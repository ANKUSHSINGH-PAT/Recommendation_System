# EKS Cluster Setup Script for PowerShell
# This script creates an EKS cluster with all necessary components

# Configuration
$AWS_REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
$CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "recommendation-cluster" }

Write-Host "Starting EKS Cluster Setup..." -ForegroundColor Green
Write-Host "Region: $AWS_REGION" -ForegroundColor Yellow
Write-Host "Cluster Name: $CLUSTER_NAME" -ForegroundColor Yellow

# Check prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow
$commands = @("aws", "kubectl", "eksctl")
foreach ($cmd in $commands) {
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "Error: $cmd is not installed" -ForegroundColor Red
        exit 1
    }
}
Write-Host "All prerequisites met" -ForegroundColor Green

# Create EKS cluster
Write-Host "`nCreating EKS cluster (this will take 15-20 minutes)..." -ForegroundColor Yellow
eksctl create cluster `
  --name $CLUSTER_NAME `
  --region $AWS_REGION `
  --nodegroup-name standard-workers `
  --node-type t3.medium `
  --nodes 2 `
  --nodes-min 2 `
  --nodes-max 5 `
  --managed `
  --with-oidc `
  --full-ecr-access

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create EKS cluster" -ForegroundColor Red
    exit 1
}

Write-Host "`nCluster created successfully!" -ForegroundColor Green

# Update kubeconfig
Write-Host "`nUpdating kubeconfig..." -ForegroundColor Yellow
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify cluster
Write-Host "`nVerifying cluster..." -ForegroundColor Yellow
kubectl get nodes

# Install metrics server for HPA
Write-Host "`nInstalling metrics server..." -ForegroundColor Yellow
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for metrics server
Write-Host "`nWaiting for metrics server to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
kubectl get deployment metrics-server -n kube-system

Write-Host "`nEKS Cluster setup completed successfully!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run: .\scripts\deploy.ps1" -ForegroundColor Cyan
Write-Host "2. Or follow the manual deployment steps in EKS_DEPLOYMENT_GUIDE.md" -ForegroundColor Cyan

# Made with Bob