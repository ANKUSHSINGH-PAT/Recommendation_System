#!/bin/bash

# EKS Deployment Script for Recommendation System
# This script automates the deployment process to AWS EKS

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-recommendation-cluster}"
ECR_REPO_NAME="${ECR_REPO_NAME:-recommendation-system}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo -e "${GREEN}Starting EKS Deployment Process...${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in aws kubectl docker; do
    if ! command_exists $cmd; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
done
echo -e "${GREEN}All prerequisites met${NC}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}AWS Account ID: $AWS_ACCOUNT_ID${NC}"

# Build ECR repository URL
ECR_REPO_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"

# Step 1: Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t $ECR_REPO_NAME:$IMAGE_TAG .
echo -e "${GREEN}Docker image built successfully${NC}"

# Step 2: Tag image for ECR
echo -e "${YELLOW}Tagging image for ECR...${NC}"
docker tag $ECR_REPO_NAME:$IMAGE_TAG $ECR_REPO_URL:$IMAGE_TAG

# Step 3: Login to ECR
echo -e "${YELLOW}Logging in to ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Step 4: Create ECR repository if it doesn't exist
echo -e "${YELLOW}Checking ECR repository...${NC}"
if ! aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION >/dev/null 2>&1; then
    echo -e "${YELLOW}Creating ECR repository...${NC}"
    aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION
    echo -e "${GREEN}ECR repository created${NC}"
else
    echo -e "${GREEN}ECR repository already exists${NC}"
fi

# Step 5: Push image to ECR
echo -e "${YELLOW}Pushing image to ECR...${NC}"
docker push $ECR_REPO_URL:$IMAGE_TAG
echo -e "${GREEN}Image pushed successfully${NC}"

# Step 6: Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Step 7: Update deployment YAML with correct image
echo -e "${YELLOW}Updating deployment YAML...${NC}"
sed -i.bak "s|<AWS_ACCOUNT_ID>|$AWS_ACCOUNT_ID|g" k8s/flask-deployment.yaml
sed -i.bak "s|<AWS_REGION>|$AWS_REGION|g" k8s/flask-deployment.yaml

# Step 8: Apply Kubernetes manifests
echo -e "${YELLOW}Applying Kubernetes secrets...${NC}"
kubectl apply -f k8s/secrets.yaml

echo -e "${YELLOW}Applying deployment...${NC}"
kubectl apply -f k8s/flask-deployment.yaml

echo -e "${YELLOW}Applying HPA...${NC}"
kubectl apply -f k8s/hpa.yaml

# Step 9: Wait for deployment
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/flask-app

# Step 10: Get service URL
echo -e "${YELLOW}Getting service URL...${NC}"
kubectl get service flask-service

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}To get the LoadBalancer URL, run:${NC}"
echo -e "kubectl get service flask-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"

# Made with Bob
