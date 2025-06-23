#!/bin/bash

# EC2 instance configuration
export INSTANCE_TYPE="t3.medium"
export KEY_NAME="llm-deployment-key"
export SECURITY_GROUP="llm-api-sg"

# image configuration
# US East (N. Virginia) - us-east-1
# export AMI_ID="ami-0c02fb55956c7d316"
# US West (Oregon) - us-west-2  
export AMI_ID="ami-0efcece6bed30fd98"
# Asia Pacific (Singapore) - ap-southeast-1
# export AMI_ID="ami-0da59f1af71ea4ad2"

# network configuration
export REGION="us-east-2"
export AVAILABILITY_ZONE="us-east-2a"

# application configuration
export APP_PORT="8000"                  # API port
export SSH_PORT="22"                    # SSH port

# label configuration
export PROJECT_NAME="llm-deployment"
export ENVIRONMENT="development"        # development, staging, production