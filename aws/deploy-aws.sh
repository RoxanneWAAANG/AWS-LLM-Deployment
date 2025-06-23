#!/bin/bash

# Configuration
INSTANCE_TYPE="t3.medium"
KEY_NAME="llm-deployment-key"
SECURITY_GROUP="llm-api-sg"
REGION="us-east-2"

# Get the latest Amazon Linux 2023 AMI ID dynamically
echo "Getting latest Amazon Linux 2023 AMI ID..."
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-*" \
              "Name=architecture,Values=x86_64" \
              "Name=virtualization-type,Values=hvm" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text \
    --region $REGION)

if [ "$AMI_ID" = "None" ] || [ -z "$AMI_ID" ]; then
    echo "Error: Could not find a valid Amazon Linux 2023 AMI"
    exit 1
fi

echo "Using AMI: $AMI_ID"

# Check if security group exists, create if it doesn't
echo "Checking security group..."
if ! aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION >/dev/null 2>&1; then
    echo "Creating security group..."
    aws ec2 create-security-group \
        --group-name $SECURITY_GROUP \
        --description "LLM API Security Group" \
        --region $REGION

    # Add ingress rules
    echo "Adding security group rules..."
    aws ec2 authorize-security-group-ingress \
        --group-name $SECURITY_GROUP \
        --protocol tcp \
        --port 8000 \
        --cidr 0.0.0.0/0 \
        --region $REGION

    aws ec2 authorize-security-group-ingress \
        --group-name $SECURITY_GROUP \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $REGION
else
    echo "Security group $SECURITY_GROUP already exists, using existing one"
fi

echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-groups $SECURITY_GROUP \
    --region $REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "Error: Failed to launch instance"
    exit 1
fi

echo "Instance ID: $INSTANCE_ID"
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

if [ $? -eq 0 ]; then
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --region $REGION \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    echo "Instance is running at: $PUBLIC_IP"
    echo "SSH command: ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
    echo "API will be available at: http://$PUBLIC_IP:8000"
    
    # Save instance details for future reference
    echo "Instance details saved to instance-info.txt"
    cat > instance-info.txt << EOF
Instance ID: $INSTANCE_ID
Public IP: $PUBLIC_IP
AMI ID: $AMI_ID
Instance Type: $INSTANCE_TYPE
Key Name: $KEY_NAME
Security Group: $SECURITY_GROUP
Region: $REGION
Launch Time: $(date)
EOF
else
    echo "Error: Instance failed to start properly"
    exit 1
fi