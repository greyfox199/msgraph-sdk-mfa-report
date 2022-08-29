# msgraph-sdk-mfa-report
this utility is used to to get mfa data via the ms graph api endpoints from azure via the ms graph sdk for powershell

Requirements:  
-Assumes an app registration has been created in Azure tenant with appropriate permissions and with a client secret created.  This will be used to actually make a connection to the MS graph api endpoints.   
-Assumes  "Microsoft.Graph" powershell module has been installed.   
-Assumes "msal.ps" powershell module has been installed.   

# Azure configuration
This makes use of the MS graph api endpoints, and as such, an app registration must be created.  When creating a new registration, the only thing needed on the initial screen is a unique name.  Once it is created, the "Application (client) ID" can be obtained from the overview section.  
Once the client ID has been obtained, the following "API permissions" need to be added as "Application" type permissions:   
-User.Read.All   
-UserAuthenticationMethod.Read.All   
Once the permissions are added, someone with appropriate permissions (usually global admin) must grant admin consent for the requested permissions before they will be functional.   
A new client secret must also be created.  When creating a new client secret, choose an approriate expiration time and be sure to record the "value" for the "Secret ID" created when it is show, as this is the only time it will be shown.  If it is not saved, it must be deleted and a new one must be created.  The value for "Secret ID" will not be used.

# install
To install this script, either utilize the git-clone feature or manaually download from this repo.  It should be placed in a suitable location of your choosing for scheduled tasks.  This script requires a json config file to be passed in as a parameter.  The config file should be placed in an appropriate location.   

Once the powershell script and json config file have been created and configured, the script can be run manually as follows:  

.\msgraph-sdk-mfa-report.ps1 -ConfigFilePath "/path/to/config.json"

# config file
The config file is a json-formatted config file.  There are 4 required fields to control functionality

The simplest file will be this:
```json
{
    "required": {
       "appID": "[INSERT APP ID]",
        "tenantID": "[INSERT TENANT ID]",
        "clientSecretFilePath": "X:\\path\\to\\graphcredfile",
        "reportDirectory": "X:\\path\\to\\reportdirectory"
    }
}
```
**client_id**: This is the "Application (client) ID" from the azure app registration created for the graph api.  
**tenantID**: This is the tenant ID of the tenant where the app exists.   
**clientSecretFilePath**: This is the path to the secure password file for for the client secret for the app.     
**reportDirectory**:  This is the path that will be used to write the exported json and csv files for the mfa report.   

# output
This will create two files, a json-formatted file and a csv file.  

the json-formatted file will have a name of msgraph-sdk-mfa-report-[TIMESTAMP].json in the specified reportDirectory config entry.  It will have the following structure:

```json
[
    {
        "defaultMethod":  "[DEFAULT METHOD CONFIGURED]",
        "microsoftAuthenticatorAuthenticationMethod":  [true | false],
        "mobilePhone":  [true | false],
        "microsoftAuthenticatorPush":  [true | false],
        "passwordlessMicrosoftAuthenticatorAuthenticationMethod":  [true | false],
        "temporaryAccessPassAuthenticationMethod":  [true | false],
        "alternateMobilePhone":  [true | false],
        "softwareOathAuthenticationMethod":  [true | false],
        "passwordAuthenticationMethod":  [true | false],
        "windowsHelloForBusinessAuthenticationMethod":  [true | false],
        "isMfaRegistered":  [true | false],
        "fido2AuthenticationMethod":  [true | false],
        "emailAuthenticationMethod":  [true | false],
        "officePhone":  [true | false],
        "phoneAuthenticationMethod":  [true | false],
        "softwareOneTimePasscode":  [true | false],
        "UserprincipalName":  "[USERPRINCIPALNAME]"
    }
]
```

The data reported is taken from the results of Get-MgUserAuthenticationMethod and from the following graph endpoint related to mfa registration:

https://graph.microsoft.com/beta/reports/authenticationMethods/userRegistrationDetails

Get-MgUserAuthenticationMethod lists methods such as fido2, temporary access pass and Windows Hello for business.  The userRegistrationDetails endpoint will report on the default method configured as well as the "isMFARegistered", which should be set to true if any method valid for multifactor authentication has been configured.


The csv file will have a name of msgraph-sdk-mfa-report-[TIMESTAMP].csv in the specified reportDirectory config entry.  It will have the same data as the json with the keys as the headers of the csv file.   