#!/bin/bash

# Cleanup Script for EKS Deployment
# This script removes all AWS resources created during deployment

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-recommendation-cluster}"
ECR_REPO_NAME="${ECR_REPO_NAME:-recommendation-system}"

echo -e "${YELLOW}Starting cleanup process...${NC}"
echo -e "${RED}WARNING: This will delete all resources!${NC}"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

# Delete Kubernetes resources
echo -e "${YELLOW}Deleting Kubernetes resources...${NC}"
kubectl delete -f k8s/ --ignore-not-found=true || true
echo -e "${GREEN}Kubernetes resources deleted${NC}"

# Wait for LoadBalancer to be deleted
echo -e "${YELLOW}Waiting for LoadBalancer to be deleted...${NC}"
sleep 30

# Delete EKS cluster
echo -e "${YELLOW}Deleting EKS cluster (this may take 10-15 minutes)...${NC}"
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION --wait || true
echo -e "${GREEN}EKS cluster deleted${NC}"

# Delete ECR repository
echo -e "${YELLOW}Deleting ECR repository...${NC}"
aws ecr delete-repository \
    --repository-name $ECR_REPO_NAME \
    --region $AWS_REGION \
    --force || true
echo -e "${GREEN}ECR repository deleted${NC}"

# Clean up local Docker images
echo -e "${YELLOW}Cleaning up local Docker images...${NC}"
docker rmi $ECR_REPO_NAME:latest || true
docker rmi $(docker images -q $ECR_REPO_NAME) || true
echo -e "${GREEN}Local Docker images cleaned${NC}"

echo -e "${GREEN}Cleanup completed successfully!${NC}"
echo -e "${YELLOW}Note: Some resources may take a few minutes to fully delete${NC}"

# Made with Bob
