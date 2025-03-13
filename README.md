# azd-litellm ![Awesome Badge](https://awesome.re/badge-flat2.svg)

An `azd` template to deploy [LiteLLM](https://www.litellm.ai/) running in Azure Container Apps using an Azure PostgreSQL database.

To use this template, follow these steps using the [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview):

1. Log in to Azure Developer CLI. This is only required once per-install.

    ```bash
    azd auth login
    ```

2. Initialize this template using `azd init`:

    ```bash
    azd init --template build5nines/azd-react-bootstrap-dashboard
    ```

3. Use `azd up` to provision your Azure infrastructure and deploy the web application to Azure.

    ```bash
    azd up
    ```

## Architecture Diagram

![Diagram of Azure Resources provisioned with this template]()

## Azure Resources

These are the Azure resources that are deployed with this template:

- TODO

