pipeline {
    agent any

    environment {
        IMAGE_NAME = 'hitendra369/laravel_dynamic_dashboard' // Docker image name
        // IMAGE_TAG = "${env.BUILD_NUMBER}"             // Tag with build number
        IMAGE_TAG = "latest"
        DOCKER_REGISTRY = 'docker.io'               // Correct Docker Hub registry URL
        DOCKER_CREDENTIALS = 'docker_hub_creds'     // Jenkins stored credentials ID
        // Render Deploy Hook URL stored as Jenkins Secret Text credential (ID: RENDER_DEPLOY_HOOK)
        RENDER_DEPLOY_HOOK = credentials('RENDER_DEPLOY_HOOK')
        // Aeonfree deployment - configure these in Jenkins (leave empty to skip)
        AEONFREE_HOST = 'laravel-dynamic.iceiy.com'                         // ftp.example.com or host.example.com
        AEONFREE_PATH = 'htdocs'                         // remote path where to upload the artifact
    // Note: Credential IDs are stored in  Jenkins credentials store. We will bind them via withCredentials in the deploy stage.
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out code...'
                git branch: 'main', url: 'https://github.com/HitKakadiya3/dynamic_dashboard_app.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo 'Building Docker image...'
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Login to Docker Registry') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        // Secure way to pass password without Groovy interpolation
                        sh '''
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        '''
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                    // Also push with 'latest' tag for Render deployment
                    sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
                    sh "docker push ${IMAGE_NAME}:latest"
                }
            }
            post {
                success {
                    script {
                        // Guard: ensure deploy hook URL is configured before attempting deploy
                        if (!env.RENDER_DEPLOY_HOOK || !env.RENDER_DEPLOY_HOOK.startsWith('http')) {
                            echo 'RENDER_DEPLOY_HOOK is  not configured; skipping Render deployment.'
                        } else {
                            echo 'Docker push succeeded — triggering Render deployment via Deploy Hook...'
                            // Use the Render Deploy Hook URL (secret) to kick off a deployment.
                            // Jenkins will mask the secret env var in logs. POSIX sh compatible with retry and GET fallback.
                            sh '''
                                    set -e
                                    max_retries=3
                                    # Try POST first with retries
                                    attempt_post=1
                                    while [ "$attempt_post" -le "$max_retries" ]; do
                                        http_code=$(curl -sS -o /tmp/render_deploy_resp.json -w "%{http_code}" -X POST "$RENDER_DEPLOY_HOOK")
                                        echo "Render hook [POST] attempt $attempt_post status: $http_code"
                                        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
                                            echo "Render response:"; cat /tmp/render_deploy_resp.json || true
                                            echo "Render deployment triggered successfully."
                                            exit 0
                                        fi
                                        if [ "$http_code" -ge 500 ]; then
                                            delay=$((attempt_post*5))
                                            echo "Server error from Render. Retrying in ${delay}s..."
                                            sleep "$delay"
                                            attempt_post=$((attempt_post+1))
                                            continue
                                        fi
                                        echo "Render deploy hook returned an error. Response body:"; cat /tmp/render_deploy_resp.json || true
                                        exit 1
                                    done

                                    # Fallback: try GET with retries
                                    attempt_get=1
                                    while [ "$attempt_get" -le "$max_retries" ]; do
                                        http_code=$(curl -sS -o /tmp/render_deploy_resp.json -w "%{http_code}" -X GET "$RENDER_DEPLOY_HOOK")
                                        echo "Render hook [GET] attempt $attempt_get status: $http_code"
                                        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
                                            echo "Render response:"; cat /tmp/render_deploy_resp.json || true
                                            echo "Render deployment triggered successfully."
                                            exit 0
                                        fi
                                        if [ "$http_code" -ge 500 ]; then
                                            delay=$((attempt_get*5))
                                            echo "Server error from Render. Retrying in ${delay}s..."
                                            sleep "$delay"
                                            attempt_get=$((attempt_get+1))
                                            continue
                                        fi
                                        echo "Render deploy hook returned an error. Response body:"; cat /tmp/render_deploy_resp.json || true
                                        exit 1
                                    done

                                    echo "All attempts to trigger Render deploy failed."
                                    cat /tmp/render_deploy_resp.json || true
                                    exit 1
                            '''
                        }
                    }
                }
                failure {
                    echo 'Docker push failed — skipping Render deployment.'
                }
            }
        }

        stage('Clean Up') {
            steps {
                echo 'Cleaning up local images...'
                sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
                sh "docker rmi ${IMAGE_NAME}:latest || true"
            }
        }
        
        stage('Deploy to Aeonfree') {
            steps {
                script {
                    // Skip if host not configured
                    if (!env.AEONFREE_HOST || env.AEONFREE_HOST.trim() == '') {
                        echo 'AEONFREE_HOST not configured; skipping Aeonfree deployment.'
                    } else {
                        echo "Preparing deploy artifact for ${env.AEONFREE_HOST}..."
                        // Create zip archive
                        sh '''
                            set -e
                            rm -f /tmp/deploy.zip || true
                            zip -r /tmp/deploy.zip . -x ".git/*" "vendor/*" "node_modules/*" "storage/*" "tests/*" "build/*" || true
                            ls -lh /tmp/deploy.zip || true
                        '''

                        // Try SSH deploy first
                        def sshAttempted = false
                        try {
                            echo 'Attempting to bind Jenkins SSH credential id "aeonfree_ssh"...'
                            withCredentials([sshUserPrivateKey(credentialsId: 'aeonfree_ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                                sshAttempted = true
                                echo 'Attempting SSH deploy to Aeonfree...'
                                sh '''
                                    set -e
                                    chmod 600 "$SSH_KEY" || true
                                    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@${AEONFREE_HOST}" "mkdir -p ${AEONFREE_PATH} || true"
                                    scp -o StrictHostKeyChecking=no -i "$SSH_KEY" /tmp/deploy.zip "$SSH_USER@${AEONFREE_HOST}:${AEONFREE_PATH}/deploy.zip"
                                    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@${AEONFREE_HOST}" "cd ${AEONFREE_PATH} && unzip -o deploy.zip && rm deploy.zip"
                                '''
                            }
                        } catch (err) {
                            echo "SSH deploy failed: ${err}. Attempting FTP fallback..."
                        }

                        if (!sshAttempted) {
                            // FTP fallback using lftp
                            try {
                                echo 'Attempting FTP deploy using Jenkins credential id "AEONFREE_FTP_CREDENTIALS"...'
                                withCredentials([usernamePassword(credentialsId: 'AEONFREE_FTP_CREDENTIALS', usernameVariable: 'FTP_USER', passwordVariable: 'FTP_PASS')]) {
                                    sh '''
                                        set -e
                                        # Create lftp script
                                        echo "set ssl:verify-certificate no
                                        set ftp:ssl-allow no
                                        open ftp://${AEONFREE_HOST}
                                        user ${FTP_USER} ${FTP_PASS}
                                        cd ${AEONFREE_PATH}
                                        put /tmp/deploy.zip -o deploy.zip
                                        quit" > /tmp/lftp_script

                                        # Execute lftp with retries
                                        max_retries=3
                                        attempt=1
                                        while [ "$attempt" -le "$max_retries" ]; do
                                            if lftp -f /tmp/lftp_script; then
                                                echo "FTP upload successful!"
                                                rm /tmp/lftp_script
                                                exit 0
                                            fi
                                            echo "FTP attempt $attempt failed. Retrying in 10s..."
                                            sleep 
            }
        }
    }

    post {
        success {
            echo "Docker image ${IMAGE_NAME}:${IMAGE_TAG} built and pushed successfully!"
        }
        failure {
            echo "Build failed!"
        }
    }
}
