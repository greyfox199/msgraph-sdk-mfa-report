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
    $users = get-mguser -all
    foreach ($user in $users) {
    write-host $user.UserprincipalName
    $userMFAMethods = Get-MgUserAuthenticationMethod -userid $user.Id
    #Get-MgReportAuthenticationMethodUserRegistrationDetail -Filter "UserprincipalName eq '$($user.UserprincipalName)'"
    $userMFaRegistrationDetails = Get-MgReportAuthenticationMethodUserRegistrationDetail -Filter "UserprincipalName eq '$($user.UserprincipalName)'"

    write-host $userMFaRegistrationDetails.IsMfaRegistered

    foreach ($method in $userMFAMethods) {
        foreach ($types in $method.AdditionalProperties["@odata.type"]) {
            write-host $types
        }
    }
    write-host "****************"
    }

}