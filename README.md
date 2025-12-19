# DevSecOps Insecure EKS MongoDB Lab (Wiz Scan Project)

## Project Overview

This project demonstrates how to intentionally build an **insecure cloud environment** so that a security scanning tool (Wiz) can identify risks.

The environment includes:

* An **Amazon EKS cluster** running a public web application
* A **MongoDB database on an EC2 instance**
* **Over-privileged IAM permissions**
* **Hardcoded secrets** exposed inside containers

This setup is **intentionally insecure** for learning and scanning purposes.

---

## Architecture Summary

* EKS cluster and MongoDB EC2 run in the **same VPC**
* Web application is publicly accessible through a **LoadBalancer**
* MongoDB runs on an EC2 instance with **weak security**
* Secrets are stored in **plaintext ConfigMaps**
* RBAC grants **cluster-admin** access to the application

---

# Phase 1 – Deploy the Web Application to EKS

### Step 1: Configure cluster access (local machine)

On your **local laptop** (not SSH), connect kubectl to EKS:

```bash
aws eks update-kubeconfig --region us-east-2 --name my-cluster
```

If AWS CLI is missing, install it first:
[https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

---

### Step 2: Verify EKS access

```bash
kubectl get nodes
```

If nodes appear, you are connected successfully.

---

### Step 3: Create application manifests

Create the following files locally:

* `deployment.yaml`
* `service.yaml`

These files:

* Pull the container image
* Run the web app
* Expose it publicly using a LoadBalancer

---

### Step 4: Verify YAML files have content

```bash
type deployment.yaml
type service.yaml
```

You **must see YAML output**.
If the files are empty, stop and fix them.

---

### Step 5: Deploy to EKS

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

Expected output:

* Deployment created
* Service created

---

### Step 6: Confirm everything is running

```bash
kubectl get pods
kubectl get svc
```

Check for:

* Pod status: **Running**
* Service type: **LoadBalancer**
* External IP assigned (may take 1–3 minutes)

---

# Phase 2 – Identity and Secrets (Intentionally Insecure)

This phase introduces **security risks** that Wiz is expected to detect.

---

## Step 1 – Give the web app full Kubernetes admin access

### What this does

You are giving the application **full control of the cluster**, which is extremely unsafe.

### Why this exists

Wiz should flag:

* Over-privileged Kubernetes ServiceAccount
* Dangerous RBAC configuration

---

### Files created

* `serviceaccount.yaml`
* `clusterrolebinding.yaml`

These bind the ServiceAccount to `cluster-admin`.

---

### Apply RBAC configuration

```bash
kubectl apply -f serviceaccount.yaml
kubectl apply -f clusterrolebinding.yaml
```

---

### Verify

```bash
kubectl get serviceaccount webapp-admin-sa
kubectl get clusterrolebinding webapp-admin-binding
kubectl describe pod <pod-name>
```

You should see:

```
Service Account: webapp-admin-sa
```

---

## Step 2 – Over-privilege the MongoDB EC2 instance

### What this does

The MongoDB EC2 server is given **excessive AWS permissions**.

### Why this exists

Wiz should flag:

* Over-privileged IAM role
* Dangerous EC2 permissions

---

### MongoDB admin user (weak credentials)

On the MongoDB EC2 instance:

```bash
mongosh
use admin
```

Create an admin user:

```javascript
db.createUser({
  user: "adminuser",
  pwd: "password123",
  roles: [{ role: "root", db: "admin" }]
})
```

Expected output:

```
{ ok: 1 }
```

Exit MongoDB:

```bash
exit
```

This is **intentionally weak** and insecure.

---

## Step 3 – Store MongoDB credentials insecurely

### Enable MongoDB authentication

Edit MongoDB config:

```bash
sudo nano /etc/mongod.conf
```

Confirm or add:

```yaml
security:
  authorization: enabled
```

Restart MongoDB:

```bash
sudo systemctl restart mongod
```

Test login:

```bash
mongosh -u adminuser -p password123 --authenticationDatabase admin
```

---

### Step 3.1 – Get MongoDB private IP

On the MongoDB EC2 instance:

```bash
hostname -I
```

Example:

```
10.0.4.232
```

Save this IP.

---

### Step 3.2 – Create plaintext credentials file (local machine)

```powershell
@"
MONGO_URI=mongodb://adminuser:password123@10.0.4.232:27017/admin
"@ | Out-File -Encoding utf8 mongodb-creds.txt
```

This is **intentionally insecure**.

Verify file contents:

```powershell
type mongodb-creds.txt
```

---

### Step 3.3 – Create ConfigMap from credentials

```bash
kubectl create configmap mongodb-creds --from-file=mongodb-creds.txt
```

Verify:

```bash
kubectl get configmap mongodb-creds
```

---

### Step 3.4 – Restart application to load secrets

```bash
kubectl rollout restart deployment web-app
```

Wait and confirm:

```bash
kubectl get pods
```

---

### Step 3.5 – Prove credentials are inside the container

```bash
kubectl exec -it <pod-name> -- cat /etc/secrets/mongodb-creds.txt
```

Expected output:

```
MONGO_URI=mongodb://adminuser:password123@10.0.4.232:27017/admin
```

---

## Project Outcome

At this point:

* The application is public
* Kubernetes RBAC is dangerously open
* MongoDB credentials are exposed
* IAM permissions are excessive

This environment is now **ready for Wiz scanning**, and Wiz should report multiple high-risk findings.

---

