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

@description('Desired replica count for LiteLLM containers.')
param containerReplicaCount int


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
      identitySettings: {
        identity: 'system'
        lifecycle: 'All'
      }
    }
    template: {
      containers: [
        {
          name: containerName
          image: containerImage
          // resources: {
          //   cpu: 0.5
          //   memory: '1Gi'
          // }
          // Pass the PostgreSQL connection string via an environment variable.
          env: [
            {
              name: 'POSTGRESQL_CONNECTION_STRING'
              value: postgresqlConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: containerReplicaCount
        maxReplicas: containerReplicaCount
      }
    }
  }
}

output containerAppName string = containerApp.name
output containerAppFQDN string = containerApp.properties.configuration.ingress.fqdn
output identityPrincipalId string = containerApp.identity.principalId
