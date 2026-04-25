using 'main.bicep'

param baseName = 'agentctt'
param location = 'australiaeast'
param principals = [
  { id: '4b74544b-02c6-4e4f-b936-732c9c3fff65', principalType: 'User' }
  { id: 'a6efe236-83c5-472b-a068-65006e369ad7', principalType: 'ServicePrincipal' }
]
