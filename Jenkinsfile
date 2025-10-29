pipeline {
    agent any

    environment {
        AEONFREE_HOST = 'ftpupload.net'               // FTP host
        AEONFREE_PATH = 'htdocs'  // Remote path on FTP
        FTP_CREDENTIALS = 'AEONFREE_FTP_CREDENTIALS'  // Jenkins credential ID
        SITE_URL = 'https://laravel-dynamic.iceiy.com'
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
                    set -e
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

        stage('Build Frontend') {
            steps {
                sh '''
                    set -e
                    echo "🧰 Checking Node.js..."
                    if ! command -v npm >/dev/null 2>&1; then
                        echo "Installing Node.js 18..."
                        if command -v apt-get >/dev/null 2>&1; then
                            curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
                            apt-get install -y nodejs
                        elif command -v yum >/dev/null 2>&1; then
                            curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
                            yum install -y nodejs
                        elif command -v apk >/dev/null 2>&1; then
                            apk add --no-cache nodejs npm
                        else
                            echo "No supported package manager found for Node.js!"
                            exit 1
                        fi
                    fi

                    echo "📦 Installing dependencies..."
                    npm ci

                    echo "🏗️  Building assets..."
                    npm run build
                    echo "✅ Frontend build complete."
                '''
            }
        }

        stage('Deploy Files to FTP') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${FTP_CREDENTIALS}", usernameVariable: 'FTP_USER', passwordVariable: 'FTP_PASS')]) {
                    sh '''
                        set -e
                        echo "🚀 Starting FTP deployment..."
                        echo "📂 Workspace: $(pwd)"
                        ls -la

                        echo "📄 Preparing lftp upload script..."
                        cat > /tmp/lftp_upload_script <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
set net:max-retries 3
set net:timeout 60
set cmd:fail-exit true
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
lcd $(pwd)
cd ${AEONFREE_PATH}
mirror -R --verbose --parallel=2 --no-perms \
    --include-glob "*" \
    --include-glob ".*" \
    --exclude-glob ".git/*" \
    --exclude-glob ".github/*" \
    --exclude-glob "tests/*" \
    --exclude-glob "storage/logs/*" \
    --exclude-glob "node_modules/**" \
    --exclude-glob "vendor/**"
bye
EOF

                        echo "📤 Uploading files..."
                        lftp -f /tmp/lftp_upload_script || { echo "❌ FTP upload failed!"; exit 1; }

                        echo "✅ Files uploaded successfully."
                    '''
                }
            }
        }

        stage('Trigger Laravel Maintenance') {
            steps {
                echo "🌐 Running Laravel maintenance remotely..."
                sh '''
                    set -e
                    echo "<?php
                    error_reporting(E_ALL);
                    ini_set('display_errors', 1);
                    echo '<pre>Running Laravel maintenance...\\n';
                    require __DIR__ . '/vendor/autoload.php';
                    $app = require_once __DIR__ . '/bootstrap/app.php';
                    $kernel = $app->make(Illuminate\\\\Contracts\\\\Console\\\\Kernel::class);
                    foreach (['config:clear','cache:clear','route:clear','view:clear','config:cache'] as $cmd) {
                        echo '> php artisan ' . $cmd . '\\n';
                        $kernel->call($cmd);
                        echo $kernel->output();
                    }
                    echo '\\n✅ Done.\\n</pre>';
                    ?>" > artisan-clear.php

                    echo "📤 Uploading maintenance script..."
                    cat > /tmp/lftp_artisan_script <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
lcd $(pwd)
cd ${AEONFREE_PATH}
put artisan-clear.php
bye
EOF
                    lftp -f /tmp/lftp_artisan_script

                    echo "⚡ Executing artisan-clear.php on site..."
                    curl -fsS ${SITE_URL}/artisan-clear.php || echo "⚠️ Could not trigger artisan-clear.php remotely."

                    echo "🧹 Deleting artisan-clear.php from server..."
                    cat > /tmp/lftp_delete_script <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
cd ${AEONFREE_PATH}
rm artisan-clear.php
bye
EOF
                    lftp -f /tmp/lftp_delete_script || echo "⚠️ Cleanup failed."
                '''
            }
        }
    }

    post {
        success {
            echo "✅ Deployment finished successfully — files uploaded and Laravel cleared!"
        }
        failure {
            echo "❌ Deployment failed — check Jenkins logs for errors."
        }
    }
}
