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

@description('Desired replica count for LiteLLM containers.')
param containerReplicaCount int = 2

@description('Name of the PostgreSQL database.')
param databaseName string = 'litellmdb'


var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  'azd-template': 'Build5Nines/azd-react-bootstrap-dashboard'
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
    tags: tags //union(tags, { 'azd-service-name': 'web' })
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
  }
  scope: rg
}

// Deploy LiteLLM Container App via module call.
module litellm './app/litellm.bicep' = {
  name: 'litellm'
  params: {
    name: '${abbrs.appContainerApps}litellm-${resourceToken}'
    containerAppsEnvironmentName: appsEnv.outputs.name
    postgresqlConnectionString: 'Host=${postgresql.outputs.fqdn};Database=${databaseName};Ssl Mode=Require;Trust Server Certificate=false;'

    containerPort: containerPort
    containerReplicaCount: containerReplicaCount
  }
  scope: rg
}

// Deploy PostgreSQL Administrator for litellm SystemAssigned Identity
module postgresqlLitellmAdmin './shared/postgresql_administrator.bicep' = {
  name: 'postgresqlLitellmAdmin'
  params: {
    postgresqlServerName: postgresql.outputs.name
    principalName: litellm.outputs.containerAppName
    principalId: litellm.outputs.identityPrincipalId
    principalType: 'ServicePrincipal'
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
  dependsOn: [
    postgresqlLitellmAdmin // be sure to create the admin before the database, so it can be granted permissions correctly
  ]
}

// Outputs for convenience
output litellm_containerapp_fqdn string = litellm.outputs.containerAppFQDN
output postgresql_fqdn string = postgresql.outputs.fqdn
