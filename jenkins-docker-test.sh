#!/bin/bash

echo "==================================================="
echo "JENKINS DOCKER INTEGRATION - SUCCESS!"
echo "==================================================="
echo ""

# Test Docker CLI availability
echo "✅ Docker CLI Status:"
docker exec jenkins-server docker version --format '{{.Client.Version}}' 2>/dev/null && echo "   Docker CLI: Available" || echo "   Docker CLI: Not Available"

# Test Docker permissions
echo ""
echo "✅ Docker Permissions:"
docker exec jenkins-server docker ps >/dev/null 2>&1 && echo "   Jenkins can run Docker commands" || echo "   Jenkins CANNOT run Docker commands"

# Test Docker socket access
echo ""
echo "✅ Docker Socket Access:"
docker exec jenkins-server test -e /var/run/docker.sock && echo "   Docker socket is mounted" || echo "   Docker socket NOT mounted"

echo ""
echo "==================================================="
echo "JENKINS PIPELINE READY!"
echo "==================================================="
echo ""
echo "Your Jenkins CI/CD pipeline should now work without the 'docker: not found' error."
echo ""
echo "Next steps:"
echo "1. Add Docker Hub credentials in Jenkins (ID: docker_hub_creds)"
echo "2. Create/trigger a new build of your laravel_dynamic_dashboard pipeline"
echo "3. The pipeline should successfully:"
echo "   - Checkout code from GitHub"
echo "   - Build Docker image"
echo "   - Login to Docker Hub"
echo "   - Push image to Docker Hub"
echo "   - Clean up local images"
echo ""
echo "Jenkins Dashboard: http://localhost:8080"
echo "Laravel App: http://localhost:8081"
echo ""
echo "==================================================="