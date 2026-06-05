#!/bin/bash

# EKS Cluster Setup Script
# This script creates an EKS cluster with all necessary configurations

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-recommendation-cluster}"
NODE_TYPE="${NODE_TYPE:-t3.medium}"
NODE_COUNT="${NODE_COUNT:-2}"
MIN_NODES="${MIN_NODES:-2}"
MAX_NODES="${MAX_NODES:-5}"

echo -e "${GREEN}Starting EKS Cluster Setup...${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
for cmd in aws eksctl kubectl; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
done

# Create EKS cluster
echo -e "${YELLOW}Creating EKS cluster (this may take 15-20 minutes)...${NC}"
eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $AWS_REGION \
    --nodegroup-name standard-workers \
    --node-type $NODE_TYPE \
    --nodes $NODE_COUNT \
    --nodes-min $MIN_NODES \
    --nodes-max $MAX_NODES \
    --managed \
    --with-oidc \
    --ssh-access \
    --ssh-public-key ~/.ssh/id_rsa.pub \
    --full-ecr-access

echo -e "${GREEN}EKS cluster created successfully${NC}"

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Install metrics server for HPA
echo -e "${YELLOW}Installing metrics server...${NC}"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Create namespace (optional)
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace recommendation-system --dry-run=client -o yaml | kubectl apply -f -

# Install AWS Load Balancer Controller (optional but recommended)
echo -e "${YELLOW}Installing AWS Load Balancer Controller...${NC}"
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json || true

eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --approve

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller || true

echo -e "${GREEN}EKS cluster setup completed!${NC}"
echo -e "${YELLOW}Cluster Name: $CLUSTER_NAME${NC}"
echo -e "${YELLOW}Region: $AWS_REGION${NC}"
echo -e "${YELLOW}To verify cluster status, run:${NC}"
echo -e "kubectl get nodes"

# Made with Bob
