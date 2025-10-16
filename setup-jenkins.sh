#!/bin/bash

# Jenkins Setup Script
# This script helps configure Jenkins for your Laravel CI/CD pipeline

echo "Setting up Jenkins for Laravel Dynamic Dashboard..."

# Install Docker CLI in Jenkins container
docker exec -u root jenkins-server sh -c "
  apt-get update && \
  apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && \
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
  echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt-get update && \
  apt-get install -y docker-ce-cli
"

echo "Docker CLI installed in Jenkins container"

# Get Jenkins initial admin password
echo "Getting Jenkins initial admin password..."
JENKINS_PASSWORD=$(docker exec jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Password file not found - Jenkins may already be configured")

echo "=================================================="
echo "JENKINS SETUP INFORMATION"
echo "=================================================="
echo "Jenkins URL: http://localhost:8080"
echo "Initial Admin Password: $JENKINS_PASSWORD"
echo ""
echo "Next Steps:"
echo "1. Open http://localhost:8080 in your browser"
echo "2. Use the password above to unlock Jenkins"
echo "3. Install suggested plugins"
echo "4. Create your admin user"
echo "5. Configure Jenkins instance"
echo ""
echo "For your CI/CD pipeline, you'll need to:"
echo "1. Install Docker Pipeline plugin"
echo "2. Add Docker Hub credentials (ID: docker_hub_creds)"
echo "3. Create a new Pipeline job"
echo "4. Point it to your GitHub repository"
echo "=================================================="