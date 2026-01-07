#!/bin/bash

if ! az account show > /dev/null 2>/dev/null; then
    echo "Not logged in. Running az login..."
    az login
else
    echo "Already logged in as: $(az account show --query user.name -o tsv)"
    echo "Current subscription: $(az account show --query name -o tsv)"
fi

echo

# Ensure we are in the project root
cd "$(dirname "$0")/.."
echo "Current dir: $(pwd)"

echo

echo "Fetching configuration from Terraform..."
SQL_SERVER=$(terraform -chdir=terraform output -raw sql_server_hostname)
DB_NAME=$(terraform -chdir=terraform output -raw sql_database_name)
FUNC_NAME=$(terraform -chdir=terraform output -raw function_app_name)

if [ -z "$SQL_SERVER" ] || [ -z "$DB_NAME" ] || [ -z "$FUNC_NAME" ]; then
    echo "Error: Could not fetch configuration from Terraform outputs."
    exit 1
fi

echo

echo "Assigning roles for Function App: $FUNC_NAME"
echo "Target Server: $SQL_SERVER"
echo "Target Database: $DB_NAME"

echo

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

echo "Executing SQL via sqlcmd (using Azure AD authentication)..."
if sqlcmd -S "$SQL_SERVER" -d "$DB_NAME" -G -Q "$SQL_ROLE_ASSIGN"; then
    echo "Roles assigned successfully"
else
    exit 1
fi

echo

echo "Verifying database role membership..."
SQL_ROLE_CHECK=$(cat <<EOF
SELECT
    dp.name  AS DatabaseRole,
    mp.name  AS MemberName,
    mp.type_desc AS MemberType
FROM sys.database_role_members drm
JOIN sys.database_principals dp ON drm.role_principal_id = dp.principal_id
JOIN sys.database_principals mp ON drm.member_principal_id = mp.principal_id
WHERE mp.name = '$FUNC_NAME'
ORDER BY dp.name;
EOF)
sqlcmd -S "$SQL_SERVER" -d "$DB_NAME" -G -Q "$SQL_ROLE_CHECK" -y 30 -Y 30
