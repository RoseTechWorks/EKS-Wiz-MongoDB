#!/bin/bash
# ==========================================
# MongoDB Install Script (Intentionally Insecure / Older Setup)
# For DevSecOps / Wiz Scanning Practice
# ==========================================

set -e

echo "Updating system packages..."
sudo apt update -y
echo "Installing required packages..."
sudo apt install -y curl gnupg awscli
echo "Installing kubectl..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
echo "Adding MongoDB GPG key..."
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg
echo "Adding MongoDB repository..."
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | \
sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
echo "Installing MongoDB..."
sudo apt update -y
sudo apt install -y mongodb-org mongodb-mongosh
echo "Starting MongoDB service..."
sudo systemctl start mongod
sudo systemctl enable mongod

echo "MongoDB installation completed successfully."
