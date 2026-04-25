param name string
param location string
param tags object = {}
param aiSearchEndpoint string = ''
param aiSearchResourceId string = ''

resource aiHub 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    allowProjectManagement: true
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: aiHub
  name: '${name}-project'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

resource gpt5oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiHub
  name: 'gpt-4o'
  sku: {
    name: 'GlobalStandard'
    capacity: 1000
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2026-03-05'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

resource f2CapacityPlan 'Microsoft.CognitiveServices/accounts/commitmentPlans@2024-10-01' = {
  parent: aiHub
  name: 'foundry-f2-capacity'
  sku: {
    name: 'F2'
  }
  properties: {
    planType: 'ProvisionedManaged'
    hostingModel: 'ProvisionedWeb'
    current: {
      tier: 'F2'
      count: 1
    }
    autoRenew: true
  }
}

resource aiSearchConnection 'Microsoft.CognitiveServices/accounts/connections@2025-10-01-preview' = if (aiSearchEndpoint != '') {
  parent: aiHub
  name: 'ai-search-connection'
  properties: {
    authType: 'AAD'
    category: 'CognitiveSearch'
    target: aiSearchEndpoint
    metadata: {
      type: 'azure_ai_search'
      ResourceId: aiSearchResourceId
    }
  }
}

resource aiSearchProjectConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-10-01-preview' = if (aiSearchEndpoint != '') {
  parent: aiProject
  name: 'ai-search-connection-project'
  properties: {
    authType: 'AAD'
    category: 'CognitiveSearch'
    target: aiSearchEndpoint
    metadata: {
      type: 'azure_ai_search'
      ResourceId: aiSearchResourceId
    }
  }
}

output accountName string = aiHub.name
output resourceId string = aiHub.id
output endpoint string = aiHub.properties.endpoint
output deploymentName string = gpt5oDeployment.name
output projectName string = aiProject.name
output location string = location
output principalId string = aiHub.identity.principalId
output aiSearchConnectionName string = aiSearchEndpoint != '' ? aiSearchConnection.name : ''
output f2CapacityPlanName string = f2CapacityPlan.name
