targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('The Azure region for all resources.')
param location string

@description('Name of the resource group to create or use')
param resourceGroupName string 

@description('Port exposed by the LiteLLM container.')
param containerPort int = 80

@description('Minimum replica count for LiteLLM containers.')
param containerMinReplicaCount int = 2

@description('Maximum replica count for LiteLLM containers.')
param containerMaxReplicaCount int = 3

@description('Name of the PostgreSQL database.')
param databaseName string = 'litellmdb'

@description('Name of the PostgreSQL database admin user.')
param databaseAdminUser string = 'litellmuser'

@description('Password for the PostgreSQL database admin user.')
@secure()
param databaseAdminPassword string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  'azd-template': 'https://github.com/Build5Nines/azd-litellm'
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module monitoring './shared/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}litellm-${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}litellm-${resourceToken}'
  }
  scope: rg
}

module appsEnv './shared/apps-env.bicep' = {
  name: 'apps-env'
  params: {
    name: '${abbrs.appManagedEnvironments}litellm-${resourceToken}'
    location: location
    tags: tags 
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
  scope: rg
}

// Deploy PostgreSQL Server via module call.
module postgresql './shared/postgresql.bicep' = {
  name: 'postgresql'
  params: {
    name: '${abbrs.dBforPostgreSQLServers}litellm-${resourceToken}'
    location: location
    tags: tags
    databaseAdminUser: databaseAdminUser
    databaseAdminPassword: databaseAdminPassword
  }
  scope: rg
}

// Deploy PostgreSQL Database via module call.
module postgresqlDatabase './shared/postgresql_database.bicep' = {
  name: 'postgresqlDatabase'
  params: {
    serverName: postgresql.outputs.name
    databaseName: databaseName
  }
  scope: rg
}

// Deploy LiteLLM Container App via module call.
module litellm './app/litellm.bicep' = {
  name: 'litellm'
  params: {
    name: '${abbrs.appContainerApps}litellm-${resourceToken}'
    containerAppsEnvironmentName: appsEnv.outputs.name
    postgresqlConnectionString: 'postgresql://${databaseAdminUser}:${databaseAdminPassword}@${postgresql.outputs.fqdn}/${databaseName}'

    containerPort: containerPort
    containerMinReplicaCount: containerMinReplicaCount
    containerMaxReplicaCount: containerMaxReplicaCount
  }
  scope: rg
}

// Outputs for convenience
output litellm_containerapp_fqdn string = litellm.outputs.containerAppFQDN
output postgresql_fqdn string = postgresql.outputs.fqdn
