pipeline {
    agent any

    environment {
        AEONFREE_HOST = 'ftpupload.net'               // FTP host
        AEONFREE_PATH = 'htdocs'                      // Remote path on FTP
        FTP_CREDENTIALS = 'AEONFREE_FTP_CREDENTIALS'  // Jenkins credential ID (username + password)
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out repository...'
                git branch: 'main', url: 'https://github.com/HitKakadiya3/dynamic_dashboard_app.git'
            }
        }

        stage('Install FTP Client') {
            steps {
                sh '''
                    echo "Installing lftp if not found..."
                    if ! command -v lftp >/dev/null 2>&1; then
                        if command -v apt-get >/dev/null 2>&1; then
                            apt-get update && apt-get install -y lftp
                        elif command -v yum >/dev/null 2>&1; then
                            yum install -y lftp
                        elif command -v apk >/dev/null 2>&1; then
                            apk add --no-cache lftp
                        else
                            echo "No supported package manager found for lftp!"
                            exit 1
                        fi
                    fi
                '''
            }
        }

        stage('Deploy to FTP') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${FTP_CREDENTIALS}", usernameVariable: 'FTP_USER', passwordVariable: 'FTP_PASS')]) {
                    sh '''
                        echo "Starting FTP deployment..."

                        # Ensure vendor and node_modules exist if needed
                        [ -d vendor ] && echo "✅ vendor folder found"
                        [ -d node_modules ] && echo "✅ node_modules folder found"
                        [ -f .env ] && echo "✅ .env file found"

                        # Create lftp mirror script
                        cat > /tmp/lftp_mirror_script <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
set net:max-retries 2
set net:timeout 30
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
mirror -R \
    --verbose \
    --only-newer \
    --parallel=2 \
    --exclude .git/ \
    --exclude .github/ \
    --exclude .gitlab/ \
    --exclude .gitignore \
    --exclude .gitattributes \
    ./ ${AEONFREE_PATH}
bye
EOF

                        echo "Running lftp mirror..."
                        lftp -f /tmp/lftp_mirror_script

                        echo "✅ FTP deployment complete!"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ All files and folders uploaded to FTP successfully!"
        }
        failure {
            echo "❌ FTP deployment failed!"
        }
    }
}
