# GitHub Actions Setup Guide for EKS Deployment

This guide explains how to set up GitHub Actions to automatically build and deploy your application to EKS.

## Overview

The GitHub Actions workflow ([`.github/workflows/deploy-to-eks.yml`](.github/workflows/deploy-to-eks.yml)) will:
- Build Docker image on GitHub's servers
- Push image to Amazon ECR
- Deploy to your EKS cluster
- Update Kubernetes resources

## Prerequisites

✅ EKS cluster created (recommendation-cluster)
✅ ECR repository exists (recommendation-system)
✅ GitHub repository for your code

## Setup Steps

### 1. Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add the following secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key | IAM user with ECR and EKS permissions |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Key | Corresponding secret key |
| `GROQ_API_KEY` | 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 | Your Groq API key |
| `ASTRA_DB_TOKEN` | AstraCS:UpNkGAeaMEIWZspwQKajjtDH:dc672ba3a1c3932ab98be8ef1061910d0214469edab8d79f84d08cb59912c9cd | Your Astra DB token |
| `ASTRA_DB_ENDPOINT` | https://11df3258-f70c-4a3a-97f3-29e79ba9b40b-us-east-2.apps.astra.datastax.com | Your Astra DB endpoint |
| `HUGGINGFACE_TOKEN` | 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 | Your HuggingFace token |

### 2. Create IAM User for GitHub Actions

Create an IAM user with the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. Update kubeconfig Access (One-time setup)

Run this command to allow GitHub Actions to access your cluster:

```powershell
# Get your IAM user ARN
$IAM_USER_ARN = (aws sts get-caller-identity --query Arn --output text)

# Add GitHub Actions IAM user to aws-auth ConfigMap
kubectl edit configmap aws-auth -n kube-system
```

Add this to the `mapUsers` section:

```yaml
mapUsers: |
  - userarn: arn:aws:iam::905418389834:user/github-actions
    username: github-actions
    groups:
      - system:masters
```

### 4. Push Code to GitHub

```bash
# Initialize git if not already done
git init

# Add all files
git add .

# Commit
git commit -m "Add EKS deployment with GitHub Actions"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Push to main branch
git push -u origin main
```

### 5. Trigger Deployment

The workflow will automatically run when you:
- Push to the `main` branch
- Manually trigger it from GitHub Actions tab

To manually trigger:
1. Go to your GitHub repository
2. Click "Actions" tab
3. Select "Build and Deploy to EKS"
4. Click "Run workflow"

## Workflow Features

### Automatic Triggers
- ✅ Runs on every push to `main` branch
- ✅ Can be manually triggered via GitHub UI

### Build Process
- ✅ Builds Docker image on GitHub runners
- ✅ Tags with commit SHA and `latest`
- ✅ Pushes to Amazon ECR

### Deployment Process
- ✅ Updates Kubernetes secrets
- ✅ Deploys new version to EKS
- ✅ Applies HPA configuration
- ✅ Waits for rollout to complete
- ✅ Displays service URL

## Monitoring Deployments

### View Workflow Runs
1. Go to GitHub repository → Actions tab
2. Click on a workflow run to see details
3. View logs for each step

### Check Deployment Status
```powershell
# Get pods
kubectl get pods -l app=flask

# Get service
kubectl get service flask-service

# Get HPA status
kubectl get hpa flask-app-hpa

# View logs
kubectl logs -l app=flask --tail=50 -f
```

## Troubleshooting

### Workflow Fails at "Login to Amazon ECR"
- Check AWS credentials in GitHub Secrets
- Verify IAM user has ECR permissions

### Workflow Fails at "Deploy to EKS"
- Check if IAM user is added to aws-auth ConfigMap
- Verify cluster name matches in workflow file

### Pods Not Starting
```powershell
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Image Pull Errors
- Verify ECR repository exists
- Check IAM permissions for ECR
- Ensure image was pushed successfully

## Alternative: Manual Deployment (Without Docker Desktop)

If you prefer not to use GitHub Actions, you can:

1. **Use AWS Cloud9 or EC2 instance** with Docker installed
2. **Use GitHub Codespaces** (has Docker pre-installed)
3. **Use WSL2** on Windows with Docker installed

## Cost Considerations

### GitHub Actions
- Free tier: 2,000 minutes/month for private repos
- Public repos: Unlimited free minutes
- This workflow uses ~5-10 minutes per deployment

### AWS Resources
- EKS: $73/month (control plane)
- EC2: ~$60/month (2 × t3.medium nodes)
- ECR: $0.10/GB/month (storage)
- Data transfer: Variable

## Security Best Practices

1. ✅ Never commit secrets to Git
2. ✅ Use GitHub Secrets for sensitive data
3. ✅ Rotate AWS credentials regularly
4. ✅ Use least-privilege IAM policies
5. ✅ Enable branch protection on `main`
6. ✅ Require pull request reviews

## Next Steps

After successful deployment:

1. **Get Application URL**:
   ```powershell
   kubectl get service flask-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. **Test Application**:
   ```powershell
   curl http://<LoadBalancer-URL>/
   ```

3. **Monitor Logs**:
   ```powershell
   kubectl logs -l app=flask -f
   ```

4. **Set up Prometheus** (optional):
   ```powershell
   kubectl apply -f prometheus/prometheus-configmap.yaml
   kubectl apply -f prometheus/prometheus-deployment.yaml
   ```

---

**Created:** 2026-06-05
**Version:** 1.0