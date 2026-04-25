@description('Base name prefix for all resources')
param baseName string = 'agentct'

@description('Azure region for all resources')
param location string = 'australiaeast'

@description('Principal object IDs to grant access to deployed resources')
param principals array = []

var commonTags = {
  project: 'agentct-agent'
}
var foundryName = '${baseName}-fndry'
var aiSearchName = '${baseName}-search'
var apiAppName = '${baseName}-api'
var webAppName = '${baseName}-web'

// ── AI Search ────────────────────────────────────────────────────────────────
module aiSearch 'aisearch.bicep' = {
  name: 'aiSearchDeployment'
  params: {
    name: aiSearchName
    location: location
    tags: commonTags
  }
}

// ── AI Foundry ───────────────────────────────────────────────────────────────
module azureFoundry 'foundry.bicep' = {
  name: 'foundryDeployment'
  params: {
    name: foundryName
    location: location
    tags: commonTags
    aiSearchEndpoint: aiSearch.outputs.endpoint
    aiSearchResourceId: aiSearch.outputs.id
  }
}

// ── Web Apps ─────────────────────────────────────────────────────────────────
module apiApp 'webapp.bicep' = {
  name: 'apiAppDeployment'
  params: {
    name: apiAppName
    location: location
    tags: commonTags
    appCommandLine: 'dotnet agentctapi.dll'
  }
}

module webApp 'webapp.bicep' = {
  name: 'webAppDeployment'
  params: {
    name: webAppName
    location: location
    tags: commonTags
    appCommandLine: 'dotnet agentctweb.dll'
  }
}

// ── Role assignments: Foundry ↔ AI Search ────────────────────────────────────
var searchIndexDataReaderRoleId = '1407120a-92aa-4202-b7e9-c0e197c71c8f'
var searchServiceContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'

resource searchResource 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
  dependsOn: [aiSearch]
}

resource foundrySearchIndexDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchResource.id, foundryName, searchIndexDataReaderRoleId)
  scope: searchResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataReaderRoleId)
    principalId: azureFoundry.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource foundrySearchServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchResource.id, foundryName, searchServiceContributorRoleId)
  scope: searchResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: azureFoundry.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Role assignments: API App → Foundry ──────────────────────────────────────
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var cognitiveServicesUserRoleId = 'a97b65f3-24c7-4388-baec-2e87135dc908'

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  name: foundryName
  dependsOn: [azureFoundry]
}

resource apiAppOpenAIUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, apiAppName, cognitiveServicesOpenAIUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: apiApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource apiAppCogServicesUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, apiAppName, cognitiveServicesUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleId)
    principalId: apiApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Role assignments: Web App → Foundry ──────────────────────────────────────
resource webAppOpenAIUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, webAppName, cognitiveServicesOpenAIUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: webApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource webAppCogServicesUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, webAppName, cognitiveServicesUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleId)
    principalId: webApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Role assignments: API App → AI Search ────────────────────────────────────
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'

resource apiAppSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchResource.id, apiAppName, searchIndexDataContributorRoleId)
  scope: searchResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: apiApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Role assignments: Web App → AI Search ────────────────────────────────────
resource webAppSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchResource.id, webAppName, searchIndexDataContributorRoleId)
  scope: searchResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: webApp.outputs.principalId
    principalType: 'ServicePrincipal'
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

resource userSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principal in principals: {
  name: guid(searchResource.id, principal.id, searchIndexDataContributorRoleId)
  scope: searchResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: principal.id
    principalType: principal.principalType
  }
}]

// ── Outputs ──────────────────────────────────────────────────────────────────
output foundryEndpoint string = azureFoundry.outputs.endpoint
output foundryDeploymentName string = azureFoundry.outputs.deploymentName
output aiSearchEndpoint string = aiSearch.outputs.endpoint
output apiAppDefaultHostName string = apiApp.outputs.defaultHostName
output webAppDefaultHostName string = webApp.outputs.defaultHostName
