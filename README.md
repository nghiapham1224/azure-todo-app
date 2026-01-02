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
