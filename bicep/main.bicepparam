using 'main.bicep'

param baseName = 'agentct'
param location = 'australiaeast'
param principals = [
  { id: '<user-principal-object-id>', principalType: 'User' }
  { id: '<service-principal-object-id>', principalType: 'ServicePrincipal' }
]
