
export APP_NAME='poc-azure-oidc'
export GH_REPO='johndohoneyjr/poc-azure-oidc'
export OWNER='XXX'
export TENANT_ID='XXX'
export SUB_ID='XXX'

echo "Make sure you are logged in to Azure CLI..." 
az login

echo "Make sure you are logged in to GitHub CLI..." 
gh auth login

echo
echo "Using the Azure AD Tenant: $TENANT_ID" 
az account set --subscription $SUB_ID
echo "Applying changes to Azure Subscription ID: $SUB_ID"

echo "Start setup OpenID Connect between GitHub and Azure..."
echo "  - Creating Azure AD Application Registration with name <$APP_NAME>"
echo "  - Configuring the GitHub repository <$GH_REPO>"

echo "Creating Azure Active Directory application $APP_NAME..."
APP_ID=$(az ad app create --display-name ${APP_NAME} --query appId -o tsv)
        
sleep 5
echo "APP_ID: ${APP_ID} created." 

echo "Creating Service Principal..." 
SP_ID=$(az ad sp create --id ${APP_NAME} --query objectId -o tsv)
sleep 5
echo "SPN_ID: $SP_ID created." 

echo "Getting Azure Subscription Id..."
SUB_ID=$(az account show --query id -o tsv)
echo "SUB_ID: $SUB_ID"
        
echo "Assign Contributor role to $SP_ID (SPN) on $SUB_ID (Subscription)..." 
az role assignment create --role contributor --subscription $SUB_ID --assignee-object-id $SP_ID --assignee-principal-type ServicePrincipal

$APP_OBJ_ID = $(az ad app show --id $APP_ID --query objectId -o tsv)
echo "APP_OBJECT_ID: $APP_OBJ_ID" 

echo "Set Owner on application registration..."
$USER_OBJ_ID = $(az ad user show --id $OWNER --query objectId --out tsv)
az ad app owner add --id $APP_OBJ_ID --owner-object-id $USER_OBJ_ID

echo "Creating AAD Federated Identity Credentials..."
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${APP_OBJ_ID}/federatedIdentityCredentials" --body "{'name':'refpath','issuer':'https://token.actions.githubusercontent.com','subject':'repo:${GH_REPO}:ref:refs/heads/main','description':'main','audiences':['api://AzureADTokenExchange']}"
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${APP_OBJ_ID}/federatedIdentityCredentials" --body "{'name':'pullrequest','issuer':'https://token.actions.githubusercontent.com','subject':'repo:${GH_REPO}:pull-request','description':'pr','audiences':['api://AzureADTokenExchange']}"
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${APP_OBJ_ID}/federatedIdentityCredentials" --body "{'name':'environ','issuer':'https://token.actions.githubusercontent.com','subject':'repo:${GH_REPO}:environment:Production','description':'Environment Production','audiences':['api://AzureADTokenExchange']}"

echo "Creating GitHub repository secrets..." -
echo AZURE_CLIENT_ID=$APP_ID
echo AZURE_SUBSCRIPTION_ID=$SUB_ID
echo AZURE_TENANT_ID=$TENANT_ID

echo "Creating GitHub secrets..."
gh secret set AZURE_CLIENT_ID --body=$APP_ID --repo $GH_REPO
gh secret set AZURE_SUBSCRIPTION_ID --body=$SUB_ID --repo $GH_REPO
gh secret set AZURE_TENANT_ID --body=$TENANT_ID --repo $GH_REPO

echo "GitHub $GH_REPO secrets...`n" -ForegroundColor Yellow
$GH_REPO_SECRETS = $(gh secret list --repo $GH_REPO)
echo $GH_REPO_SECRETS

echo "Initialization Complete..." 
