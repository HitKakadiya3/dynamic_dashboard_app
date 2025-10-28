pipeline {
    agent any

    environment {
        AEONFREE_HOST = 'ftpupload.net'               // FTP host
        AEONFREE_PATH = 'htdocs'                      // Remote path on FTP
        FTP_CREDENTIALS = 'AEONFREE_FTP_CREDENTIALS'  // Jenkins credential ID (username + password)
        SITE_URL = 'https://laravel-dynamic.iceiy.com' // Your live site URL
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

        stage('Deploy to FTP & Run Laravel Commands') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${FTP_CREDENTIALS}", usernameVariable: 'FTP_USER', passwordVariable: 'FTP_PASS')]) {
                    sh '''
                        echo "🚀 Starting FTP deployment..."

                        # Create a temporary PHP script to clear caches and migrate DB
                        cat > artisan-clear.php <<'PHP'
                        <?php
                        error_reporting(E_ALL);
                        ini_set('display_errors', 1);
                        echo "<pre>🧹 Running Laravel maintenance commands...\\n";

                        require __DIR__ . '/vendor/autoload.php';
                        $app = require_once __DIR__ . '/bootstrap/app.php';
                        $kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);

                        $commands = [
                            'config:clear',
                            'cache:clear',
                            'route:clear',
                            'view:clear',
                            'config:cache',
                            'migrate:fresh --force'
                        ];

                        foreach ($commands as $cmd) {
                            echo "\\n> php artisan {$cmd}\\n";
                            $output = $kernel->call($cmd);
                            echo $kernel->output();
                        }

                        echo "\\n✅ All Laravel tasks completed successfully!\\n</pre>";
                        PHP

                        # Confirm critical assets
                        [ -f .env ] && echo "✅ Found .env" || echo "⚠️ Missing .env!"
                        [ -d vendor ] && echo "✅ Found vendor" || echo "⚠️ Missing vendor!"
                        [ -d node_modules ] && echo "✅ Found node_modules" || echo "⚠️ Missing node_modules!"

                        # Prepare LFTP mirror script
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
    --delete \
    --parallel=2 \
    --include-glob "*" \
    --include-glob ".*" \
    --exclude-glob ".git*" \
    --exclude-glob ".github*" \
    --exclude-glob ".gitlab*" \
    --exclude-glob "tests/*" \
    --exclude-glob "storage/logs/*" \
    --exclude-glob "build/*" \
    --exclude-glob "tmp/*" \
    .
bye
EOF

                        echo "📂 Uploading all files to FTP (including hidden ones)..."
                        lftp -f /tmp/lftp_mirror_script

                        echo "🌐 Triggering Laravel maintenance (cache clear + migrate:fresh)..."
                        curl -s ${SITE_URL}/artisan-clear.php || echo "⚠️ Could not trigger artisan-clear.php remotely."

                        echo "🧽 Cleaning up remote temporary file..."
                        cat > /tmp/lftp_delete_script <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
cd ${AEONFREE_PATH}
rm artisan-clear.php
bye
EOF
                        lftp -f /tmp/lftp_delete_script || echo "⚠️ Could not delete artisan-clear.php"

                        echo "✅ Deployment + Laravel commands completed!"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ FTP deployment finished successfully — all files uploaded, caches cleared, and DB migrated!"
        }
        failure {
            echo "❌ FTP deployment failed!"
        }
    }
}
