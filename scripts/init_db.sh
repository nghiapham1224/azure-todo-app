#!/bin/bash

# Ensure we are in the project root
cd "$(dirname "$0")/.."

echo "Fetching configuration from Terraform..."
FUNC_URL=$(terraform -chdir=terraform output -raw function_app_url)

if [ -z "$FUNC_URL" ]; then
    echo "Error: Could not fetch function_app_url from Terraform outputs."
    exit 1
fi

INIT_URL="${FUNC_URL}/api/init"

echo "Initializing database via: $INIT_URL"
echo "Sending POST request..."

RESPONSE=$(curl -s -X POST "$INIT_URL")

if [[ $RESPONSE == *"initialized"* ]]; then
    echo "Success: $RESPONSE"
else
    echo "Error or unexpected response: $RESPONSE"
    echo "Check if the function app is deployed and running."
    exit 1
fi
