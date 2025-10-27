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
        AEONFREE_HOST = 'ftpupload.net'                         // ftp.example.com or host.example.com
        AEONFREE_PATH = 'htdocs'                         // remote path where to upload the artifact
    // Note: Credential IDs are stored in  Jenkins credentials store.   We will bind them via withCredentials in the deploy stage.
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
                        // Install zip if not available
                        sh '''
                            if ! command -v zip >/dev/null 2>&1; then
                                if command -v apt-get >/dev/null 2>&1; then
                                    apt-get update && apt-get install -y zip
                                elif command -v yum >/dev/null 2>&1; then
                                    yum install -y zip
                                elif command -v apk >/dev/null 2>&1; then
                                    apk add --no-cache zip
                                else
                                    echo "No supported package manager found. Please install zip manually."
                                    exit 1
                                fi
                            fi
                        '''
                        
                        // Create zip archive
                        sh '''
                            set -e
                            # Ensure we're in the project directory
                            cd "${WORKSPACE}"
                            
                            # Clean up any existing zip
                            rm -f /tmp/deploy.zip || true
                            
                            # Create the zip with verbose output for debugging
                            echo "Creating zip archive in ${PWD}..."
                            zip -v -r /tmp/deploy.zip . \
                                -x ".git/*" \
                                -x "vendor/*" \
                                -x "node_modules/*" \
                                -x "storage/*" \
                                -x "tests/*" \
                                -x "build/*" \
                                -x ".env" || true
                            
                            # Verify the zip was created
                            if [ ! -f /tmp/deploy.zip ]; then
                                echo "Failed to create zip file!"
                                exit 1
                            fi
                            
                            # Show the zip contents and size
                            echo "Zip file details:"
                            ls -lh /tmp/deploy.zip
                            echo "Zip contents:"
                            unzip -l /tmp/deploy.zip | head -n 10
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
                                echo 'Installing lftp...'
                                sh '''
                                    if command -v apt-get >/dev/null 2>&1; then
                                        apt-get update && apt-get install -y lftp
                                    elif command -v yum >/dev/null 2>&1; then
                                        yum install -y lftp
                                    elif command -v apk >/dev/null 2>&1; then
                                        apk add --no-cache lftp
                                    else
                                        echo "No supported package manager found. Please install lftp manually."
                                        exit 1
                                    fi
                                '''
                                
                                echo 'Attempting FTP deploy using Jenkins credential id "AEONFREE_FTP_CREDENTIALS"...'
                                withCredentials([usernamePassword(credentialsId: 'AEONFREE_FTP_CREDENTIALS', usernameVariable: 'FTP_USER', passwordVariable: 'FTP_PASS')]) {
                                    sh '''
                                        set -e
                                        # Verify zip exists before FTP
                                        if [ ! -f /tmp/deploy.zip ]; then
                                            echo "Error: /tmp/deploy.zip not found!"
                                            exit 1
                                        fi

                                        # Create extraction PHP script
                                        echo "Creating extraction script..."
                                        echo '<?php
                                        header("Content-Type: text/plain");
                                        error_reporting(E_ALL);
                                        ini_set("display_errors", 1);
                                        
                                        if (!file_exists("deploy.zip")) {
                                            echo "Error: deploy.zip not found";
                                            exit(1);
                                        }
                                        
                                        echo "Starting extraction...\\n";
                                        
                                        $zip = new ZipArchive;
                                        $res = $zip->open("deploy.zip");
                                        if ($res === TRUE) {
                                            echo "Zip opened successfully\\n";
                                            if (!$zip->extractTo(".")) {
                                                echo "Failed to extract files";
                                                $zip->close();
                                                exit(1);
                                            }
                                            echo "Files extracted\\n";
                                            $zip->close();
                                            echo "Zip closed\\n";
                                            
                                            if (!unlink("deploy.zip")) {
                                                echo "Warning: Could not delete deploy.zip\\n";
                                            } else {
                                                echo "Zip file deleted\\n";
                                            }
                                            echo "Extraction complete";
                                        } else {
                                            echo "Failed to open zip (error code: " . $res . ")";
                                            exit(1);
                                        }
                                        ?>' > /tmp/extract.php

                                        # Create lftp script for upload and extraction
                                        echo "debug 3
                                        set ssl:verify-certificate no
                                        set ftp:ssl-allow no
                                        set net:max-retries 3
                                        set net:timeout 60
                                        set xfer:log yes
                                        set xfer:show-status yes
                                        open ftp://${AEONFREE_HOST}
                                        user ${FTP_USER} ${FTP_PASS}
                                        cd ${AEONFREE_PATH}
                                        # Upload the zip file
                                        put /tmp/deploy.zip -o deploy.zip
                                        # Execute unzip command
                                        quote SITE UNZIP deploy.zip
                                        # Remove the zip file after extraction
                                        rm -f deploy.zip
                                        quit" > /tmp/lftp_script
                                        
                                        # Show lftp version and capabilities
                                        echo "LFTP version:"
                                        lftp --version
                                        
                                        # Upload zip file
                                        echo "Uploading zip file..."
                                        if ! lftp -f /tmp/lftp_script; then
                                            echo "Failed to upload zip file!"
                                            exit 1
                                        fi
                                        
                                        echo "Attempting upload and extraction..."
                                        max_retries=3
                                        attempt=1
                                        
                                        while [ $attempt -le $max_retries ]; do
                                            echo "Attempt $attempt of $max_retries..."
                                            
                                            if lftp -f /tmp/lftp_script; then
                                                echo "Upload successful!"
                                                break
                                            fi
                                            
                                            if [ $attempt -eq $max_retries ]; then
                                                echo "All upload attempts failed"
                                                exit 1
                                            fi
                                            
                                            echo "Upload attempt failed. Waiting before retry..."
                                            sleep 10
                                            attempt=$((attempt + 1))
                                        done
                                        
                                        # Try shell-based unzip as fallback
                                        echo "Attempting shell-based extraction..."
                                        echo "debug 3
                                        set ssl:verify-certificate no
                                        set ftp:ssl-allow no
                                        set net:max-retries 3
                                        set net:timeout 60
                                        open ftp://${AEONFREE_HOST}
                                        user ${FTP_USER} ${FTP_PASS}
                                        cd ${AEONFREE_PATH}
                                        # Try to use shell unzip command
                                        quote SITE EXEC unzip -o deploy.zip
                                        # Remove the zip file after extraction
                                        rm -f deploy.zip
                                        quit" > /tmp/lftp_extract
                                        
                                        if ! lftp -f /tmp/lftp_extract; then
                                            echo "Warning: Shell-based extraction failed. Files are uploaded but may need manual extraction."
                                        else
                                            echo "Shell-based extraction completed successfully."
                                        fi
                                        
                                        # Clean up temporary files
                                        rm -f /tmp/lftp_script /tmp/lftp_extract
                                        
                                        # Clean up extraction script
                                        echo "set ssl:verify-certificate no
                                        set ftp:ssl-allow no
                                        open ftp://${AEONFREE_HOST}
                                        user ${FTP_USER} ${FTP_PASS}
                                        cd ${AEONFREE_PATH}
                                        rm extract.php
                                        quit" > /tmp/lftp_script_cleanup
                                        
                                        echo "Cleaning up..."
                                        lftp -f /tmp/lftp_script_cleanup || true

                                        # Nothing here - removing duplicate code
                                        
                                        # Clean up
                                        echo "Cleaning up temporary files..."
                                        rm -f /tmp/lftp_script /tmp/extract.php
                                        
                                        # Clean up remote extract.php
                                        echo "debug 3
                                        set ssl:verify-certificate no
                                        set ftp:ssl-allow no
                                        set net:max-retries 3
                                        set net:timeout 60
                                        open ftp://${AEONFREE_HOST}
                                        user ${FTP_USER} ${FTP_PASS}
                                        cd ${AEONFREE_PATH}
                                        rm -f extract.php
                                        quit" > /tmp/lftp_cleanup
                                        
                                        lftp -f /tmp/lftp_cleanup || true
                                        rm -f /tmp/lftp_cleanup
                                        echo "All FTP attempts failed"
                                        rm /tmp/lftp_script
                                        exit 1
                                    '''
                                }
                            } catch (err) {
                                error "FTP deploy failed: ${err}"
                            }
                        }
                    }
                }
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
