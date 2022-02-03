<#
.SYNOPSIS
    Setup OIDC between GitHub and Microsoft Azure.

.NOTES
    Version:        0.1
    Author:         John Dohoney
    Creation Date:  February 3, 2022

.EXAMPLE
    PS C:\>setup-aadgh.ps1
#>


function Poc-AzureAdEphemOIDC {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The name of the application registration")]
        [ValidateNotNullOrEmpty()]
        [string]
        $APP_NAME,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the GitHub repository")]
        [ValidateNotNullOrEmpty()]
        [string]
        $GH_REPO,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the User that needs to be set as owner on the application registration")]
        [ValidateNotNullOrEmpty()]
        [string]
        $OWNER,

        [Parameter(Mandatory = $true, HelpMessage = "The Id of the Azure Active Directory tenant")]
        [ValidateNotNullOrEmpty()]
        [string]
        $TENANT_ID
    )
    try {
        Write-Host "Creating Azure Active Directory application $APP_NAME..." -ForegroundColor Green
        $APP_ID = $(az ad app create --display-name ${APP_NAME} --query appId -o tsv)
        
        # wait for AAD app to be created or the script will fail
        Start-Sleep -Seconds 5
        Write-Host "APP_ID: $APP_ID created.`n" -ForegroundColor Yellow

        Write-Host "Creating Service Principal..." -ForegroundColor Green
        $SP_ID = $(az ad sp create --id $APP_ID --query objectId -o tsv)
        Start-Sleep -Seconds 5
        Write-Host "SPN_ID: $SP_ID created.`n" -ForegroundColor Yellow

        Write-Host "Getting Azure Subscription Id..." -ForegroundColor Green
        $SUB_ID = $(az account show --query id -o tsv)
        Write-Host "SUB_ID: $SUB_ID.`n" -ForegroundColor Yellow
        
        Write-Host "Assign Contributor role to $SP_ID (SPN) on $SUB_ID (Subscription)..." -ForegroundColor Green
        az role assignment create --role contributor --subscription $SUB_ID --assignee-object-id $SP_ID --assignee-principal-type ServicePrincipal

        $APP_OBJ_ID = $(az ad app show --id $APP_ID --query objectId -o tsv)
        Write-Host "APP_OBJECT_ID: $APP_OBJ_ID`n" -ForegroundColor Yellow

        Write-Host "Set Owner on application registration..." -ForegroundColor Green
        $USER_OBJ_ID = $(az ad user show --id $OWNER --query objectId --out tsv)
        az ad app owner add --id $APP_OBJ_ID --owner-object-id $USER_OBJ_ID

        Write-Host "Creating federated Identity Credential..." -ForegroundColor Green
        az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${APP_OBJ_ID}/federatedIdentityCredentials" --body "{'name':'refpathfic','issuer':'https://token.actions.githubusercontent.com','subject':'repo:${GH_REPO}:ref:refs/heads/main','description':'main','audiences':['api://AzureADTokenExchange']}"
        az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${APP_OBJ_ID}/federatedIdentityCredentials" --body "{'name':'prfic','issuer':'https://token.actions.githubusercontent.com','subject':'repo:${GH_REPO}:pull-request','description':'pr','audiences':['api://AzureADTokenExchange']}"
        az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${APP_OBJ_ID}/federatedIdentityCredentials" --body "{'name':'envfic','issuer':'https://token.actions.githubusercontent.com','subject':'repo:${GH_REPO}:environment:Production','description':'Environment Production','audiences':['api://AzureADTokenExchange']}"

        Write-Host "Creating GitHub repository secrets...`n" -ForegroundColor Green
        Write-Host AZURE_CLIENT_ID=$APP_ID
        Write-Host AZURE_SUBSCRIPTION_ID=$SUB_ID
        Write-Host AZURE_TENANT_ID=$TENANT_ID

        Write-Host "Creating GitHub secrets...`n" -ForegroundColor Green
        gh secret set AZURE_CLIENT_ID --body=$APP_ID --repo $GH_REPO
        gh secret set AZURE_SUBSCRIPTION_ID --body=$SUB_ID --repo $GH_REPO
        gh secret set AZURE_TENANT_ID --body=$TENANT_ID --repo $GH_REPO

        Write-Host "GitHub $GH_REPO secrets...`n" -ForegroundColor Yellow
        $GH_REPO_SECRETS = $(gh secret list --repo $GH_REPO)
        Write-Host $GH_REPO_SECRETS
    }
    catch {
        $exception = $_.Exception.Message
        Write-Host "An error occured - ", $exception
        exit;
    }
}


$APP_NAME = 'poc-azure-oidc'
$GH_REPO = 'johndohoneyjr/poc-azure-oidc'
$OWNER = '27d9daa3-90a0-4a08-aa7d-9f52aedd8a34'
$TENANT_ID = '72f988bf-86f1-41af-91ab-2d7cd011db47'
$SUB_ID = '33732876-7635-4beb-9654-e3c3c37b7ecb'

Write-Host "Make sure you are logged in to Azure CLI...`n`n" -ForegroundColor Green
az login

Write-Host "Make sure you are logged in to GitHub CLI...`n`n" -ForegroundColor Blue
gh auth login

Write-Host "Using the Azure AD Tenant: $TENANT_ID`n" -ForegroundColor Yellow
az account set --subscription $SUB_ID
Write-Host "Applying changes to Azure Subscription ID: $SUB_ID`n" -ForegroundColor Yellow

Write-Host "Start setup OpenID Connect between GitHub and Azure...`n`
- Creating Azure AD Application Registration with name <$APP_NAME>`n`
- Configuring the GitHub repository <$GH_REPO>`n" -ForegroundColor Green
Poc-AzureAdEphemOIDC -APP_NAME $APP_NAME -GH_REPO $GH_REPO -TENANT_ID $TENANT_ID -OWNER $OWNER

Write-Host "Initialization completed ..." -ForegroundColor Green