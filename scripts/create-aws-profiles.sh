#!/bin/bash

# AWS Profile Creator
# Creates AWS CLI profiles for a specific role across all organization accounts
#
# Notes:
# - Gracefully handles accounts where the role doesn't exist (skips with message)
# - Prevents duplicate profiles when re-running the script
# - Validates SSO session exists before proceeding
# - Uses SSO session name, lowercase account names, and original role names for profile naming (e.g., "myorg-myaccount-DBAReadOnly")
#
# Example usage:
# ./create-aws-profiles.sh DBA
# ./create-aws-profiles.sh DBAReadOnly my-sso-session

ROLE_NAME="$1"
SSO_SESSION="${2:-myorg}"

show_usage() {
    echo "Usage: $0 <ROLE_NAME> [SSO_SESSION]"
    echo ""
    echo "Arguments:"
    echo "  ROLE_NAME    The role name to create profiles for (required)"
    echo "  SSO_SESSION  The SSO session name to use (optional, defaults to 'myorg')"
    echo ""
    echo "Examples:"
    echo "  $0 DBA"
    echo "  $0 DBA my-company-sso"
    echo "  $0 ReadOnlyAccess prod-session"
    echo ""
    echo "To find available SSO sessions, check your ~/.aws/config file for [sso-session <name>] entries"
    echo "Or run: grep '\\[sso-session' ~/.aws/config"
}

if [ -z "$ROLE_NAME" ]; then
    show_usage
    exit 1
fi

# Validate that the SSO session exists in AWS config
if ! grep -q "\\[sso-session $SSO_SESSION\\]" ~/.aws/config 2>/dev/null; then
    echo "Error: SSO session '$SSO_SESSION' not found in ~/.aws/config"
    echo ""
    echo "Available SSO sessions:"
    grep '\\[sso-session' ~/.aws/config 2>/dev/null | sed 's/\\[sso-session \\(.*\\)\\]/  \\1/' || echo "  No SSO sessions found in ~/.aws/config"
    echo ""
    echo "Please configure an SSO session first or specify an existing one."
    exit 1
fi

echo "Using SSO session: $SSO_SESSION"
echo "Creating profiles for role: $ROLE_NAME"
echo ""

# Get access token from SSO cache
echo "Retrieving SSO access token..."
if [ ! -d ~/.aws/sso/cache/ ] || [ -z "$(ls ~/.aws/sso/cache/*.json 2>/dev/null)" ]; then
    echo "Error: No SSO cache found. Please login first:"
    echo "  aws sso login --sso-session $SSO_SESSION"
    exit 1
fi

# Get the most recent cache file that contains accessToken
CACHE_FILE=$(ls -t ~/.aws/sso/cache/*.json | xargs grep -l "accessToken" | head -n 1)
if [ -z "$CACHE_FILE" ]; then
    echo "Error: No access token found in SSO cache. Please login first:"
    echo "  aws sso login --sso-session $SSO_SESSION"
    exit 1
fi

ACCESS_TOKEN=$(jq -r '.accessToken' "$CACHE_FILE" 2>/dev/null)
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Invalid access token in cache. Please login again:"
    echo "  aws sso login --sso-session $SSO_SESSION"
    exit 1
fi

# Get all accounts using access token
echo "Fetching account list..."
accounts_json=$(aws sso list-accounts --access-token "$ACCESS_TOKEN" --query 'accountList[].{id:accountId,name:accountName}' --output json 2>/dev/null)

if [ -z "$accounts_json" ] || [ "$accounts_json" = "null" ]; then
    echo "Error: Failed to fetch accounts. Please login again:"
    echo "  aws sso login --sso-session $SSO_SESSION"
    exit 1
fi

echo "$accounts_json" | jq -r '.[] | "\(.id) \(.name)"' | \
while read -r account_id account_name; do
    # Check if role exists in this account using access token
    if aws sso list-account-roles --account-id "$account_id" --access-token "$ACCESS_TOKEN" --query "roleList[?roleName=='$ROLE_NAME'].roleName" --output text 2>/dev/null | grep -q "$ROLE_NAME"; then
        # Create profile name: SSO session + lowercase account name + original role name
        account_name_lower=$(echo "$account_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        profile_name="${SSO_SESSION}-${account_name_lower}-${ROLE_NAME}"
        
        # Skip if profile already exists with correct configuration
        if aws configure get sso_account_id --profile "$profile_name" 2>/dev/null | grep -q "$account_id"; then
            echo "Profile '$profile_name' already exists - skipping"
        else
            echo "Creating profile: $profile_name for account: $account_name ($account_id)"
            
            aws configure set sso_session "$SSO_SESSION" --profile "$profile_name"
            aws configure set sso_account_id "$account_id" --profile "$profile_name"
            aws configure set sso_role_name "$ROLE_NAME" --profile "$profile_name"
            aws configure set region "us-east-1" --profile "$profile_name"
        fi
    else
        echo "Role '$ROLE_NAME' not found in account: $account_name ($account_id) - skipping"
    fi
done

echo ""
echo "Profile creation completed!"