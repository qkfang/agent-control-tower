
az group create --name 'rg-agentct' --location 'australiaeast'

az deployment group create --name 'agentct-dev' --resource-group 'rg-agentct' --template-file './main.bicep' --parameters './main.bicepparam'


