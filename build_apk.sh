#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Attendance Flutter Mobile - One-Click Release APK Builder
# ============================================================

# -------------------------
# Configuration & Defaults
# -------------------------

API_BASE_URL="${API_BASE_URL:-https://api-attendance.mooble.win}"
FLUTTER_BUILD_DIR="build/app/outputs/flutter-apk"
DIST_DIR="dist/apk"
KEY_PROPERTIES="android/key.properties"

# ============================================================
# Helper Functions
# ============================================================

info() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

success() {
    echo
    echo "============================================================"
    echo "SUCCESS: $1"
    echo "============================================================"
}

warn() {
    echo "WARNING: $1"
}

error() {
    echo
    echo "ERROR: $1" >&2
    exit 1
}

# ============================================================
# 1. Validation & Environment Checks
# ============================================================

info "Validating build environment"

command -v flutter >/dev/null 2>&1 || \
    error "Flutter is not installed or not available in PATH."

[ -f "pubspec.yaml" ] || \
    error "Please run this script from the Flutter project root directory (containing pubspec.yaml)."

# Extract app version from pubspec.yaml
APP_VERSION=$(grep -m 1 '^version:' pubspec.yaml | awk '{print $2}' | tr -d '\r' || echo "1.0.0+1")
CLEAN_VERSION=$(echo "$APP_VERSION" | tr '+' '_')

echo "Project Directory : $(pwd)"
echo "App Version       : $APP_VERSION"
echo "API Base URL      : $API_BASE_URL"
echo "Distribution Dir  : $DIST_DIR"

if [ -f "$KEY_PROPERTIES" ]; then
    echo "Signing Config    : Production Keystore (android/key.properties found)"
else
    warn "android/key.properties not found. Building with default release signing configuration."
    warn "(To use a custom production keystore, see android/key.properties.example)"
fi

# ============================================================
# 2. Clean & Fetch Dependencies
# ============================================================

info "[1/5] Fetching Flutter dependencies"

flutter clean
flutter pub get

# ============================================================
# 3. Analyze & Run Automated Tests
# ============================================================

info "[2/5] Running static analysis & tests"

echo "Running flutter analyze..."
flutter analyze --no-fatal-infos || warn "Some lints reported during analysis."

echo "Running flutter test..."
flutter test

# ============================================================
# 4. Build Release Signed APK
# ============================================================

info "[3/5] Compiling Android Release APK"

mkdir -p "$DIST_DIR"

# Build universal release APK
flutter build apk \
    --release \
    --dart-define=API_BASE_URL="$API_BASE_URL"

[ -f "$FLUTTER_BUILD_DIR/app-release.apk" ] || \
    error "Build failed: $FLUTTER_BUILD_DIR/app-release.apk not found."

# ============================================================
# 5. Package & Copy to Distribution Folder
# ============================================================

info "[4/5] Organizing distribution artifacts"

TARGET_APK="$DIST_DIR/attendance_app-v${CLEAN_VERSION}-release.apk"
LATEST_APK="$DIST_DIR/attendance_app-release-latest.apk"

cp -f "$FLUTTER_BUILD_DIR/app-release.apk" "$TARGET_APK"
cp -f "$FLUTTER_BUILD_DIR/app-release.apk" "$LATEST_APK"

# Calculate File Size & Checksum
APK_SIZE=$(ls -lh "$TARGET_APK" | awk '{print $5}')
SHA256_HASH=""
if command -v sha256sum >/dev/null 2>&1; then
    SHA256_HASH=$(sha256sum "$TARGET_APK" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    SHA256_HASH=$(shasum -a 256 "$TARGET_APK" | awk '{print $1}')
elif command -v certutil >/dev/null 2>&1; then
    SHA256_HASH=$(certutil -hashfile "$TARGET_APK" SHA256 | sed -n '2p' | tr -d ' \r\n')
fi

# ============================================================
# 6. Build Summary & Next Steps
# ============================================================

info "[5/5] Release APK Build Complete"

echo
echo "APK Details:"
echo "------------------------------------------------------------"
echo "Version         : $APP_VERSION"
echo "API Endpoint    : $API_BASE_URL"
echo "Primary File    : $TARGET_APK"
echo "Latest Shortcut : $LATEST_APK"
echo "File Size       : $APK_SIZE"
if [ -n "$SHA256_HASH" ]; then
    echo "SHA-256 Hash    : $SHA256_HASH"
fi
echo "------------------------------------------------------------"
echo
echo "Installation Instructions:"
echo "• Connect an Android phone via USB with USB Debugging enabled, then run:"
echo "  adb install -r $TARGET_APK"
echo
echo "• Or copy the APK to your phone/Google Drive to share with teachers."
echo

success "Release APK successfully built in ./$DIST_DIR/"
