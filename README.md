# TrendStore – End-to-End DevOps Project

A hands-on DevOps project that packages a static TrendStore storefront into a Docker image, automates image builds and publishing with Jenkins, deploys the application to Amazon EKS, and monitors the Kubernetes environment with Prometheus and Grafana.

## Project objectives

- Build and run the TrendStore storefront in a Docker container.
- Store versioned container images in Docker Hub.
- Automate checkout, Docker build, and image publishing with Jenkins.
- Deploy the application to Amazon EKS using Kubernetes Deployment and LoadBalancer Service resources.
- Collect cluster and node metrics with Prometheus, Node Exporter, and kube-state-metrics.
- Visualize Kubernetes and node metrics in Grafana.
- Provision the Jenkins EC2 host and supporting IAM/security-group resources with Terraform.

## Architecture

```text
Developer push
     |
     v
GitHub repository
     |  GitHub webhook
     v
Jenkins on Amazon EC2
     |  checkout -> validate -> docker build -> docker push
     v
Docker Hub (sethuaws/trendstore)
     |
     |  image pull
     v
Amazon EKS
  - trendstore Deployment
  - trendstore-service (LoadBalancer)
     |
     v
Public TrendStore storefront

Amazon EKS metrics
     |
     v
Prometheus
  - Kubernetes API / node / cAdvisor metrics
  - Node Exporter
  - kube-state-metrics
     |
     v
Grafana dashboards
```

## Technology stack

| Area | Technology |
|---|---|
| Cloud | AWS |
| Infrastructure as Code | Terraform |
| Containerization | Docker |
| Container registry | Docker Hub |
| Source control | Git and GitHub |
| CI/CD | Jenkins and GitHub webhook |
| Container orchestration | Amazon EKS and Kubernetes |
| Monitoring | Prometheus, Node Exporter, kube-state-metrics |
| Visualization | Grafana |
| Operating system | Amazon Linux 2023 for EC2 hosts |

## Repository layout

```text
.
├── Dockerfile
├── Jenkinsfile
├── dist/
│   └── index.html
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── iam.tf
│   ├── outputs.tf
│   └── user_data.sh
└── kubernetes/
    ├── deployment.yaml
    ├── service.yaml
    ├── prometheus-values.yaml
    └── grafana-values.example.yaml
```

The real `kubernetes/grafana-values.yaml` is intentionally excluded from Git because it contains the Grafana admin password. Use the example file as a template and provide your own strong password locally. Terraform state, `.tfvars`, plan files, private keys, and credentials must also remain out of source control.

## 1. Build the application image

The Dockerfile uses Nginx to serve the built static site:

```dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Build and run locally:

```bash
docker build -t trendstore:v1 .
docker run -d --name trendstore -p 3000:80 trendstore:v1
curl -I http://localhost:3000
```

The local HTTP check returned `HTTP/1.1 200 OK`.

Tag and publish the image:

```bash
docker login
docker tag trendstore:v1 sethuaws/trendstore:v1
docker push sethuaws/trendstore:v1
```

The Docker Hub repository used in this project is `sethuaws/trendstore`. The Jenkins pipeline also publishes `latest` and a short Git commit SHA tag.

## 2. Provision Jenkins infrastructure with Terraform

The Terraform configuration in `terraform/` provisions the Jenkins EC2 host and supporting resources, including its security group, IAM role/profile, and instance configuration.

Run from the Terraform directory:

```bash
cd terraform
terraform init
terraform fmt
terraform validate
terraform plan -out=jenkins.tfplan
terraform apply jenkins.tfplan
```

Review the plan and AWS region, CIDR rules, instance type, and IAM permissions before applying. Keep `terraform.tfstate`, `terraform.tfvars`, and `*.tfplan` files private and out of Git.

The Terraform validation and plan screenshots are included in the evidence archive. The plan shown in the screenshot is a plan, not proof that Terraform applied those resources.

## 3. Configure Jenkins CI/CD

The Jenkins job is named `TrendStore-CI-CD` and uses Pipeline script from SCM:

- Repository: `https://github.com/sethuraman98/trendstore-devops.git`
- Branch: `main`
- Script path: `Jenkinsfile`
- Build trigger: GitHub hook trigger for GITScm polling

The pipeline stages:

1. Check out the GitHub repository.
2. Validate that the Dockerfile and `dist/index.html` exist.
3. Build the Docker image using the short Git commit SHA and `latest` tags.
4. Authenticate to Docker Hub using the Jenkins credential ID `dockerhub-creds`.
5. Push both tags to Docker Hub and log out.

Configure a GitHub repository webhook pointing to the Jenkins webhook endpoint:

```text
http://<JENKINS_HOST>:8080/github-webhook/
```

Use a Jenkins credential store for Docker Hub and GitHub credentials. Do not hard-code tokens or passwords in the Jenkinsfile or commit them to Git.

A Jenkins build completed with `Finished: SUCCESS`, and the Docker Hub repository showed the pushed image tags.

## 4. Create the Amazon EKS cluster

The cluster was created in AWS region `ap-southeast-2` using `eksctl`, with one managed `t3.small` worker node:

```bash
eksctl create cluster \
  --name trendstore-eks \
  --region ap-southeast-2 \
  --version 1.34 \
  --nodegroup-name trendstore-workers \
  --node-type t3.small \
  --nodes 1 \
  --nodes-min 1 \
  --nodes-max 1 \
  --node-volume-size 20 \
  --managed
```

Configure kubectl:

```bash
aws eks update-kubeconfig \
  --region ap-southeast-2 \
  --name trendstore-eks

kubectl get nodes -o wide
kubectl get pods -A
```

The cluster and managed node group reached `ACTIVE`, and the worker node reached `Ready`.

### Cluster creation troubleshooting note

The SSH session was interrupted with a connection reset while cluster creation was in progress. The CloudFormation operation continued independently of the SSH session. After reconnecting, the cluster status and managed node group were checked and confirmed as `ACTIVE`. This is documented as a text troubleshooting note; the SSH disconnect itself was not captured in a screenshot.

## 5. Deploy TrendStore to Kubernetes

Apply the Deployment and Service manifests:

```bash
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml

kubectl get deployments
kubectl get pods -o wide
kubectl get services
```

The Deployment runs `sethuaws/trendstore:latest` on container port `80`. The Service is type `LoadBalancer` and exposes port `80`.

Get the public endpoint:

```bash
kubectl get svc trendstore-service
```

Open the `EXTERNAL-IP` hostname in a browser using HTTP. The application endpoint returned `HTTP/1.1 200 OK` and the storefront loaded successfully.

## 6. Install Prometheus

Helm was used to install Prometheus into a dedicated `monitoring` namespace. The values file disables Alertmanager and Pushgateway, enables Node Exporter and kube-state-metrics, disables persistent storage for this short-lived lab, and sets resource requests/limits.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --values kubernetes/prometheus-values.yaml \
  --wait \
  --timeout 10m
```

Verify:

```bash
kubectl get pods -n monitoring
kubectl get services -n monitoring
kubectl top nodes
kubectl top pods -n monitoring
```

Prometheus was accessed locally through port forwarding:

```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

Keep the port-forward process running while accessing `http://localhost:9090` through an SSH tunnel or from the same host.

The Prometheus target check reported **10 targets total and 10 healthy** at the time of capture. This is a point-in-time validation, not a guarantee of continuous availability.

## 7. Install and configure Grafana

Create a local `kubernetes/grafana-values.yaml` based on `kubernetes/grafana-values.example.yaml`. Set a strong, unique admin password in the local file. The real values file is ignored by Git.

Install Grafana:

```bash
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values kubernetes/grafana-values.yaml \
  --wait \
  --timeout 5m
```

The configured Prometheus data source uses the in-cluster service URL:

```text
http://prometheus-server.monitoring.svc.cluster.local
```

Access Grafana using port forwarding:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

For access from a Windows workstation, create an SSH tunnel in a separate PowerShell window:

```powershell
ssh -i "$HOME\Downloads\Newkey.pem" -L 3001:localhost:3000 ec2-user@<EC2_PUBLIC_IP>
```

Then browse to `http://localhost:3001`. Keep both the Kubernetes port-forward and SSH tunnel running. Log in with the Grafana admin credentials configured locally.

The dashboard includes Kubernetes pod status, pod restarts, EKS node memory usage, and EKS node CPU usage. Grafana and Prometheus were installed with persistence disabled for this lab, so their stored data/configuration may be lost if the pods are recreated.

## 8. Evidence screenshots

The companion ZIP archive contains the screenshots collected during implementation, including:

- Docker image build, container run, HTTP response, and Docker Hub push
- GitHub repository push and Jenkins credentials
- Jenkins CI/CD successful build
- EKS cluster creation and cluster/node verification
- Kubernetes Deployment, Service, and public storefront
- Prometheus target health (10/10)
- Grafana Prometheus data source and EKS monitoring dashboard
- Terraform initialization, plan, and validation workflow

## 9. Cleanup to avoid AWS charges

The EKS control plane, worker EC2 instance, EBS volume, and Kubernetes LoadBalancer can incur AWS charges. After saving screenshots and pushing the final project files, delete the EKS cluster if it is no longer needed:

```bash
eksctl delete cluster \
  --name trendstore-eks \
  --region ap-southeast-2
```

Wait for deletion to finish, then verify in the AWS Console that the EKS cluster, node group, associated EC2 instance, EBS volume, and load balancer have been removed.

The Jenkins EC2 host is separate from the EKS cluster. Keep it if you still need the CI/CD demonstration; otherwise remove it using the correct Terraform workspace/state or the AWS Console. Do not run `terraform destroy` from an unrelated or stale Terraform state. Confirm the resources shown in the destroy plan before approving it.

Also remove any temporary local Docker containers/images if they are no longer required:

```bash
docker rm -f trendstore
docker image prune -f
```

## Notes and limitations

- The deployment uses the public Docker Hub image `sethuaws/trendstore:latest`; for repeatable production deployments, pin a specific immutable image tag or digest.
- The application LoadBalancer and Jenkins endpoint in the lab used HTTP. Use TLS and appropriately restricted network access for production.
- The monitoring setup is intentionally lightweight for a single small worker node. Prometheus and Grafana persistence are disabled, and retention is configured for a short lab window.
- The Grafana chart installation emitted a deprecation warning during this lab. The release deployed successfully, but check the chart's current maintenance status before reusing this exact chart in a new environment.
- The Terraform plan screenshot records planned changes. Only report resources as provisioned when the corresponding apply operation and resulting AWS resources have been verified.

## Author / repository

GitHub repository: https://github.com/sethuraman98/trendstore-devops
Docker Hub repository: https://hub.docker.com/r/sethuaws/trendstore
