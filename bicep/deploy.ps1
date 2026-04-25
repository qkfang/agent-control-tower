
az group create --name 'rg-agentctt' --location 'australiaeast'

az deployment group create --name 'agentctt-dev' --resource-group 'rg-agentctt' --template-file './main.bicep' --parameters './main.bicepparam'


