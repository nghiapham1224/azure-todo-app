
# Azure Todo App (Manual Setup Guide)

This branch contains the simplified version of the Todo App, designed to be deployed manually via the Azure Portal and CLI tools. It separates the frontend (Static Web App) and backend (Azure Functions + SQL Database).

## Prerequisites

Before starting, ensure you have the following installed on your local machine:

### 1. Azure CLI
Used to manage Azure resources from the command line.
- **Install:** [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Login:** Run `az login`

### 2. Node.js & npm
Required for the Static Web Apps CLI and frontend tools.
- **Install:** [Download Node.js](https://nodejs.org/) (LTS version recommended)

### 3. Azure Functions Core Tools
Required to run and debug the Python function app locally.
- **Install (via npm):**
  ```bash
  npm install -g azure-functions-core-tools@4 --unsafe-perm true
  ```
- **Verify:** Run `func --version`

### 4. Azure Static Web Apps CLI (SWA CLI)
Used to serve and deploy the frontend manually.
- **Install (via npm):**
  ```bash
  npm install -g @azure/static-web-apps-cli
  ```
- **Verify:** Run `swa --version`

### 5. Python 3.10+
Required for the backend logic.
- **Install:** [Download Python](https://www.python.org/downloads/)

---

## Step 1: Create Azure Resources (Portal)

### 1.1 Resource Group
The container for all your application components.

* Subscription: *{your subscription}*
* Resource group name: `rg-todo-manual`
* Region: **East US 2** *(or your preferred region)*

### 1.2 Virtual Network
This provides the private network layer and connectivity for your app components.

* Basics:
	* Resource group: **rg-todo-manual**
	* Virtual network name: `vnet-todo-manual`
	* Region: **East US 2**
* IP addresses:
    * IPv4 address space: `10.0.0.0/16`
    * Subnets:
        1. *Outbound Subnet (for Functions):*
            * Name: `snet-outbound`
            * Starting address: `10.0.0.0`
            * Size: `/24`
            * Delegate subnet to a service: **Microsoft.App/environments**
        2. *Private Subnet (for Data):*
            * Name: `snet-private`
            * Starting address: `10.0.1.0`
            * Size: `/24`
            *  Enable private subnet: **checked**
  
### 1.3  SQL Database

* Resource group: **rg-todo-manual**
* Database  name: `TodoDB`
* Server: **Create new**
	* Server  name: `sql-todo-manual` *(must be globally unique)*
	* Location: **East US 2**
	* Authentication method: **Use both SQL and Microsoft Entra authentication**
	* Set Microsoft Entra admin: *{select your Entra user account}*
	* Server admin login: `sqladmin`
	* Password: `YourVeryStrongPassword123`
* Workload environment: **Development**
* Compute + storage: **General Purpose - Serverless**

### 1.4  Log Analytics Workspace

* Subscription: *{your subscription}*
* Resource group name: **rg-todo-manual**
* Name: `law-todo-manual`
* Region: **East US 2**

### 1.5 Function App

**Martketplace > Function App > Create Function App (Flex Consumption):**
* Basics:
	* Resource group: **rg-todo-manual**
	* Function App name: `func-todo-manual` *(must be globally unique)*
	*  Region: **East US 2**
	*  Runtime stack: **Python**
	* Version: **3.13**
	* Instance size: **2048 MB**
* Storage:
	* Storage account: **Create new** 
		* Name: `satodomanual` *(must be globally unique)*
* Networking:
	* Enable public access: **On**
	* Enable virtual network integration: **On**
		* Virtual Network: **vnet-todo-manual**
		* Outbound access > Enable VNet integration: **On**
			* Outbound subnet: **snet-outbound**
		* Storage networking > Storage public network access: **Enable public access from all networks** *(we will disable this and configure private network endpoint later)*
* Monitoring:
	* Enable Application Insights: **Yes**
	* Application Insights: **Create new**
		* Name: `insight-todo-manual`
		* Location: **East US 2**
		* Workspace: **law-todo-manual**
* Deployment:
	* Continuous deployment: **Disable**
	* Authentication settings > Basic authentication: **Enable**
* Authentication:
	* Resource authentication:
		* Host storage (AzureWebJobsStorage) > **Managed Identity**
		* Deployment storage > **Managed Identity**
		* Application Insights > **Managed Identity**
	* Managed identity: **System-assigned managed identity**

### 1.7 Private Endpoints

**sql-todo-manual  > Networking > Private access > Create a private endpoint:**
* Basics:
	* Resource group: **rg-todo-manual**
	* Name: `pe-sql`
	* Network Interface Name:  `pe-sql-nic`
	* Region: **East US 2**
* Resource:
	* Resource type: **Microsoft.Sql/servers**
	* Resource: **sql-todo-manual**
	* Target sub-resource: **sqlServer**
* Virtual Network:
	* Virtual network: **vnet-todo-manual**
	* Subnet: **snet-private**
* DNS:
	* Integrate with private DNS zone: **Yes**
		* Configuration name: **privatelink-database-windows-net**
		* Subscription: *{Your subscription}*
		* Resource group: **rg-todo-manual**
		* Private DNS zone: **(new) privatelink.database.windows.net**

**satodomanual > Networking > Private endpoints > Create a private endpoint:**
* Basics:
	* Resource group: **rg-todo-manual**
	* Name: `pe-storage`
	* Network Interface Name:  `pe-storage-nic`
	* Region: **East US 2**
* Resource:
	* Resource type: **  Microsoft.Storage/storageAccounts**
	* Resource: **satodomanual**
	* Target sub-resource: **blob**
* Virtual Network:
	* Virtual network: **vnet-todo-manual**
	* Subnet: **snet-private**
* DNS:
	* Integrate with private DNS zone: **Yes**
		* Configuration name: **privatelink-blob-windows-net**
		* Subscription: *{Your subscription}*
		* Resource group: **rg-todo-manual**
		* Private DNS zone: **(new) privatelink.blob.core.windows.net**

**satodomanual > Security * networking > Networking > Public access:**
* Public network access > Manage: **Disable***

**satodomanual > Settings > Configurations:**
* Allow Blob anonymous access: **Disable**

### 1.8 Static Web App

* Basics:
	* Resource group: **rg-todo-manual**
	* Name: `swa-todo-manual`
	* Plan type: **Free**
	* Deployment details > Source: **Other**
* Deployment configuration:
	* Deployment authorization policy: **Deployment token**
* Advanced:
	* Region for Azure Functions API and staging environments: **East US 2**

---

## Step 2: Grant Database Access to Function App Managed Identity

1. **Enable Managed Identity on the Function App**
	* Go to your Function App **func-todo-manual** in the portal.
	* Under **Settings**, click **Identity**.
	* Under **System assigned**, ensure the **Status** is **On**.
2. 

---

## Step 2: Configure Backend (Function App)

1. **Get SQL Connection String:**
   - Go to your SQL Database resource.
   - Click **Connection strings**.
   - Copy the `ADO.NET` (SQL authentication) string.
   - Replace `{your_password}` with the password you created earlier.

2. **Add Setting to Function App:**
   - Go to your Function App resource.
   - Click **Settings** > **Environment variables**.
   - Add a new App Setting:
     - Name: `MSSQL_CONNECTION_STRING`
     - Value: `<Your connection string>`
   - Click **Apply**.

3. **Deploy Backend Code:**
   - Open your terminal in the project root.
   - Run:
     ```bash
     func azure functionapp publish func-todo-manual
     ```
   - Wait for the deployment to finish.

4. **Enable CORS:**
   - The SWA needs permission to talk to the Function App.
   - Go to the Function App > **CORS**.
   - Add the URL of your Static Web App (e.g., `https://agreeable-glacier-123.azurestaticapps.net`).
   - Click **Save**.

---

## Step 3: Configure Frontend (Static Web App)

1. **Update API URL:**
   - Open `templates/index.html`.
   - Find the line `let API_URL = ...`.
   - Replace it with your actual Function App URL:
     ```javascript
     let API_URL = "https://func-todo-manual.azurewebsites.net/api/todos";
     ```

2. **Deploy Frontend:**
   - Run the SWA CLI deploy command:
     ```bash
     swa deploy ./templates --env production --deployment-token <YOUR_SWA_DEPLOYMENT_TOKEN>
     ```
   - Use the token you copied in Step 1.4.

---

## Step 4: Verify

1. Open the URL provided by the SWA CLI output (or find it in the Azure Portal under your Static Web App).
2. The app should load.
3. Try adding a Todo item. If it appears, the frontend is successfully talking to the database via the Function App!
