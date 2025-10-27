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
                        echo "Preparing deployment to ${env.AEONFREE_HOST}..."
                        sh '''
                            # Create zip archive including all files
                            cd "${WORKSPACE}"
                            echo "Creating deployment package..."
                            
                            # Check if zip is installed
                            if [ $(command -v zip >/dev/null 2>&1; echo $?) -eq 0 ]; then
                                echo "Zip command is available"
                            else
                                echo "Installing zip..."
                                if [ $(command -v apt-get >/dev/null 2>&1; echo $?) -eq 0 ]; then
                                    apt-get update && apt-get install -y zip
                                elif [ $(command -v yum >/dev/null 2>&1; echo $?) -eq 0 ]; then
                                    yum install -y zip
                                elif [ $(command -v apk >/dev/null 2>&1; echo $?) -eq 0 ]; then
                                    apk add --no-cache zip
                                else
                                    echo "No package manager found to install zip"
                                    exit 1
                                fi
                            fi
                            
                            echo "Creating zip archive..."
                            zip -r /tmp/deploy.zip . -x "storage/*" "tests/*" "build/*"
                            
                            echo "Archive created successfully"
                        // Install zip if not available
                        script {
                            def hasZip = sh(script: 'which zip', returnStatus: true) == 0
                            if (hasZip) {
                                sh 'echo "Zip is already installed"'
                            } else {
                                sh '''
                                    echo "Installing zip..."
                                    if [ -x "$(command -v apt-get)" ]; then
                                
                                        apt-get update && apt-get install -y zip
                                    elif [ -x "$(command -v yum)" ]; then
                                        yum install -y zip
                                    elif [ -x "$(command -v apk)" ]; then
                                        apk add --no-cache zip
                                    else
                                        echo "No supported package manager found. Please install zip manually."
                                        exit 1
                                    fi
                                '''
                            }
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

                                        # First check what exists and create zip file accordingly
                                        cd "${WORKSPACE}"
                                        echo "Checking for vendor, node_modules, and .env..."
                                        
                                        # Start with base exclusions - explicitly exclude all git-related files
                                        EXCLUDE_OPTS="-x .git/* .git/ .gitignore .gitattributes .github/* .gitlab/* storage/* tests/* build/* */.git/* */.gitignore"
                                        
                                        # Check if vendor exists and should be included
                                        if [ -d "vendor" ] && [ -f "vendor/autoload.php" ]; then
                                            echo "Found valid vendor directory - including in deployment"
                                        else
                                            echo "Excluding vendor directory"
                                            EXCLUDE_OPTS="$EXCLUDE_OPTS vendor/*"
                                        fi
                                        
                                        # Check if node_modules exists and should be included
                                        if [ -d "node_modules" ] && [ -f "node_modules/.package-lock.json" ]; then
                                            echo "Found valid node_modules directory - including in deployment"
                                        else
                                            echo "Excluding node_modules directory"
                                            EXCLUDE_OPTS="$EXCLUDE_OPTS node_modules/*"
                                        fi
                                        
                                        # Check if .env exists
                                        if [ -f ".env" ]; then
                                            echo "Found .env file - including in deployment"
                                        else
                                            echo "No .env file found"
                                            EXCLUDE_OPTS="$EXCLUDE_OPTS .env"
                                        fi
                                        
                                        echo "Checking for git files before creating archive..."
                                        find . -name ".git*" -o -name ".git"
                                        
                                        echo "Creating deployment archive..."
                                        echo "Exclusion options: $EXCLUDE_OPTS"
                                        eval "zip -r /tmp/deploy.zip . $EXCLUDE_OPTS"
                                        
                                        # Verify the contents of the zip file
                                        echo "Verifying archive contents..."
                                        
                                        # Check for included important files
                                        echo "Checking key files..."
                                        unzip -l /tmp/deploy.zip > /tmp/zip_contents.txt
                                        
                                        echo "Checking for vendor files..."
                                        grep 'vendor/autoload.php' /tmp/zip_contents.txt || echo "No vendor/autoload.php found"
                                        
                                        echo "Checking for node_modules..."
                                        grep 'node_modules/' /tmp/zip_contents.txt || echo "No node_modules found"
                                        
                                        echo "Checking for .env file..."
                                        grep '.env' /tmp/zip_contents.txt || echo "No .env found"
                                        
                                        # Verify no git files are included
                                        echo "Verifying no git files are included:"
                                        git_files=$(grep -E '.git/|.gitignore|.gitattributes|.github/|.gitlab/' /tmp/zip_contents.txt || true)
                                        if [ ! -z "$git_files" ]; then
                                            echo "ERROR: Git-related files found in archive!"
                                            echo "Found git files:"
                                            echo "ERROR: Git-related files found in archive:"
                                            echo "$git_files"
                                            rm -f /tmp/zip_contents.txt
                                            exit 1
                                        else
                                            echo "Confirmed: No git-related files in archive"
                                        fi
                                        
                                        # Show summary of archive
                                        echo "Archive contents summary:"
                                        echo "----------------------------------------"
                                        unzip -l /tmp/deploy.zip | head -n 5
                                        echo "..."
                                        unzip -l /tmp/deploy.zip | tail -n 3
                                        echo "----------------------------------------"
                                        
                                        # Clean up
                                        rm -f /tmp/zip_contents.txt
                                        
                                        # Check zip file size
                                        zip_size=$(ls -lh /tmp/deploy.zip | awk '{print $5}')
                                        echo "Archive size: $zip_size"
                                        
                                        # Create extract.php script
                                        cat <<'EOF' > /tmp/extract.php
<?php
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
?>
EOF

                                        # Create lftp script for upload
                                        echo "set cmd:fail-exit yes;
                                        debug 3;
                                        set ssl:verify-certificate no;
                                        set ftp:ssl-allow no;
                                        set net:max-retries 3;
                                        set net:timeout 60;
                                        set xfer:log yes;
                                        set xfer:show-status yes;
                                        open ftp://${AEONFREE_HOST};
                                        user ${FTP_USER} ${FTP_PASS};
                                        cd ${AEONFREE_PATH};
                                        put /tmp/deploy.zip -o deploy.zip;
                                        quit;" > /tmp/lftp_script
                                            echo date("Y-m-d H:i:s") . " - " . $message . "\\n";
                                        }
                                        
                                        function checkPermissions() {
                                            $currentDir = getcwd();
                                            debug("Current directory: " . $currentDir);
                                            debug("Current user: " . get_current_user());
                                            debug("Directory writable: " . (is_writable($currentDir) ? "yes" : "no"));
                                            
                                            if (!is_writable($currentDir)) {
                                                chmod($currentDir, 0755);
                                                debug("Attempted to set directory permissions to 755");
                                                if (!is_writable($currentDir)) {
                                                    debug("ERROR: Directory still not writable after chmod");
                                                    return false;
                                                }
                                            }
                                            return true;
                                        }
                                        
                                        function checkZipFile() {
                                            if (!file_exists("deploy.zip")) {
                                                debug("ERROR: deploy.zip not found");
                                                return false;
                                            }
                                            $size = filesize("deploy.zip");
                                            debug("ZIP file size: " . $size . " bytes");
                                            if ($size === 0) {
                                                debug("ERROR: deploy.zip is empty");
                                                return false;
                                            }
                                            return true;
                                        }
                                        
                                        function listCurrentFiles() {
                                            debug("Current directory contents:");
                                            $files = scandir(".");
                                            foreach ($files as $file) {
                                                if ($file != "." && $file != "..") {
                                                    $perms = substr(sprintf("%o", fileperms("./" . $file)), -4);
                                                    debug($file . " (permissions: " . $perms . ")");
                                                }
                                            }
                                        }
                                        
                                        function extractZip() {
                                            debug("Starting ZIP extraction...");
                                            $zip = new ZipArchive();
                                            $res = $zip->open("deploy.zip");
                                            if ($res !== TRUE) {
                                                debug("ERROR: Failed to open ZIP (error code: " . $res . ")");
                                                return false;
                                            }
                                            
                                            debug("ZIP opened successfully. File count: " . $zip->numFiles);
                                            
                                            // First check if we can extract
                                            for ($i = 0; $i < $zip->numFiles; $i++) {
                                                $filename = $zip->getNameIndex($i);
                                                $dirname = dirname($filename);
                                                if ($dirname !== "." && !is_dir($dirname)) {
                                                    if (!mkdir($dirname, 0755, true)) {
                                                        debug("ERROR: Could not create directory: " . $dirname);
                                                        $zip->close();
                                                        return false;
                                                    }
                                                    debug("Created directory: " . $dirname);
                                                }
                                            }
                                            
                                            debug("Extracting files...");
                                            if (!$zip->extractTo(".")) {
                                                $error = error_get_last();
                                                debug("ERROR: Failed to extract files - " . ($error ? $error["message"] : "Unknown error"));
                                                $zip->close();
                                                return false;
                                            }
                                            
                                            $zip->close();
                                            debug("ZIP extraction completed");
                                            
                                            // Verify extraction
                                            $extracted = false;
                                            if (file_exists("artisan") && file_exists("composer.json")) {
                                                debug("Verified key Laravel files exist");
                                                $extracted = true;
                                            } else {
                                                debug("ERROR: Key Laravel files missing after extraction");
                                            }
                                            
                                            return $extracted;
                                        }
                                        
                                        // Main execution
                                        debug("=== Starting extraction process ===");
                                        listCurrentFiles();
                                        
                                        if (!checkPermissions()) {
                                            debug("ERROR: Permission check failed");
                                            exit(1);
                                        }
                                        
                                        if (!checkZipFile()) {
                                            debug("ERROR: ZIP file check failed");
                                            exit(1);
                                        }
                                        
                                        if (!extractZip()) {
                                            debug("ERROR: Extraction failed");
                                            exit(1);
                                        }
                                        
                                        debug("=== Post-extraction state ===");
                                        listCurrentFiles();
                                        
                                        // Only delete zip if everything was successful
                                        if (file_exists("deploy.zip")) {
                                            if (unlink("deploy.zip")) {
                                                debug("ZIP file cleaned up");
                                            } else {
                                                debug("WARNING: Could not delete ZIP file");
                                            }
                                        }
                                        
                                        debug("SUCCESS: Deployment completed successfully");
                                        ?>' > /tmp/extract.php
                                        
                                        # Now create the lftp script for upload
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
                                        # Upload both files
                                        put /tmp/deploy.zip -o deploy.zip
                                        put /tmp/extract.php -o extract.php
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
                                        
                                        echo "Starting upload process..."
                                        max_retries=3
                                        attempt=1
                                        
                                        while [ "$attempt" -le "$max_retries" ]
                                        do
                                            echo "Upload attempt $attempt of $max_retries..."
                                            
                                            if lftp -f /tmp/lftp_script
                                            then
                                                echo "Files uploaded successfully!"
                                                break
                                            fi
                                            
                                            if [ "$attempt" -eq "$max_retries" ]
                                            then
                                                echo "All upload attempts failed"
                                                rm -f /tmp/lftp_script /tmp/deploy.zip /tmp/extract.php
                                                exit 1
                                            fi
                                            
                                            echo "Upload attempt failed. Waiting before retry..."
                                            sleep 10
                                            attempt=`expr $attempt + 1`
                                        done
                                        
                                        echo "Creating PHP extraction script..."
                                        # Create a more robust extraction script
                                        cat > /tmp/extract.php << 'EOF'
<?php
header("Content-Type: text/plain");
error_reporting(E_ALL);
ini_set("display_errors", 1);

function debug($message) {
    echo date("Y-m-d H:i:s") . " - " . $message . "\n";
}

function checkZipFile() {
    if (!file_exists("deploy.zip")) {
        debug("Error: deploy.zip not found");
        return false;
    }
    return true;
}

function extractFiles() {
    $zip = new ZipArchive;
    $res = $zip->open("deploy.zip");
    if ($res === TRUE) {
        debug("Zip opened successfully");
        
        // First create directories
        for ($i = 0; $i < $zip->numFiles; $i++) {
            $dirname = dirname($zip->getNameIndex($i));
            if ($dirname !== "." && !is_dir($dirname)) {
                if (!mkdir($dirname, 0755, true)) {
                    debug("Failed to create directory: " . $dirname);
                    $zip->close();
                    return false;
                }
            }
        }
        
        if (!$zip->extractTo(".")) {
            debug("Failed to extract files");
            $zip->close();
            return false;
        }
        
        $zip->close();
        debug("Files extracted successfully");
        
        if (!unlink("deploy.zip")) {
            debug("Warning: Could not delete deploy.zip");
        }
        
        return true;
    }
    debug("Failed to open zip (error code: " . $res . ")");
    return false;
}

debug("Starting extraction process");

if (!checkZipFile()) {
    exit(1);
}

if (!extractFiles()) {
    exit(1);
}

echo "Extraction complete";
?>
EOF

                                        # Create LFTP script for uploading extract.php
                                        cat > /tmp/lftp_extract << EOL
set cmd:fail-exit yes
debug 3
set ssl:verify-certificate no
set ftp:ssl-allow no
set net:max-retries 3
set net:timeout 60
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
cd ${AEONFREE_PATH}
put /tmp/extract.php -o extract.php
quit
EOL

                                        echo "Uploading extraction script..."
                                        if lftp -f /tmp/lftp_extract; then
                                            echo "Extraction script uploaded successfully"
                                        else
                                            echo "Failed to upload extraction script"
                                            exit 1
                                        fi                                        echo "Waiting for files to be ready..."
                                        sleep 5
                                        
                                        echo "Starting extraction..."
                                        response=$(curl -s "http://${AEONFREE_HOST}/${AEONFREE_PATH}/extract.php")
                                        echo "Server response: $response"
                                        
                                        if echo "$response" | grep -q "Extraction complete"; then
                                            echo "Extraction completed successfully"
                                        else
                                            echo "Extraction failed!"
                                            exit 1
                                        fi
                                        
                                        echo "Extraction completed successfully!"
                                        
                                        # Clean up extract.php from server
                                        echo "Cleaning up..."
                                        echo "set ssl:verify-certificate no;
                                        set ftp:ssl-allow no;
                                        open ftp://${AEONFREE_HOST};
                                        user ${FTP_USER} ${FTP_PASS};
                                        cd ${AEONFREE_PATH};
                                        rm -f extract.php;
                                        quit;" > /tmp/lftp_cleanup
                                        
                                        lftp -f /tmp/lftp_cleanup || true
                                        
                                        # Clean up remote extraction script
                                        cat > /tmp/lftp_cleanup << EOL
set cmd:fail-exit yes
debug 3
set ssl:verify-certificate no
set ftp:ssl-allow no
set net:max-retries 3
set net:timeout 60
open ftp://${AEONFREE_HOST}
user ${FTP_USER} ${FTP_PASS}
cd ${AEONFREE_PATH}
rm -f extract.php
quit
EOL

                                        echo "Cleaning up..."
                                        lftp -f /tmp/lftp_cleanup || true
                                        
                                        # Clean up local temporary files
                                        rm -f /tmp/lftp_script /tmp/lftp_cleanup /tmp/deploy.zip /tmp/extract.php
                                        
                                        echo "Deployment completed successfully!"
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
