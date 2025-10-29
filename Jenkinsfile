pipeline {
    agent any

    environment {
        // free-hosting.org configuration (set these in Jenkins environment or here)
        FTP_HOST = 'ftpupload.net'                         // e.g. ftp.free-hosting.org (set in Jenkins)
        FTP_PATH = 'htdocs'                   // remote path root for site content
        FTP_CREDENTIALS_ID = 'FREEHOSTING_FTP_CREDENTIALS' // Jenkins credential ID (Username with password)

        // Site URL for remote maintenance trigger
        SITE_URL = 'http://laravel-dynamic.yzz.me'                         // e.g. https://your-subdomain.free-hosting.org
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
                    echo "🔧 Ensuring lftp is installed..."

                    if ! command -v lftp >/dev/null 2>&1; then
                        if command -v apt-get >/dev/null 2>&1; then
                            apt-get update && apt-get install -y lftp
                        elif command -v yum >/dev/null 2>&1; then
                            yum install -y lftp
                        elif command -v apk >/dev/null 2>&1; then
                            apk add --no-cache lftp
                        else
                            echo "No supported package manager found for lftp" && exit 1
                        fi
                    fi

                    echo "✅ lftp ready"
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
                            echo "No supported package manager found for Node.js" && exit 1
                        fi
                    fi

                    echo "📦 Installing dependencies (npm ci)..."
                    npm ci

                    echo "🏗️  Building assets (npm run build)..."
                    npm run build

                    echo "✅ Frontend build complete"
                '''
            }
        }

        stage('Deploy Files to FTP') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${FTP_CREDENTIALS_ID}", usernameVariable: 'FREEHOSTING_FTP_USER', passwordVariable: 'FREEHOSTING_FTP_PASS')]) {
                    sh '''
                        set -e

                        # Validate inputs
                        [ -n "$FREEHOSTING_FTP_USER" ] && [ -n "$FREEHOSTING_FTP_PASS" ] || { echo "❌ Missing FTP credentials"; exit 1; }
                        [ -n "$FTP_HOST" ] || { echo "❌ Missing FTP_HOST (FTP server)"; exit 1; }
                        [ -n "$FTP_PATH" ] || { echo "❌ Missing FTP_PATH (remote directory)"; exit 1; }

                        echo "🔎 Testing FTP connectivity..."
                        lftp -d -e "set ftp:passive-mode true; set ftp:ssl-allow yes; set ssl:verify-certificate no; set net:timeout 30; open ftp://$FTP_HOST; user '$FREEHOSTING_FTP_USER' '$FREEHOSTING_FTP_PASS'; pwd; ls; bye" || { echo "❌ FTP login/list failed"; exit 1; }

                        echo "📄 Preparing lftp upload script..."
                        cat > /tmp/lftp_upload_script <<EOF
set ftp:passive-mode true
set ftp:ssl-allow yes
set ssl:verify-certificate no
set net:max-retries 5
set net:timeout 120
set net:reconnect-interval-base 5
set net:reconnect-interval-multiplier 1.5
set cmd:fail-exit true
open ftp://$FTP_HOST
user "$FREEHOSTING_FTP_USER" "$FREEHOSTING_FTP_PASS"
lcd $(pwd)
cd $FTP_PATH
mirror -R --verbose --parallel=2 --no-perms \
    --include-glob "*" \
    --include-glob ".*" \
    --exclude-glob ".git/*" \
    --exclude-glob ".github/*" \
    --exclude-glob "tests/*" \
    --exclude-glob "storage/logs/*"
bye
EOF

                        echo "📤 Uploading files (verbose)..."
                        lftp -d -f /tmp/lftp_upload_script

                        echo "✅ Files uploaded"
                    '''
                }
            }
        }

        stage('Trigger Laravel Maintenance') {
            steps {
                echo '🌐 Running Laravel maintenance remotely...'
                withCredentials([usernamePassword(credentialsId: "${FTP_CREDENTIALS_ID}", usernameVariable: 'FREEHOSTING_FTP_USER', passwordVariable: 'FREEHOSTING_FTP_PASS')]) {
                    sh '''
                        set -e

                        # Validate inputs
                        [ -n "$FREEHOSTING_FTP_USER" ] && [ -n "$FREEHOSTING_FTP_PASS" ] || { echo "❌ Missing FTP credentials"; exit 1; }
                        [ -n "$FTP_HOST" ] || { echo "❌ Missing FTP_HOST (FTP server)"; exit 1; }
                        [ -n "$FTP_PATH" ] || { echo "❌ Missing FTP_PATH (remote directory)"; exit 1; }

                        # Create maintenance script
                        cat > artisan-clear.php <<'PHP'
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
echo "<pre>Running Laravel maintenance...\n";
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
foreach (['config:clear','cache:clear','route:clear','view:clear','config:cache'] as $cmd) {
    echo "> php artisan {$cmd}\n";
    $kernel->call($cmd);
    echo $kernel->output();
}
echo "\n✅ Done.\n</pre>";
PHP

                        echo "📤 Uploading maintenance script..."
                        cat > /tmp/lftp_artisan_script <<EOF
set ftp:passive-mode true
set ftp:ssl-allow yes
set ssl:verify-certificate no
set net:timeout 60
open ftp://$FTP_HOST
user "$FREEHOSTING_FTP_USER" "$FREEHOSTING_FTP_PASS"
lcd $(pwd)
cd $FTP_PATH
put artisan-clear.php
bye
EOF
                        lftp -d -f /tmp/lftp_artisan_script

                        echo "⚡ Executing artisan-clear.php on site..."
                        if [ -n "$SITE_URL" ]; then
                          curl -fsS "$SITE_URL"/artisan-clear.php || echo "⚠️ Could not trigger artisan-clear.php remotely"
                        else
                          echo "ℹ️ SITE_URL not set; skipping remote trigger"
                        fi

                        echo "🧹 Deleting maintenance script from server..."
                        cat > /tmp/lftp_delete_script <<EOF
set ftp:passive-mode true
set ftp:ssl-allow yes
set ssl:verify-certificate no
set net:timeout 60
open ftp://$FTP_HOST
user "$FREEHOSTING_FTP_USER" "$FREEHOSTING_FTP_PASS"
cd $FTP_PATH
rm artisan-clear.php
bye
EOF
                        lftp -d -f /tmp/lftp_delete_script || echo "⚠️ Cleanup failed"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ Deployment finished successfully — files uploaded and Laravel cleared!'
        }
        failure {
            echo '❌ Deployment failed — check Jenkins logs for errors.'
        }
    }
}
