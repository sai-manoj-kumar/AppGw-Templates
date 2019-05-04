<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
    [string]
    [ValidateSet("CentralUSSlice", "InternalSubscription1", "OtherSubscription")]
    $Subscription = "OtherSubscription",

    [Parameter(Mandatory = $True)]
    [string]
    $resourceGroupName,

    [string]
    $resourceGroupLocation = "",

    [string]
    $subscriptionId,

    [string]
    $deploymentName = "deployment1",

    [string]
    $templateFilePath = "template.json",

    [string]
    $parametersFilePath = "parameters.json"
)

if ($Subscription -eq "CentralUSSlice") {
    $resourceGroupLocation = "centraluseuap"
    $subscriptionId = "1496a758-b2ff-43ef-b738-8e9eb5161a86"
}
elseif ($Subscription -eq "InternalSubscription1") {
    if ($resourceGroupLocation -eq "") {
        $resourceGroupLocation = "eastus"
    }
    $subscriptionId = "f7e1a56e-347b-4103-87c7-e775a3e11ac5"
}

$resourceGroupName = $env:UserName + "-" + $resourceGroupName
Enable-AzureRmAlias -Scope CurrentUser

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

function Login {
    if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) {
        Write-Host "Not Logged in yet";
        Connect-AzAccount
        #Login-AzureRmAccount
    }
    else {
        Write-Host "Already Logged in";
    }
}

# Login if not already logged in
Login

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.network", "microsoft.compute", "microsoft.storage", "microsoft.devtestlab");
if ($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach ($resourceProvider in $resourceProviders) {
        #        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (!$resourceGroup) {
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if (!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    $now = Get-Date
    New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -Tag @{'CreatedBy' = $env:UserName; 'ExpiresBy' = $now.ToUniversalTime().AddDays(3).GetDateTimeFormats()[8]}
}
else {
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
if (Test-Path $parametersFilePath) {
    $lasterror = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath;
}
else {
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath
}
