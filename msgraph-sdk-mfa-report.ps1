[cmdletbinding()]
param (
  [Parameter (Mandatory = $true)] [String]$ConfigFilePath
)

#if Posh-SSH module can't be loaded, abort process
try {
    import-module msal.ps
} catch {
    throw "msal.ps powershell module cannot be imported, aborting process"
}

#if json config file does not exist, abort process
if (-not(Test-Path -Path $ConfigFilePath -PathType Leaf)) {
    throw "json config file specified at $($ConfigFilePath) does not exist, aborting process"
}
  
#if config file configured is not json format, abort process.
try {
    $PowerShellObject=Get-Content -Path $ConfigFilePath | ConvertFrom-Json
} catch {
    throw "Config file of $($ConfigFilePath) is not a valid json file, aborting process"
}

[string] $strServerName = $env:computername

[string] $appID = ""
[string] $clientSecret = ""
[string] $tenantID = ""
[string] $reportDir = ""
[bool] $writeToLog = $false
[string] $fileTimeStamp = $(get-date -f yyyy-MM-dd-hh_mm_ss)


#function to write log file
Function LogWrite($objLogFile, [string]$strLogstring, [bool]$DisplayInConsole=$true)
{ 
  if ($DisplayInConsole -eq $true) {
    write-host $strLogstring
  }
  if ($blnWriteToLog -eq $true) {
    $objLogFile.writeline($strLogstring)
    $objLogFile.flush()
  }
}

#if appID config option does not exist in json, abort process
if ($PowerShellObject.Required.appID) {
    $appID = $PowerShellObject.Required.appID
} else {
    throw "appID does not exist in json config file, aborting process"
}

#if tenantID config option does not exist in json, abort process
if ($PowerShellObject.Required.tenantID) {
    $tenantID = $PowerShellObject.Required.tenantID
} else {
    throw "tenantID does not exist in json config file, aborting process"
}
  
#if udm secure password file does not exist, abort process
if ($PowerShellObject.Required.clientSecretFilePath) {
    if (Test-Path -Path $PowerShellObject.Required.clientSecretFilePath -PathType Leaf) {
        $clientSecretSecure = Get-Content $PowerShellObject.Required.clientSecretFilePath | ConvertTo-SecureString
        $clientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecretSecure))
    } else {
        throw "failed to get password fromm $($PowerShellObject.Required.clientSecretFilePath), aborting process"
    }
} else {
    throw "clientSecretFilePath does not exist in json config file, aborting process"
}
  
#if report directory specified, abort process
if ($PowerShellObject.Required.reportDirectory) {
    if (Test-Path -Path $PowerShellObject.Required.reportDirectory -PathType Container) {
        $reportDir = $PowerShellObject.Required.reportDirectory

        
        [string] $jsonFilePath = "$($reportDir)\msgraph-sdk-mfa-report-$($fileTimeStamp).json"
        [string] $csvFilePath = "$($reportDir)\msgraph-sdk-mfa-report-$($fileTimeStamp).csv"
        $csvFile = [System.IO.StreamWriter] $csvFilePath
    } else {
        throw "path specified for report directory of $($PowerShellObject.Required.reportDirectory) in config file does not exist, aborting process"
    }
} else {
    throw "reportDir does not exist in json config file, aborting process"
}

#set up variables


[uint16] $intDaysToKeepReportFiles = 0
[uint16] $intDaysToKeepLogFiles = 0

[bool] $blnSendSMTPErrorReport = $false
[bool] $blnSMTPAuthRequired = $false
[bool] $blnReportSuccessful = $false
[bool] $blnWriteToLog = $false
[uint16] $intSMTPPort = 587


[int] $intErrorCount = 0
$arrStrErrors = @()

#clear all errors before starting
$error.Clear()

try {
    $MsalToken = Get-MsalToken -TenantId $tenantID -ClientId $appID -ClientSecret ($clientSecret | ConvertTo-SecureString -AsPlainText -Force)
    Connect-MgGraph -AccessToken $MsalToken.AccessToken
    Select-MgProfile Beta
    write-host "connected"
    $successfullyConnected = $true

} catch {
    $ErrorMessage = $_.Exception.Message
	$line = $_.InvocationInfo.ScriptLineNumber
	$arrStrErrors += "Failed to connect to MS Graph using tenant ID of $($appID) and appID of $($tenantID),  at $($line) with the following error: $ErrorMessage"
	LogWrite $objDetailLogFile "$(get-date) Error: Failed to connect to MS Graph using tenant ID of $($appID) and appID of $($tenantID) at $($line) with the following error: $ErrorMessage"
}

if ($successfullyConnected) {

    $userList = @()
    $users = get-mguser -all
    foreach ($user in $users) {

        $microsoftAuthenticatorAuthenticationMethod = $false
        $phoneAuthenticationMethod = $false
        $passwordAuthenticationMethod = $false
        $fido2AuthenticationMethod = $false
        $windowsHelloForBusinessAuthenticationMethod = $false
        $emailAuthenticationMethod = $false
        $temporaryAccessPassAuthenticationMethod = $false
        $passwordlessMicrosoftAuthenticatorAuthenticationMethod = $false
        $softwareOathAuthenticationMethod = $false

        $mobilePhone = $false
        $alternateMobilePhone = $false
        $officePhone = $false
        $microsoftAuthenticatorPush = $false
        $softwareOneTimePasscode = $false



    
        #possible values: microsoftAuthenticatorAuthenticationMethod, phoneAuthenticationMethod, passwordAuthenticationMethod, 
        #fido2AuthenticationMethod, windowsHelloForBusinessAuthenticationMethod, emailAuthenticationMethod, temporaryAccessPassAuthenticationMethod, 
        #passwordlessMicrosoftAuthenticatorAuthenticationMethod, softwareOathAuthenticationMethod
        $userMFAMethods = Get-MgUserAuthenticationMethod -userid $user.Id
        #$userMFaRegistrationDetails = Get-MgReportAuthenticationMethodUserRegistrationDetail -Filter "UserprincipalName eq '$($user.UserprincipalName)'"

        foreach ($method in $userMFAMethods) {
            foreach ($types in $method.AdditionalProperties["@odata.type"]) {
                switch ($types) {
                    "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                        $microsoftAuthenticatorAuthenticationMethod = $true
                    }
                    "#microsoft.graph.phoneAuthenticationMethod" {
                        $phoneAuthenticationMethod = $true
                    }
                    "#microsoft.graph.passwordAuthenticationMethod" {
                        $passwordAuthenticationMethod = $true
                    }
                    "#microsoft.graph.fido2AuthenticationMethod" {
                        $fido2AuthenticationMethod = $true
                    }
                    "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                        $windowsHelloForBusinessAuthenticationMethod = $true
                    }
                    "#microsoft.graph.emailAuthenticationMethod" {
                        $emailAuthenticationMethod = $true
                    }
                    "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                        $temporaryAccessPassAuthenticationMethod = $true
                    }
                    "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" {
                     $passwordlessMicrosoftAuthenticatorAuthenticationMethod = $true
                    }
                    "#microsoft.graph.softwareOathAuthenticationMethod" {
                        $softwareOathAuthenticationMethod = $true
                    }
                }
            }
        }

        #https://docs.microsoft.com/en-us/graph/api/resources/userregistrationdetails?view=graph-rest-beta for documentation
        $Uri = "https://graph.microsoft.com/beta/reports/authenticationMethods/userRegistrationDetails/" + $User.Id
        $AccessMethodData = Invoke-MgGraphRequest -Uri $Uri -Method Get
    
        #possible values: none, mobilePhone, alternateMobilePhone, officePhone, microsoftAuthenticatorPush, 
        #softwareOneTimePasscode, unknownFutureValue
        foreach ($methodRegistered in $AccessMethodData.MethodsRegistered) {
            switch ($types) {
                "mobilePhone" {
                    $mobilePhone = $true
                }
                "alternateMobilePhone" {
                    $alternateMobilePhone = $true
                }
                "officePhone" {
                    $officePhone = $true
                }
                "microsoftAuthenticatorPush" {
                    $microsoftAuthenticatorPush = $true
                }
                "softwareOneTimePasscode" {
                    $softwareOneTimePasscode = $true
                }
            }

        }

        $userList += @{UserprincipalName = $user.UserprincipalName; microsoftAuthenticatorAuthenticationMethod = $microsoftAuthenticatorAuthenticationMethod; `
            phoneAuthenticationMethod = $phoneAuthenticationMethod; passwordAuthenticationMethod = $passwordAuthenticationMethod; fido2AuthenticationMethod = $fido2AuthenticationMethod; `
            windowsHelloForBusinessAuthenticationMethod = $windowsHelloForBusinessAuthenticationMethod; emailAuthenticationMethod = $emailAuthenticationMethod; `
            temporaryAccessPassAuthenticationMethod = $temporaryAccessPassAuthenticationMethod; passwordlessMicrosoftAuthenticatorAuthenticationMethod = $passwordlessMicrosoftAuthenticatorAuthenticationMethod; `
            softwareOathAuthenticationMethod = $softwareOathAuthenticationMethod; mobilePhone = $mobilePhone; alternateMobilePhone = $alternateMobilePhone; officePhone = $officePhone; `
            microsoftAuthenticatorPush = $microsoftAuthenticatorPush; softwareOneTimePasscode = $softwareOneTimePasscode; isMfaRegistered = $AccessMethodData.isMfaRegistered; defaultMethod = $AccessMethodData.defaultMfaMethod }
    } #end of loop through each user

    #$userList | % { new-object PSObject -Property $_}

    $userList | ConvertTo-Json -depth 100 | out-file $jsonFilePath

    $csvFile.writeline("UserprincipalName,microsoftAuthenticatorAuthenticationMethod,phoneAuthenticationMethod,passwordAuthenticationMethod,fido2AuthenticationMethod,windowsHelloForBusinessAuthenticationMethod,emailAuthenticationMethod,temporaryAccessPassAuthenticationMethod,passwordlessMicrosoftAuthenticatorAuthenticationMethod,softwareOathAuthenticationMethod,mobilePhone,alternateMobilePhone,officePhone,microsoftAuthenticatorPush,softwareOneTimePasscode,isMfaRegistered,defaultMethod")
    foreach ($item in $userList) {
        $csvFile.writeline("$($item.UserprincipalName),$($item.microsoftAuthenticatorAuthenticationMethod),$($item.phoneAuthenticationMethod),$($item.passwordAuthenticationMethod),$($item.fido2AuthenticationMethod),$($item.windowsHelloForBusinessAuthenticationMethod),$($item.emailAuthenticationMethod),$($item.temporaryAccessPassAuthenticationMethod),$($item.passwordlessMicrosoftAuthenticatorAuthenticationMethod),$($item.softwareOathAuthenticationMethod),$($item.mobilePhone),$($item.alternateMobilePhone),$($item.officePhone),$($item.microsoftAuthenticatorPush),$($item.softwareOneTimePasscode),$($item.isMfaRegistered),$($item.defaultMethod)")
    }

} #end if successfully connected

$csvFile.close()