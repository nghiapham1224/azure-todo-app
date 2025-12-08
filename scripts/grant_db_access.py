import os
import struct
import pyodbc
import subprocess
import json
import time

def get_az_access_token():
    print("Getting Azure Access Token...")
    try:
        # Get token for SQL Database
        cmd = ["az", "account", "get-access-token", "--resource", "https://database.windows.net/", "--output", "json"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)["accessToken"]
    except Exception as e:
        print(f"Error getting token: {e}")
        return None

def add_firewall_rule(rg, server):
    print(f"Adding Client IP to Firewall on {server}...")
    try:
        # Add current client IP
        subprocess.run(
            ["az", "sql", "server", "firewall-rule", "create", "-g", rg, "-s", server, "-n", "TempSetupRule", "--start-ip-address", "0.0.0.0", "--end-ip-address", "255.255.255.255"],
            check=True
        )
        print("Firewall rule added (Allow All temporarily).")
    except Exception as e:
        print(f"Firewall rule might already exist or failed: {e}")

def remove_firewall_rule(rg, server):
    print("Removing Temporary Firewall Rule...")
    try:
        subprocess.run(
            ["az", "sql", "server", "firewall-rule", "delete", "-g", rg, "-s", server, "-n", "TempSetupRule", "--yes"],
            check=True
        )
        print("Firewall rule removed.")
    except Exception as e:
        print(f"Error removing rule: {e}")

def main():
    print("--- Azure SQL Access Granter ---")
    rg = input("Enter Resource Group Name (e.g., rg-todo-dev): ").strip()
    server_name = input("Enter SQL Server Name (e.g., sql-todo-dev-xyz): ").strip()
    db_name = "TodoDB"
    func_name = input("Enter Function App Name (e.g., func-todo-dev-xyz): ").strip()

    # 1. Add Firewall Rule
    add_firewall_rule(rg, server_name)
    time.sleep(5) # Wait for propagation

    # 2. Connect and Run SQL
    token = get_az_access_token()
    if not token:
        return

    conn_str = f"Driver={{ODBC Driver 18 for SQL Server}};Server={server_name}.database.windows.net;Database={db_name};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    
    # Pack token for pyodbc
    # SQL_COPT_SS_ACCESS_TOKEN = 1256
    token_bytes = bytes(token, "utf-8")
    exptoken = b""
    for i in token_bytes:
        exptoken += bytes({i})
        exptoken += bytes({0})
    token_struct = struct.pack("=i", len(exptoken)) + exptoken

    try:
        print("Connecting to SQL Server...")
        conn = pyodbc.connect(conn_str, attrs_before={1256: token_struct})
        cursor = conn.cursor()

        print(f"Creating User for Managed Identity: {func_name}...")
        
        # Check if user exists
        check_user_sql = f"SELECT count(*) FROM sys.database_principals WHERE name = '{func_name}'"
        cursor.execute(check_user_sql)
        if cursor.fetchone()[0] == 0:
            cursor.execute(f"CREATE USER [{func_name}] FROM EXTERNAL PROVIDER")
            print("User created.")
        else:
            print("User already exists.")

        # Grant Roles
        print("Granting Roles...")
        cursor.execute(f"ALTER ROLE db_datareader ADD MEMBER [{func_name}]")
        cursor.execute(f"ALTER ROLE db_datawriter ADD MEMBER [{func_name}]")
        # cursor.execute(f"ALTER ROLE db_ddladmin ADD MEMBER [{func_name}]") # Optional
        
        conn.commit()
        print("SUCCESS! Function App has been granted access.")
        conn.close()

    except Exception as e:
        print(f"SQL Error: {e}")
        print("Make sure you are the AAD Admin of the SQL Server.")

    # 3. Cleanup
    remove_firewall_rule(rg, server_name)

if __name__ == "__main__":
    main()
