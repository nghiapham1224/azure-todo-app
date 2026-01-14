#!/bin/bash

# Color Defination
CLR_INFO='\033[0;36m'   # Cyan
CLR_OK='\033[0;32m'     # Green
CLR_ERR='\033[0;31m'    # Red
CLR_VAR='\033[1;33m'    # Bold Yellow
NC='\033[0m'            # No Color

# 1. Check Auth
if ! az account show > /dev/null 2>/dev/null; then
    echo -e "${CLR_INFO}[info]${NC} Not logged in. Running az login..."
    az login
else
    echo -e "${CLR_OK}[ok]${NC} Logged in as: $(az account show --query user.name -o tsv)"
    echo -e "${CLR_INFO}[info]${NC} Azure Subscription: $(az account show --query name -o tsv)"
fi

# 2. Get Config
cd "$(dirname "$0")/.."
echo -e "${CLR_INFO}[info]${NC} Fetching Terraform outputs..."

RG_NAME=$(terraform -chdir=terraform output -raw resource_group_name)
SQL_SERVER_NAME=$(terraform -chdir=terraform output -raw sql_server_name)
SQL_SERVER_HOSTNAME=$(terraform -chdir=terraform output -raw sql_server_hostname)
DB_NAME=$(terraform -chdir=terraform output -raw sql_database_name)
FUNC_NAME=$(terraform -chdir=terraform output -raw function_app_name)
MY_IP=$(curl -s https://ipv4.icanhazip.com)

echo -e "  ${NC}Resource Group: ${CLR_VAR}$RG_NAME"
echo -e "  ${NC}SQL Server:     ${CLR_VAR}$SQL_SERVER_NAME"
echo -e "  ${NC}Database:       ${CLR_VAR}$DB_NAME"
echo -e "  ${NC}Function App:   ${CLR_VAR}$FUNC_NAME"
echo -e "  ${NC}Local IP:       ${CLR_VAR}$MY_IP"

if [ -z "$SQL_SERVER_NAME" ]; then
    echo -e "${CLR_ERR}[error]${NC} Could not fetch Terraform outputs."
    exit 1
fi

# 3. Networking
echo -e "${CLR_INFO}[info]${NC} Enabling public access for: ${CLR_VAR}$SQL_SERVER_NAME${NC}"
az sql server update -g $RG_NAME -n $SQL_SERVER_NAME --set publicNetworkAccess="Enabled" > /dev/null

echo -e "${CLR_INFO}[info]${NC} Adding firewall rule for IP: ${CLR_VAR}$MY_IP${NC}"
az sql server firewall-rule create -g $RG_NAME -s $SQL_SERVER_NAME -n AllowTempLocalIP --start-ip-address $MY_IP --end-ip-address $MY_IP > /dev/null

echo -ne "${CLR_INFO}[info]${NC} Waiting for propagation"
for i in {1..30}; do
    echo -ne "."
    sleep 1
done
echo -e " Done!${NC}"

# 4. SQL Roles
SQL_ROLE_ASSIGN=$(cat <<EOF
SET NOCOUNT ON;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$FUNC_NAME')
BEGIN
    CREATE USER [$FUNC_NAME] FROM EXTERNAL PROVIDER;
END
ALTER ROLE db_datareader ADD MEMBER [$FUNC_NAME];
ALTER ROLE db_datawriter ADD MEMBER [$FUNC_NAME];
ALTER ROLE db_ddladmin   ADD MEMBER [$FUNC_NAME];
EOF
)

echo -e "${CLR_INFO}[info]${NC} Assigning roles to: ${CLR_VAR}$FUNC_NAME${NC}"
if sqlcmd -S "$SQL_SERVER_HOSTNAME" -d "$DB_NAME" -G -Q "$SQL_ROLE_ASSIGN"; then
    echo -e "${CLR_OK}[ok]${NC} Roles assigned successfully."
else
    echo -e "${CLR_ERR}[error]${NC} SQL execution failed."
    exit 1
fi

# 5. Verify
echo -e "${CLR_INFO}[info]${NC} Verifying database role membership..."
SQL_ROLE_CHECK=$(cat <<EOF
SET NOCOUNT ON;
SELECT
    dp.name  AS DatabaseRole,
    mp.name  AS MemberName,
    mp.type_desc AS MemberType
FROM sys.database_role_members drm
JOIN sys.database_principals dp ON drm.role_principal_id = dp.principal_id
JOIN sys.database_principals mp ON drm.member_principal_id = mp.principal_id
WHERE mp.name = '$FUNC_NAME'
ORDER BY dp.name;
EOF
)
sqlcmd -S "$SQL_SERVER_HOSTNAME" -d "$DB_NAME" -G -Q "$SQL_ROLE_CHECK" -y 30 -Y 30

# 6. Cleanup
echo -e "${CLR_INFO}[info]${NC} Removing firewall rule and disabling public access..."
az sql server firewall-rule delete -g $RG_NAME -s $SQL_SERVER_NAME -n AllowTempLocalIP > /dev/null
az sql server update -g $RG_NAME -n $SQL_SERVER_NAME --set publicNetworkAccess="Disabled" > /dev/null

echo -e "${CLR_OK}[ok]${NC} Cleanup complete."
