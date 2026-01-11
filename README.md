


# Azure Todo App (Terraform Deployment Guide)

This project demonstrates a Todo App with a Python Azure Functions backend and a static HTML/JS frontend, deployed using Terraform.

![My Diagram](diagram.svg)

---

## Prerequisites

Ensure you have the following installed and configured:

> [!TIP] **Windows Users:** For the best experience with the Azure CLI and shell commands used in this guide, it is highly recommended to install and use **Windows Subsystem for Linux (WSL)**. This allows you to run a native Linux environment (like Ubuntu) directly on Windows.
**Install:** Open PowerShell as Administrator and run `wsl --install`.

### 1. Azure CLI
Used to manage Azure resources and authenticate Terraform.
- **Install:** [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Verify:** Run `az --version`

### 2. Terraform
Used to define and provision the Azure infrastructure.
- **Install:** [Install Terraform](https://learn.hashicorp.com/terraform/tutorials/aws/install-cli) (version 1.0+ recommended)
- **Verify:** Run `terraform --version`

### 3. Node.js & npm (for Frontend Deployment)
Required for the Static Web Apps CLI and frontend tools.
- **Install:** [Download Node.js](https://nodejs.org/) (LTS version recommended)

### 4. Azure Functions Core Tools (for Backend Deployment)
Required to run and debug the Python function app locally and for deployment.
- **Install (via npm):** `npm install -g azure-functions-core-tools@4 --unsafe-perm true`
- **Verify:** Run `func --version`

### 5. Azure Static Web Apps CLI (SWA CLI) (for Frontend Deployment)
Used to serve and deploy the frontend.
- **Install (via npm):** `npm install -g @azure/static-web-apps-cli`
- **Verify:** Run `swa --version`

### 7. Azure Infrastructure Prerequisites
Before running Terraform, you must manually create the following resources:

#### A. Storage Account for Terraform State
Terraform needs a place to store its state file.
1.  Create a **Resource Group** (e.g., `terraform-state-rg`) and a **Storage Account** (globally unique name).
2.  Create a **Container** named `tfstate` inside that Storage Account.
3.  **Permissions:** Ensure your user account has the **Storage Blob Data Contributor** role.

#### B. Key Vault & SQL Password
The deployment retrieves the SQL Admin Password from an Azure Key Vault. This is required for secure password management.
1.  Create a **Key Vault** (e.g., `terraform-kv-01`).
2.  Create a **Secret** named `sql-password` containing a strong password.
3.  **Update Configuration:** You **must** specify your own Key Vault in `terraform/data.tf` because this is used to pass the SQL password.
    *   Locate the `data "azurerm_key_vault" "kv"` block in `terraform/data.tf`.
    *   Update the `name` and `resource_group_name` to match your Key Vault.

---

## Deployment Steps

This section outlines how to deploy the Azure Todo App infrastructure.

### 1. Terraform Initialization

Navigate to the `terraform` directory:
```bash
cd terraform
```

**Configuration:**
1.  **Backend Config:** Open `terraform/providers.tf` and update the `backend "azurerm"` block with your **Storage Account** name (from Prerequisite 7A).
    ```hcl
    backend "azurerm" {
      storage_account_name = "tfstate1756664581" # Change this to a globally unique name
      container_name       = "tfstate"
      key                  = "todo-dev.tfstate"
      use_azuread_auth     = true
    }
    ```
2.  **Variables:** Configure your environment variables by renaming the example file:
    ```bash
    mv terraform.tfvars.example terraform.tfvars
    ```
    Open `terraform.tfvars` and fill in the required values:
    *   `subscription_id`: Your Azure Subscription ID.
    *   `aad_admin_object_id`: Your Azure AD User Object ID.

**Initialize Terraform:**
```bash
terraform init
```

### 2. Prepare for Terraform Apply

Since you have already configured the Key Vault and Storage Account in the **Prerequisites** section, you are ready to proceed.

### 3. Plan and Apply Infrastructure

From the `terraform` directory:

```bash
# Review the proposed changes
terraform plan -out main.tfplan

# Apply the changes to create Azure resources
terraform apply "main.tfplan"
```
Confirm the apply by typing `yes` when prompted.

### 4. Configure SQL Database User for Function App

After Terraform has created the SQL Server and Function App, you need to grant the Function App's Managed Identity permissions to the SQL Database.
Navigate back to the project root and run the `create_db_user.sh` script:

```bash
cd .. # Go back to project root
./scripts/create_db_user.sh
```
This script fetches necessary outputs from Terraform and executes SQL commands to create a user for the Function App and assign it `db_datareader`, `db_datawriter`, and `db_ddladmin` roles. It uses Azure AD authentication, so ensure your Azure CLI is logged in as an Azure AD admin for the SQL server.

### 5. Deploy Backend (Azure Function App)

From the project root:

```bash
func azure functionapp publish $(terraform -chdir=terraform output -raw function_app_name)
```
This command deploys your Python function app code to the Azure Function App created by Terraform.

### 6. Configure Frontend (Static Web App)

#### a. Update the API Endpoint in `frontend/index.html`
The frontend needs to know where to send API requests. Open `frontend/index.html` and update the `API_URL` variable.

Locate the line where `API_URL` is defined and replace it with the actual Function App URL. You can get the URL using:

```bash
terraform -chdir=terraform output -raw function_app_url
```

Example:
```javascript
// In frontend/index.html
let API_URL = "https://<your-function-app-name>.azurewebsites.net/api/todos";
```
> Make sure to include the `/api/todos` path suffix as that's typically how function routes are defined.

#### b. Deploy Frontend Static Files

Get the deployment token for the Static Web App and then deploy the `frontend` directory:

```bash
DEPLOYMENT_TOKEN=$(az staticwebapp secrets list --name $(terraform -chdir=terraform output -raw static_web_app_name) --resource-group $(terraform -chdir=terraform output -raw resource_group_name) --query "properties.apiKey" -o tsv)
swa deploy ./frontend --env production --deployment-token $DEPLOYMENT_TOKEN
```

### 7. Initialize Database Schema

Once both the backend and frontend are deployed and configured, trigger the database schema initialization.

From the project root:

```bash
./scripts/init_db.sh
```
This script calls the `/api/init` endpoint of your deployed Function App to create the necessary tables in the SQL Database.

### 8. Verify Deployment

1.  Open your Static Web App URL in a browser. You can get the URL using:
    ```bash
    terraform -chdir=terraform output -raw swa_default_hostname
    ```
2.  Try adding a new Todo item.
3.  **Validation:** If the item appears, the Frontend, Function App, and Azure SQL Database are communicating correctly.
    *   Check **Browser Console (F12)** for frontend errors.
    *   Check **Function App Logs** in Azure Portal for backend/database issues.

---

## Clean Up

To destroy the deployed Azure resources (use with caution!):

```bash
cd terraform
terraform destroy
```

Confirm by typing `yes`.
