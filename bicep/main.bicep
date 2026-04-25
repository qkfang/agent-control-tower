@description('Base name prefix for all resources')
param baseName string = 'agentct'

@description('Azure region for all resources')
param location string = 'australiaeast'

@description('Principal object IDs to grant access to deployed resources')
param principals array = []

var commonTags = {
}
var foundryName = '${baseName}-foundry'
var storageAccountName = replace('${baseName}sa', '-', '')
var logAnalyticsName = '${baseName}-law'
var appInsightsName = '${baseName}-ai'
var appServicePlanName = '${baseName}-asp'
var webAppName = '${baseName}-web'


// ── Storage Account ──────────────────────────────────────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}


// ── Log Analytics Workspace ──────────────────────────────────────────────────
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource logAnalyticsDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-storage'
  scope: logAnalyticsWorkspace
  properties: {
    storageAccountId: storageAccount.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}


// ── Application Insights ─────────────────────────────────────────────────────
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}


// ── App Service Plan ─────────────────────────────────────────────────────────
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: commonTags
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: false
  }
}


// ── AI Foundry ───────────────────────────────────────────────────────────────
module azureFoundry 'foundry.bicep' = {
  name: 'foundryDeployment'
  params: {
    name: foundryName
    location: location
    tags: commonTags
  }
}

// ── Role assignments: API App → Foundry ──────────────────────────────────────
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  name: foundryName
  dependsOn: [azureFoundry]
}


// ── Web App ──────────────────────────────────────────────────────────────────
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v9.0'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'AZURE_AI_PROJECT_ENDPOINT'
          value: azureFoundry.outputs.endpoint
        }
        {
          name: 'AZURE_AI_MODEL_DEPLOYMENT_NAME'
          value: azureFoundry.outputs.deploymentName
        }
      ]
    }
  }
}


// ── App Insights diagnostic settings for Web App ─────────────────────────────
resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-law'
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}


// ── Role assignments: additional principals ──────────────────────────────────
resource userOpenAIUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principal in principals: {
  name: guid(foundryAccount.id, principal.id, cognitiveServicesOpenAIUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: principal.id
    principalType: principal.principalType
  }
}]

// ── Role assignment: Web App managed identity → Foundry ──────────────────────
resource webAppOpenAIUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, webApp.id, cognitiveServicesOpenAIUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}


// ── Outputs ──────────────────────────────────────────────────────────────────
output foundryEndpoint string = azureFoundry.outputs.endpoint
output foundryDeploymentName string = azureFoundry.outputs.deploymentName
output storageAccountName string = storageAccount.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
