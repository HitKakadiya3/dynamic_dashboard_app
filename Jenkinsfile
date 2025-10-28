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
                echo '📦 Checking out repository...'
                git branch: 'main', url: 'https://github.com/HitKakadiya3/dynamic_dashboard_app.git'
            }
        }

        stage('Install FTP Client') {
            steps {
                sh '''
                    echo "🔧 Checking for lftp..."
                    if ! command -v lftp >/dev/null 2>&1; then
                        echo "Installing lftp..."
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
                    echo "✅ lftp is ready."
                '''
            }
        }

        stage('Deploy to FTP') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${FTP_CREDENTIALS}", usernameVariable: 'FTP_USER', passwordVariable: 'FTP_PASS')]) {
                    sh '''
                        echo "🚀 Starting FTP deployment..."

                        # Verify important files and folders
                        [ -f .env ] && echo "✅ Found .env file" || echo "⚠️ Missing .env file!"
                        [ -d vendor ] && echo "✅ Found vendor folder" || echo "⚠️ Missing vendor folder!"
                        [ -d node_modules ] && echo "✅ Found node_modules folder" || echo "⚠️ Missing node_modules folder!"

                        # Create LFTP script for mirroring
                        cat > /tmp/lftp_mirror_script <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
set net:max-retries 3
set net:timeout 60
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
lcd .
cd ${AEONFREE_PATH}
mirror -R \
    --verbose \
    --only-newer \
    --parallel=2 \
    --include .env \
    --include vendor/ \
    --include node_modules/ \
    --include .htaccess \
    --exclude .git/ \
    --exclude .github/ \
    --exclude .gitlab/ \
    --exclude tests/ \
    --exclude storage/logs/ \
    --exclude build/ \
    --exclude tmp/ \
    .
bye
EOF

                        echo "📂 Uploading all files (including .env, vendor, node_modules)..."
                        lftp -f /tmp/lftp_mirror_script

                        echo "✅ Deployment completed successfully!"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ FTP deployment finished successfully — all files uploaded!"
        }
        failure {
            echo "❌ FTP deployment failed!"
        }
    }
}
