#!/bin/bash

# Q CLI Agent Hook - AWS Profile Context
# Simple script to provide AWS profile context for Q CLI

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed"
    exit 0
fi

# Check if AWS config exists
if [ ! -f ~/.aws/config ]; then
    echo "No AWS config file found"
    exit 0
fi

echo "=== Available AWS Profiles ==="
echo ""

# Get all profiles
profiles=$(aws configure list-profiles 2>/dev/null)

if [ -z "$profiles" ]; then
    echo "No AWS profiles configured"
    exit 0
fi

# Display each profile with basic info
for profile in $profiles; do
    echo "Profile: $profile"
    
    if [ "$profile" = "default" ]; then
        account=$(aws configure get sso_account_id 2>/dev/null || echo "Not configured")
        role=$(aws configure get sso_role_name 2>/dev/null || echo "Not configured")
        region=$(aws configure get region 2>/dev/null || echo "Not configured")
    else
        account=$(aws configure get sso_account_id --profile "$profile" 2>/dev/null || echo "Not configured")
        role=$(aws configure get sso_role_name --profile "$profile" 2>/dev/null || echo "Not configured")
        region=$(aws configure get region --profile "$profile" 2>/dev/null || echo "Not configured")
    fi
    
    echo "  Account: $account"
    echo "  Role: $role"
    echo "  Default region: $region"
    echo ""
done

echo "=== Usage Reminder ==="
echo "Always use --profile flag with AWS commands:"
echo "  aws s3 ls --profile <profile-name>"
echo "  aws ec2 describe-instances --profile <profile-name>"
echo ""