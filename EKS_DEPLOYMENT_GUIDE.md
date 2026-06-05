# EKS Deployment Guide for Recommendation System

This comprehensive guide will walk you through deploying your Flask-based Recommendation System on Amazon EKS (Elastic Kubernetes Service).

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [Monitoring and Maintenance](#monitoring-and-maintenance)
5. [Troubleshooting](#troubleshooting)
6. [Cost Optimization](#cost-optimization)

---

## Prerequisites

### Required Tools
Install the following tools before proceeding:

1. **AWS CLI** (v2.x or later)
   ```bash
   # Windows (PowerShell)
   msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
   
   # Verify installation
   aws --version
   ```

2. **kubectl** (Kubernetes CLI)
   ```bash
   # Windows (PowerShell)
   curl -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
   
   # Verify installation
   kubectl version --client
   ```

3. **eksctl** (EKS CLI)
   ```bash
   # Windows (PowerShell)
   choco install eksctl
   
   # Or download from: https://github.com/weaveworks/eksctl/releases
   
   # Verify installation
   eksctl version
   ```

4. **Docker Desktop**
   - Download from: https://www.docker.com/products/docker-desktop
   - Ensure Docker is running

5. **Helm** (Optional, for advanced deployments)
   ```bash
   choco install kubernetes-helm
   ```

### AWS Account Setup

1. **Configure AWS Credentials**
   ```bash
   aws configure
   ```
   Provide:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (e.g., us-east-1)
   - Default output format (json)

2. **Verify AWS Configuration**
   ```bash
   aws sts get-caller-identity
   ```

3. **Required IAM Permissions**
   Your AWS user/role needs permissions for:
   - EKS (create/manage clusters)
   - EC2 (create/manage instances, VPC, security groups)
   - ECR (create/manage container registries)
   - IAM (create/manage roles and policies)
   - CloudFormation (for eksctl)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              EKS Cluster                            │    │
│  │                                                     │    │
│  │  ┌──────────────┐  ┌──────────────┐               │    │
│  │  │   Pod 1      │  │   Pod 2      │               │    │
│  │  │ Flask App    │  │ Flask App    │  ...          │    │
│  │  └──────────────┘  └──────────────┘               │    │
│  │         │                  │                       │    │
│  │         └──────────┬───────┘                       │    │
│  │                    │                               │    │
│  │         ┌──────────▼──────────┐                    │    │
│  │         │  LoadBalancer Svc   │                    │    │
│  │         └──────────┬──────────┘                    │    │
│  │                    │                               │    │
│  └────────────────────┼───────────────────────────────┘    │
│                       │                                     │
│         ┌─────────────▼──────────────┐                     │
│         │  Network Load Balancer     │                     │
│         └─────────────┬──────────────┘                     │
│                       │                                     │
└───────────────────────┼─────────────────────────────────────┘
                        │
                        ▼
                   Internet Users
```

**Components:**
- **EKS Cluster**: Managed Kubernetes control plane
- **Worker Nodes**: EC2 instances running your pods (t3.medium)
- **ECR**: Container registry for Docker images
- **Network Load Balancer**: Distributes traffic to pods
- **HPA**: Horizontal Pod Autoscaler (scales 2-10 pods)
- **Secrets**: Stores API keys and sensitive data

---

## Step-by-Step Deployment

### Phase 1: Prepare Your Environment

#### 1.1 Update Your Secrets
Edit `k8s/secrets.yaml` and add your actual API keys:

```yaml
stringData:
  GROQ_API_KEY: "your-actual-groq-api-key"
  ASTRA_DB_TOKEN: "your-actual-astra-db-token"
  ASTRA_DB_ENDPOINT: "your-actual-astra-db-endpoint"
  HUGGINGFACE_TOKEN: "your-actual-huggingface-token"
```

**Important:** Never commit secrets to Git. Add `k8s/secrets.yaml` to `.gitignore`.

#### 1.2 Review Dockerfile
The Dockerfile is already created. Review it to ensure it meets your needs:
```bash
cat Dockerfile
```

---

### Phase 2: Create EKS Cluster

#### Option A: Automated Setup (Recommended)

```bash
# Make script executable (Git Bash or WSL)
chmod +x scripts/setup-eks-cluster.sh

# Run the setup script
./scripts/setup-eks-cluster.sh
```

This script will:
- Create an EKS cluster with 2-5 worker nodes
- Install metrics server for autoscaling
- Configure AWS Load Balancer Controller
- Set up OIDC provider for IAM roles

**Time Required:** 15-20 minutes

#### Option B: Manual Setup

```bash
# Set your configuration
export AWS_REGION=us-east-1
export CLUSTER_NAME=recommendation-cluster

# Create EKS cluster
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed \
  --with-oidc \
  --full-ecr-access

# Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify cluster
kubectl get nodes
```

#### 2.1 Install Metrics Server (for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics server
kubectl get deployment metrics-server -n kube-system
```

---

### Phase 3: Build and Push Docker Image

#### 3.1 Create ECR Repository

```bash
# Set variables
export AWS_REGION=us-east-1
export ECR_REPO_NAME=recommendation-system

# Create ECR repository
aws ecr create-repository \
  --repository-name $ECR_REPO_NAME \
  --region $AWS_REGION

# Get repository URI
aws ecr describe-repositories \
  --repository-names $ECR_REPO_NAME \
  --region $AWS_REGION \
  --query 'repositories[0].repositoryUri' \
  --output text
```

#### 3.2 Build Docker Image

```bash
# Build the image
docker build -t recommendation-system:latest .

# Test locally (optional)
docker run -p 5000:5000 --env-file .env recommendation-system:latest
```

#### 3.3 Push to ECR

```bash
# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Tag image
docker tag recommendation-system:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest

# Push image
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest
```

---

### Phase 4: Deploy to EKS

#### Option A: Automated Deployment (Recommended)

```bash
# Make script executable
chmod +x scripts/deploy.sh

# Set environment variables
export AWS_REGION=us-east-1
export CLUSTER_NAME=recommendation-cluster
export ECR_REPO_NAME=recommendation-system

# Run deployment script
./scripts/deploy.sh
```

#### Option B: Manual Deployment

```bash
# Update deployment YAML with your ECR image
# Edit k8s/flask-deployment.yaml and replace:
# <AWS_ACCOUNT_ID> with your AWS account ID
# <AWS_REGION> with your region

# Apply secrets
kubectl apply -f k8s/secrets.yaml

# Apply deployment
kubectl apply -f k8s/flask-deployment.yaml

# Apply HPA
kubectl apply -f k8s/hpa.yaml

# Check deployment status
kubectl rollout status deployment/flask-app

# Get pods
kubectl get pods -l app=flask

# Get service
kubectl get service flask-service
```

---

### Phase 5: Access Your Application

#### 5.1 Get LoadBalancer URL

```bash
# Get the external URL
kubectl get service flask-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Note:** It may take 2-3 minutes for the LoadBalancer to be provisioned.

#### 5.2 Test the Application

```bash
# Get the URL
export LB_URL=$(kubectl get service flask-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test the endpoint
curl http://$LB_URL/

# Test metrics endpoint
curl http://$LB_URL/metrics
```

#### 5.3 Access in Browser

Open your browser and navigate to:
```
http://<LoadBalancer-URL>
```

---

## Monitoring and Maintenance

### View Logs

```bash
# Get pod names
kubectl get pods -l app=flask

# View logs for a specific pod
kubectl logs <pod-name>

# Follow logs in real-time
kubectl logs -f <pod-name>

# View logs from all pods
kubectl logs -l app=flask --all-containers=true
```

### Monitor Resources

```bash
# Check pod resource usage
kubectl top pods

# Check node resource usage
kubectl top nodes

# Check HPA status
kubectl get hpa

# Describe HPA for details
kubectl describe hpa flask-app-hpa
```

### Scale Manually

```bash
# Scale to specific number of replicas
kubectl scale deployment flask-app --replicas=5

# Check scaling status
kubectl get deployment flask-app
```

### Update Application

```bash
# Build new image with new tag
docker build -t recommendation-system:v2 .

# Tag and push to ECR
docker tag recommendation-system:v2 $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:v2
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:v2

# Update deployment
kubectl set image deployment/flask-app flask-container=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:v2

# Check rollout status
kubectl rollout status deployment/flask-app

# Rollback if needed
kubectl rollout undo deployment/flask-app
```

### Prometheus Integration

Your app already exposes metrics at `/metrics`. To set up Prometheus:

```bash
# Apply Prometheus manifests
kubectl apply -f prometheus/prometheus-configmap.yaml
kubectl apply -f prometheus/prometheus-deployment.yaml

# Access Prometheus
kubectl port-forward -n default svc/prometheus-service 9090:9090
```

Then open: http://localhost:9090

---

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting

```bash
# Check pod status
kubectl get pods -l app=flask

# Describe pod for events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

**Common causes:**
- Image pull errors (check ECR permissions)
- Missing secrets
- Resource constraints
- Application errors

#### 2. LoadBalancer Not Getting External IP

```bash
# Check service
kubectl describe service flask-service

# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

**Solutions:**
- Ensure AWS Load Balancer Controller is installed
- Check security groups
- Verify subnet tags

#### 3. HPA Not Scaling

```bash
# Check HPA status
kubectl describe hpa flask-app-hpa

# Check metrics server
kubectl get deployment metrics-server -n kube-system
```

**Solutions:**
- Ensure metrics server is running
- Check resource requests/limits in deployment
- Verify CPU/memory metrics are available

#### 4. Application Errors

```bash
# Check application logs
kubectl logs -l app=flask --tail=100

# Execute into pod for debugging
kubectl exec -it <pod-name> -- /bin/bash

# Check environment variables
kubectl exec <pod-name> -- env
```

### Useful Commands

```bash
# Get all resources
kubectl get all

# Describe deployment
kubectl describe deployment flask-app

# Get events
kubectl get events --sort-by=.metadata.creationTimestamp

# Delete and recreate pod
kubectl delete pod <pod-name>

# Check cluster info
kubectl cluster-info

# Check node status
kubectl describe nodes
```

---

## Cost Optimization

### Estimated Monthly Costs

**Basic Setup (2 t3.medium nodes):**
- EKS Control Plane: $73/month
- EC2 Instances (2 × t3.medium): ~$60/month
- Network Load Balancer: ~$20/month
- Data Transfer: Variable
- **Total: ~$153/month**

### Cost Reduction Tips

1. **Use Spot Instances**
   ```bash
   eksctl create nodegroup \
     --cluster=$CLUSTER_NAME \
     --spot \
     --instance-types=t3.medium,t3a.medium
   ```

2. **Right-size Your Nodes**
   - Start with t3.small if traffic is low
   - Use HPA to scale pods instead of nodes

3. **Use Fargate for Serverless**
   ```bash
   eksctl create fargateprofile \
     --cluster $CLUSTER_NAME \
     --name fp-default \
     --namespace default
   ```

4. **Schedule Downtime**
   - Scale down during off-hours
   - Use cluster autoscaler

5. **Monitor and Optimize**
   - Use AWS Cost Explorer
   - Set up billing alerts
   - Review CloudWatch metrics

### Cleanup Resources

When you're done testing:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Delete EKS cluster
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION

# Delete ECR repository
aws ecr delete-repository \
  --repository-name $ECR_REPO_NAME \
  --region $AWS_REGION \
  --force
```

---

## Security Best Practices

1. **Secrets Management**
   - Use AWS Secrets Manager or Parameter Store
   - Enable encryption at rest
   - Rotate secrets regularly

2. **Network Security**
   - Use security groups to restrict access
   - Enable VPC flow logs
   - Use private subnets for worker nodes

3. **RBAC**
   - Implement Role-Based Access Control
   - Use IAM roles for service accounts
   - Follow principle of least privilege

4. **Image Security**
   - Scan images for vulnerabilities
   - Use minimal base images
   - Keep dependencies updated

5. **Monitoring**
   - Enable CloudWatch Container Insights
   - Set up alerts for anomalies
   - Monitor API server logs

---

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [eksctl Documentation](https://eksctl.io/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Prometheus Documentation](https://prometheus.io/docs/)

---

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review AWS EKS logs in CloudWatch
3. Check Kubernetes events: `kubectl get events`
4. Review application logs: `kubectl logs -l app=flask`

---

**Last Updated:** 2026-06-05
**Version:** 1.0