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

@description('Container image for LiteLLM.')
param containerImage string  = 'litellm/litellm:latest'

@description('Port exposed by the LiteLLM container.')
param containerPort int

@description('Minimum replica count for LiteLLM containers.')
param containerMinReplicaCount int

@description('Maximum replica count for LiteLLM containers.')
param containerMaxReplicaCount int


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
        {
          name: 'azure-openai-api-key'
          value: ''
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
              name: 'LITELLM_LOG'
              value: 'DEBUG'
            }
            {
              name: 'DATABASE_URL'
              secretRef: 'database-url'
            }
            {
              name: 'AZURE_API_KEY'
              secretRef: 'azure-openai-api-key'
            }
            {
              name: 'AZURE_API_BASE'
              value: 'https://b59-knowledge-oai.openai.azure.com/'
            }
            {
              name: 'AZURE_API_VERSION'
              value: '2023-05-15'
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

output containerAppName string = containerApp.name
output containerAppFQDN string = containerApp.properties.configuration.ingress.fqdn
output identityPrincipalId string = containerApp.identity.principalId
