EKS Wiz MongoDB

Intentionally Insecure Kubernetes and MongoDB Environment for Security Scanning

## Overview

This project deploys a simple web application to Amazon EKS and intentionally introduces high risk security misconfigurations across Kubernetes MongoDB and AWS IAM.

The environment is designed for security scanning and detection specifically to demonstrate the types of issues tools like Wiz should identify.

This project is intentionally insecure. Do not use in production.

---

## Architecture Summary

Amazon EKS cluster running a public web application
MongoDB hosted on an EC2 instance
Kubernetes LoadBalancer exposes the app publicly
Kubernetes RBAC is dangerously over permissive
MongoDB credentials are stored in plaintext
EC2 IAM permissions are excessive

---

## Phase 1 Deploy Web Application to EKS

### Step 1 Configure EKS Cluster Access Local Machine

On your local laptop not SSH connect kubectl to EKS

```bash
aws --version
aws eks update kubeconfig region us east 2 name MongoDB cluster
```

---

### Step 2 Verify EKS Access

```bash
kubectl get nodes
```

If nodes appear you are connected successfully.

---

### Step 3 Create Application Manifests

Create the following files locally

deployment.yaml
service.yaml

These files pull the container image run the web application and expose it publicly using a LoadBalancer.

---

### Step 4 Deploy to EKS

```bash
kubectl apply f deployment.yaml
kubectl apply f service.yaml
```

Expected output
Deployment created
Service created

---

### Step 5 Confirm Everything Is Running

```bash
kubectl get pods
kubectl get svc
```

Check for
Pod status Running
Service type LoadBalancer
External IP assigned may take one to three minutes

At this point the application is publicly accessible from the internet.

---

## Phase 2 Identity and Secrets Intentionally Insecure

This phase introduces deliberate security risks that Wiz is expected to detect.

---

### Step 1 Give the Web App Full Kubernetes Admin Access

What this does
You are giving the application full control of the cluster which is extremely unsafe.

Why this exists
Wiz should flag over privileged Kubernetes ServiceAccount and dangerous RBAC configuration.

Files to create
serviceaccount.yaml
clusterrolebinding.yaml

These bind the ServiceAccount to cluster admin.

---

### Apply RBAC Configuration

```bash
kubectl apply f serviceaccount.yaml
kubectl apply f clusterrolebinding.yaml
```

---

### Verify

```bash
kubectl get serviceaccount webapp admin sa
kubectl get clusterrolebinding webapp admin binding
kubectl describe pod pod name
```

You should see
Service Account webapp admin sa

---

### Step 2 Over Privilege the MongoDB EC2 Instance

What this does
The MongoDB EC2 server is given excessive AWS permissions.

Why this exists
Wiz should flag over privileged IAM role and dangerous EC2 permissions.

---

### Step 3 MongoDB Admin User Weak Credentials

This is intentionally weak and insecure.

SSH into the MongoDB EC2 instance.

Enter MongoDB shell

```bash
mongosh
```

You should see
test greater than

Switch to admin database

```js
use admin
```

Create admin user

```js
db.createUser({
  user "adminuser",
  pwd "password123",
  roles [ { role "root", db "admin" } ]
})
```

Expected output
{ ok 1 }

Verify

```js
show users
```

You must see

```js
{
  user "adminuser",
  roles [ { role "root", db "admin" } ]
}
```

Exit MongoDB

```js
exit
```

---

### Step 4 Enable MongoDB Authentication and Network Exposure

Edit MongoDB config

```bash
sudo nano etc mongod.conf
```

Change
bindIp 127.0.0.1

To
bindIp 0.0.0.0

Add at the top

```yaml
security
  authorization enabled
```

Save and exit
CTRL O
ENTER
CTRL X

Restart MongoDB

```bash
sudo systemctl restart mongod
```

Verify MongoDB is listening publicly

```bash
sudo ss tulnp | grep 27017
```

You should see
0.0.0.0 colon 27017

Test login

```bash
mongosh u adminuser p password123 authenticationDatabase admin
```

---

### Step 5 Store MongoDB Credentials Insecurely

#### Step 5.1 Get MongoDB Private IP

On the MongoDB EC2 instance

```bash
hostname I
```

Example
10.0.4.232

---

#### Step 5.2 Create Plaintext Credentials File Local Machine

```powershell
@"
MONGO_URI=mongodb://adminuser:password123@10.0.4.232:27017/admin
"@ | Out File Encoding utf8 mongodb creds.txt
```

This is intentionally insecure.

Verify file contents

```powershell
Get Content mongodb creds.txt
```

---

#### Step 5.3 Create ConfigMap from Credentials

```bash
kubectl create configmap mongodb creds from file mongodb creds.txt
```

Verify

```bash
kubectl get configmap mongodb creds
```

---

#### Step 5.4 Restart Application to Load Secrets

```bash
kubectl rollout restart deployment web app
```

Wait and confirm

```bash
kubectl get pods
```

---

#### Step 5.5 Prove Credentials Are Inside the Container

```bash
kubectl exec it pod name cat etc secrets mongodb creds.txt
```

Expected output

```text
MONGO_URI=mongodb://adminuser:password123@10.0.4.232:27017/admin
```
