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
                            echo 'RENDER_DEPLOY_HOOK is not configured; skipping Render deployment.'
                        } else {
                            echo 'Docker push succeeded — triggering Render deployment via Deploy Hook...'
                            // Use the Render Deploy Hook URL (secret) to kick off a deployment.
                            // Jenkins will mask the secret env var in logs.
                            sh '''
                                set -e
                                curl -sS -X POST "$RENDER_DEPLOY_HOOK"
                            '''
                            echo 'Render deployment triggered.'
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
