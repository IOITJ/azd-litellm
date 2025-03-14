@description('Location for the resource.')
param location string = resourceGroup().location

@description('Tags for the resource.')
param tags object = {}

@description('Name of the Container Apps managed environment.')
param containerAppsEnvironmentName string

@description('Connection string for PostgreSQL. Use secure parameter.')
param postgresqlConnectionString string

@description('Name for the App.')
param name string

@description('Name of the container.')
param containerName string = 'litellm'

@description('Name of the container registry.')
param containerRegistryName string

@description('Container image for LiteLLM.')
param containerImage string

@description('Port exposed by the LiteLLM container.')
param containerPort int

@description('Minimum replica count for LiteLLM containers.')
param containerMinReplicaCount int

@description('Maximum replica count for LiteLLM containers.')
param containerMaxReplicaCount int


resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01' existing = {
  name: containerRegistryName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-04-01-preview' existing = {
  name: containerAppsEnvironmentName
}

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: name
  location: location
  tags: union(tags, {'azd-service-name':  'litellm' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: containerPort
        transport: 'auto'
      }
      secrets: [
        {
          name: 'database-url'
          value: postgresqlConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: containerName
          image: containerImage
          env: [
            {
              name: 'DATABASE_URL'
              secretRef: 'database-url'
            }
          ]
        }
      ]
      scale: {
        minReplicas: containerMinReplicaCount
        maxReplicas: containerMaxReplicaCount
      }
    }
  }
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(subscription().id, resourceGroup().id, name, 'acrPullRole')
  properties: {
    roleDefinitionId:  subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
    principalId: containerApp.identity.principalId
  }
}

output containerAppName string = containerApp.name
output containerAppFQDN string = containerApp.properties.configuration.ingress.fqdn
output identityPrincipalId string = containerApp.identity.principalId
