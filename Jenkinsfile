pipeline {
    agent any

    environment {
        AEONFREE_HOST = 'ftpupload.net'               // FTP host
        AEONFREE_PATH = 'htdocs'                      // Remote path on FTP
        FTP_CREDENTIALS = 'AEONFREE_FTP_CREDENTIALS'  // Jenkins credential ID
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out repository...'
                git branch: 'main', url: 'https://github.com/HitKakadiya3/dynamic_dashboard_app.git'
            }
        }

        stage('Prepare Deployment Package') {
            steps {
                sh '''
                    echo "Preparing deployment package..."
                    cd "${WORKSPACE}"
                    rm -f /tmp/deploy.zip || true

                    echo "Installing zip if missing..."
                    if ! command -v zip >/dev/null 2>&1; then
                        if command -v apt-get >/dev/null 2>&1; then
                            apt-get update && apt-get install -y zip
                        elif command -v yum >/dev/null 2>&1; then
                            yum install -y zip
                        elif command -v apk >/dev/null 2>&1; then
                            apk add --no-cache zip
                        else
                            echo "No supported package manager found!"
                            exit 1
                        fi
                    fi

                    echo "Creating deploy.zip excluding unnecessary folders..."
                    zip -r /tmp/deploy.zip . -x "node_modules/*" "vendor/*" "storage/*" "tests/*" ".git/*" ".github/*" "build/*"
                    ls -lh /tmp/deploy.zip
                '''
            }
        }

        stage('Upload via FTP') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${FTP_CREDENTIALS}", usernameVariable: 'FTP_USER', passwordVariable: 'FTP_PASS')]) {
                    sh '''
                        echo "Installing lftp if missing..."
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

                        echo "Uploading files to FTP..."
                        cat > /tmp/lftp_script <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
set net:max-retries 3
set net:timeout 60
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
cd ${AEONFREE_PATH}
put /tmp/deploy.zip -o deploy.zip
quit
EOF
                        lftp -f /tmp/lftp_script
                        echo "Upload completed!"

                        echo "Creating remote extraction script..."
                        cat > /tmp/extract.php <<'PHP'
<?php
header("Content-Type: text/plain");
$zip = new ZipArchive;
if ($zip->open('deploy.zip') === TRUE) {
    $zip->extractTo('.');
    $zip->close();
    unlink('deploy.zip');
    echo "✅ Files extracted successfully!";
} else {
    echo "❌ Failed to open deploy.zip";
}
?>
PHP

                        echo "Uploading extract.php..."
                        cat > /tmp/lftp_extract <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
cd ${AEONFREE_PATH}
put /tmp/extract.php -o extract.php
quit
EOF
                        lftp -f /tmp/lftp_extract

                        echo "Triggering extraction on remote server..."
                        curl -s "http://${AEONFREE_HOST}/${AEONFREE_PATH}/extract.php" || true
                        echo "Cleaning up extract.php remotely..."
                        cat > /tmp/lftp_cleanup <<EOF
set ftp:ssl-allow no
set ssl:verify-certificate no
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
cd ${AEONFREE_PATH}
rm extract.php
quit
EOF
                        lftp -f /tmp/lftp_cleanup
                        echo "Deployment completed successfully!"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ FTP deployment completed successfully!"
        }
        failure {
            echo "❌ FTP deployment failed!"
        }
    }
}
