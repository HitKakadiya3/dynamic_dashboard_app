pipeline {
    agent any

    environment {
        IMAGE_NAME = 'hitendra369/laravel_dynamic_dashboard' // Docker image name
        IMAGE_TAG = "${env.BUILD_NUMBER}"             // Tag with build number
        DOCKER_REGISTRY = 'hitendra369'    // Docker Hub username
        DOCKER_CREDENTIALS = 'docker_hub_creds'      // Jenkins stored credentials ID
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
                        sh "echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin ${DOCKER_REGISTRY}"
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }

        stage('Clean Up') {
            steps {
                echo 'Cleaning up local images...'
                sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
                sh "docker rmi ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true"
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
