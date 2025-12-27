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

### 1. Resource Group
1. Go to **Resource groups** > **Create**.
2. Name: `rg-todo-manual` (or similar).
3. Region: **East US 2** (or your preferred region).

### 2. Virtual Network (VNet)
1. Search for **Virtual Networks > Create**.
2. **Resource Group:** `rg-todo-manual`.
3. **Virtual network name:** `vnet-todo-manual`.
4. **IP Address:** `10.0.0.0/16` (Default)
5. **Subnets:** Create two distinct subnets:
   - `snet-outbound`  
     - Subnet address range: `10.0.0.0/24`  
     - Subnet delegation: `Microsoft.App/environments`  
   - `snet-private`  
     - Subnet address range: `10.0.1.0/24`

### 2. SQL Database
1. Search for **SQL Databases** > **Create**.
2. **Resource Group:** `rg-todo-manual`.
3. **Database Name:** `todo-db`.
4. **Server:** Click **Create new**.
   - Server name: `sql-server-todo-unique` (must be globally unique).
   - Location: Same as Resource Group.
   - Authentication method: **Use both SQL and Microsoft Entra authentication**.
   - Set Microsoft Entra admin: use your entra user.
   - Server admin login: `sqladmin`.
   - Password: `YourStrongPassword123!`.
5. **Workload environment:** Select **Development**.
6. **Compute + storage:** **General Purpose - Serverless**.
7. **Networking:**
   - **Allow Azure services and resources to access this server:** YES (Important!).
   - **Add current client IP address:** YES (For local access).
6. **Pricing Tier:** Select **Basic** or **Free** (if available) to save costs.
7. Click **Review + create** > **Create**.

### 3. Azure Function App
1. Search for **Function App** > **Create**.
2. **Resource Group:** `rg-todo-manual`.
3. **Name:** `func-todo-manual` (must be unique).
4. **Runtime stack:** Python.
5. **Version:** 3.10 or 3.11.
6. **Region:** Same as Resource Group.
7. **Operating System:** Linux.
8. **Hosting:** **Consumption (Serverless)**.
9. Click **Review + create** > **Create**.

### 4. Azure Static Web App
1. Search for **Static Web Apps** > **Create**.
2. **Resource Group:** `rg-todo-manual`.
3. **Name:** `swa-todo-manual`.
4. **Plan type:** Free.
5. **Deployment details:** Select **Other**.
6. Click **Review + create** > **Create**.
7. **Important:** After creation, go to the resource, click **Manage deployment token**, and copy it. You will need this to deploy the frontend.

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
