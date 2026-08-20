#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Attendance Flutter Web - One Click Production Deployment
# ============================================================

# -------------------------
# Configuration
# -------------------------

SERVER_USER="ubuntu"
SERVER_HOST="130.210.50.187"

SSH_KEY="/c/Users/Ashar/Desktop/OCI/keys/ssh-key-2026-06-29.key"

API_BASE_URL="https://api-attendance.mooble.win"
REMOTE_WEB_DIR="/var/www/attendance"
TEMP_REMOTE_TAR="/tmp/flutter_web_build.tar.gz"
LOCAL_TAR="flutter_web_build.tar.gz"
BUILD_DIR="build/web"


# ============================================================
# Helper functions
# ============================================================

info() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

error() {
    echo
    echo "ERROR: $1"
    exit 1
}


# ============================================================
# Validation
# ============================================================

info "Validating deployment environment"

command -v flutter >/dev/null 2>&1 || \
    error "Flutter is not installed or not available in PATH."

command -v ssh >/dev/null 2>&1 || \
    error "SSH is not available in PATH."

command -v scp >/dev/null 2>&1 || \
    error "SCP is not available in PATH."

command -v tar >/dev/null 2>&1 || \
    error "tar is not available in PATH."

[ -f "$SSH_KEY" ] || \
    error "SSH key not found: $SSH_KEY"

echo "Project directory : $(pwd)"
echo "Production server : $SERVER_USER@$SERVER_HOST"
echo "API Base URL      : $API_BASE_URL"
echo "Remote Web Dir    : $REMOTE_WEB_DIR"
echo "SSH key           : $SSH_KEY"


# ============================================================
# Confirm production deployment
# ============================================================

echo
read -r -p "Deploy Flutter Web release build to PRODUCTION ($REMOTE_WEB_DIR)? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi


# ============================================================
# 1. Build Flutter Web app
# ============================================================

info "[1/7] Building Flutter Web release package"

flutter clean
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

[ -d "$BUILD_DIR" ] || \
    error "Build directory not found: $BUILD_DIR"

echo "Flutter Web build successful."


# ============================================================
# 2. Compress web build assets
# ============================================================

info "[2/7] Compressing build assets"

rm -f "$LOCAL_TAR"

tar -czf "$LOCAL_TAR" -C "$BUILD_DIR" .

echo "Created build archive:"
ls -lh "$LOCAL_TAR"


# ============================================================
# 3. Test SSH connection
# ============================================================

info "[3/7] Testing production SSH connection"

ssh \
    -i "$SSH_KEY" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    "$SERVER_USER@$SERVER_HOST" \
    "echo 'SSH connection successful.'"


# ============================================================
# 4. Prepare remote directory
# ============================================================

info "[4/7] Preparing remote web directory"

ssh \
    -i "$SSH_KEY" \
    "$SERVER_USER@$SERVER_HOST" \
    "sudo mkdir -p '$REMOTE_WEB_DIR' && sudo chown -R $SERVER_USER:$SERVER_USER '$REMOTE_WEB_DIR'"


# ============================================================
# 5. Upload web build archive
# ============================================================

info "[5/7] Uploading build archive to production"

scp \
    -i "$SSH_KEY" \
    "$LOCAL_TAR" \
    "$SERVER_USER@$SERVER_HOST:$TEMP_REMOTE_TAR"

echo "Upload completed."


# ============================================================
# 6. Extract build & update web directory
# ============================================================

info "[6/7] Deploying build files on remote server"

ssh \
    -i "$SSH_KEY" \
    "$SERVER_USER@$SERVER_HOST" \
    "set -e

    echo 'Clearing old build files in $REMOTE_WEB_DIR...'
    sudo find '$REMOTE_WEB_DIR' -mindepth 1 -delete || sudo rm -rf '$REMOTE_WEB_DIR'/*

    echo 'Extracting build files to $REMOTE_WEB_DIR...'
    sudo tar -xzf '$TEMP_REMOTE_TAR' -C '$REMOTE_WEB_DIR'

    echo 'Setting permissions...'
    sudo chmod -R 755 '$REMOTE_WEB_DIR'
    sudo chown -R www-data:www-data '$REMOTE_WEB_DIR' || true

    echo 'Cleaning remote temporary archive...'
    rm -f '$TEMP_REMOTE_TAR'

    echo 'Reloading Nginx web server...'
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl reload nginx || sudo systemctl restart nginx
    else
        sudo service nginx reload
    fi
    "


# ============================================================
# 7. Verification & Cleanup
# ============================================================

info "[7/7] Verifying web deployment"

ssh \
    -i "$SSH_KEY" \
    "$SERVER_USER@$SERVER_HOST" \
    "echo 'Remote directory contents:' && ls -la '$REMOTE_WEB_DIR'"

# Remove local tar file
rm -f "$LOCAL_TAR"

echo
echo "============================================================"
echo "FLUTTER WEB DEPLOYMENT SUCCESSFUL"
echo "============================================================"
echo "Server : $SERVER_USER@$SERVER_HOST"
echo "Path   : $REMOTE_WEB_DIR"
echo
