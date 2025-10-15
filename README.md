# AWS Organization Role Access for Amazon Q Developer CLI

Automate AWS CLI profile creation for multi-account role access in AWS Organizations, with integrated Amazon Q Developer CLI support.

## Overview

This tool streamlines AWS multi-account access by:

- **Generating AWS CLI profiles** for role-based access across organization accounts
- **Integrating with Amazon Q CLI** to provide automatic profile context
- **Using AWS Identity Center SSO** for centralized authentication

### The Multi-Account Challenge

Most AWS MCP servers (including Amazon Q's `use_aws` tool) assume AWS profiles are already configured and default to using a single "default" profile. This creates friction when working across multiple AWS accounts in an organization.

Job-based MCP servers like [AWS Security MCP](https://lobehub.com/mcp/groovybugify-aws-security-mcp) and [AWS IAM MCP](https://awslabs.github.io/mcp/servers/iam-mcp-server/) are particularly affected by this limitation. Without pre-configured profiles for each account, these MCP servers might analyze the default account, and leads to further setup for cross-account uses.

This sample proposes a solution on using agent hooks in pre-generate all necessary AWS CLI profiles for your organization's accounts and roles, then provide that context automatically to Amazon Q CLI through a custom agent. This enables job-based MCP servers to work effectively across your entire AWS Organization.

## Prerequisites

- **AWS SSO access** with appropriate permission sets for target accounts
- **AWS CLI configured** with Identity Center: `aws configure sso`

## Quick Start

### 1. Configure SSO Session

For the first time, set up an SSO session in your AWS config using your organization's SSO start URL and region through the command `aws configure sso`.

In your `~/.aws/config`, you should have:

```ini
[sso-session myorg]
sso_start_url = https://company.awsapps.com/start
sso_region = eu-central-1
sso_registration_scopes = sso:account:access
```

### 2. Generate Profiles

```bash
aws sso login --sso-session myorg
./scripts/create-aws-profiles.sh DBAReadOnly myorg
```

### 3. Test Access

```bash
# Profiles follow format: <sso-session>-<account-name>-<RoleName>
aws configure list-profiles
aws s3 ls --profile myorg-workload-DBAReadOnly
aws ec2 describe-instances --profile myorg-development-DBAReadOnly
```

## Amazon Q CLI Integration

The [included agent](.amazonq/cli-agents/org-awscli-agent.json) automatically provides AWS profile context when starting Q CLI conversations through either a commands or [custom script](.amazonq/cli-agents/scripts/q-agent-aws-context.sh) within the agent's hook.

### Setup Options

```bash
cd /path/to/sample-qcli-org-role-access
mkdir -p ~/.aws/amazonq/cli-agents/scripts
cp .amazonq/cli-agents/org-awscli-agent.json ~/.aws/amazonq/cli-agents/
cp .amazonq/cli-agents/scripts/q-agent-aws-context.sh ~/.aws/amazonq/cli-agents/scripts/
chmod +x ~/.aws/amazonq/cli-agents/scripts/q-agent-aws-context.sh
```

#### Global Usage

```bash
q agent list
aws sso login --sso-session myorg
q chat --agent org-awscli-agent
```

### What It Does

- Lists all configured AWS profiles with Account ID, Role, and Region
- Reminds you about using `--profile` flags
- Runs automatically when the agent starts

## Script Reference

### create-aws-profiles.sh

```bash
./scripts/create-aws-profiles.sh <ROLE_NAME> [SSO_SESSION]
```

- `ROLE_NAME`: IAM role name to create profiles for (required)
- `SSO_SESSION`: SSO session name (optional, defaults to 'myorg')

**Features:**

- Validates SSO session before proceeding
- Handles missing roles gracefully
- Prevents duplicate profiles
- Uses cached SSO tokens automatically

## File Structure

```text
# Global (user-wide)
~/.aws/amazonq/cli-agents/
├── org-awscli-agent.json
└── scripts/q-agent-aws-context.sh

# Local (project-specific)
.amazonq/cli-agents/
├── org-awscli-agent.json (need to modify path for hook if used locally)
└── scripts/q-agent-aws-context.sh
```

## Resources

- [Q Agent Documentation](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-custom-agents-defining.html)
- [Agent Configuration](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-custom-agents-configuration.html#command-line-agent-hooks)
- [File Locations](https://github.com/aws/amazon-q-developer-cli/blob/main/docs/agent-file-locations.md)
- [Q Hooks Documentation - Depreciated](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-context-hooks.html)
- [Q CLI - AWS_PROFILE environment variable - GitHub Issue #2088](https://github.com/aws/amazon-q-developer-cli/issues/2088)