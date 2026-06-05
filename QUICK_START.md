# Quick Start Guide - EKS Deployment

This is a condensed version for experienced users. For detailed instructions, see [EKS_DEPLOYMENT_GUIDE.md](EKS_DEPLOYMENT_GUIDE.md).

## Prerequisites Checklist
- [ ] AWS CLI installed and configured
- [ ] kubectl installed
- [ ] eksctl installed
- [ ] Docker Desktop running
- [ ] AWS credentials configured

## Quick Deployment Steps

### 1. Update Secrets
Edit `k8s/secrets.yaml` with your actual API keys.

### 2. Set Environment Variables
```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=recommendation-cluster
export ECR_REPO_NAME=recommendation-system
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

### 3. Create EKS Cluster (15-20 min)
```bash
chmod +x scripts/setup-eks-cluster.sh
./scripts/setup-eks-cluster.sh
```

### 4. Build & Deploy
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

### 5. Get Application URL
```bash
kubectl get service flask-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Manual Steps (Alternative)

### Create Cluster
```bash
eksctl create cluster \
  --name recommendation-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed
```

### Build & Push Image
```bash
# Create ECR repo
aws ecr create-repository --repository-name recommendation-system --region us-east-1

# Build image
docker build -t recommendation-system:latest .

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Tag and push
docker tag recommendation-system:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/recommendation-system:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/recommendation-system:latest
```

### Deploy to Kubernetes
```bash
# Update image in k8s/flask-deployment.yaml
# Replace <AWS_ACCOUNT_ID> and <AWS_REGION>

# Apply manifests
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/flask-deployment.yaml
kubectl apply -f k8s/hpa.yaml

# Check status
kubectl get pods
kubectl get service flask-service
```

## Useful Commands

```bash
# View logs
kubectl logs -l app=flask --tail=50 -f

# Check HPA
kubectl get hpa

# Scale manually
kubectl scale deployment flask-app --replicas=3

# Update image
kubectl set image deployment/flask-app flask-container=NEW_IMAGE:TAG

# Rollback
kubectl rollout undo deployment/flask-app

# Delete everything
kubectl delete -f k8s/
eksctl delete cluster --name recommendation-cluster
```

## Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**No external IP?**
```bash
kubectl describe service flask-service
```

**HPA not working?**
```bash
kubectl describe hpa flask-app-hpa
kubectl top pods
```

## Cost Estimate
- EKS Control Plane: $73/month
- 2 × t3.medium nodes: ~$60/month
- Load Balancer: ~$20/month
- **Total: ~$153/month**

## Cleanup
```bash
kubectl delete -f k8s/
eksctl delete cluster --name recommendation-cluster --region us-east-1
aws ecr delete-repository --repository-name recommendation-system --region us-east-1 --force
```

---

For detailed explanations, troubleshooting, and best practices, see [EKS_DEPLOYMENT_GUIDE.md](EKS_DEPLOYMENT_GUIDE.md).