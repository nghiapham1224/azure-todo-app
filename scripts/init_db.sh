#!/bin/bash

# Color Definiation
CLR_INFO='\033[0;36m'
CLR_OK='\033[0;32m'
CLR_ERR='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

echo -e "${CLR_INFO}[info]${NC} Fetching Function URL..."
FUNC_URL=$(terraform -chdir=terraform output -raw function_app_url)

if [ -z "$FUNC_URL" ]; then
    echo -e "${CLR_ERR}[error]${NC} Could not fetch function_app_url."
    exit 1
fi

INIT_URL="${FUNC_URL}/api/init"

echo -e "${CLR_INFO}[info]${NC} Calling: $INIT_URL"
RESPONSE=$(curl -s -X POST "$INIT_URL")

if [[ $RESPONSE == *"initialized"* ]]; then
    echo -e "${CLR_OK}[ok]${NC} Success: $RESPONSE"
else
    echo -e "${CLR_ERR}[error]${NC} Unexpected response: $RESPONSE"
    exit 1
fi
