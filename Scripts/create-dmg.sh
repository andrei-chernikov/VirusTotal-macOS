#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/VirusTotal.xcodeproj"
SCHEME="VirusTotal"
CONFIGURATION="Release"
APP_NAME="VirusTotal"
VOLUME_NAME="${VT_VOLUME_NAME:-VirusTotal Local}"
BACKGROUND_PATH="$ROOT_DIR/Packaging/DMG/background.png"
SIGNING_CHECK_PATH="$ROOT_DIR/Scripts/verify-ad-hoc-app.sh"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/virustotal-dmg.XXXXXX")"
AD_HOC_ENTITLEMENTS_PATH="$WORK_DIR/entitlements.plist"

cleanup() {
    if [[ -n "${MOUNT_DIR:-}" && -d "$MOUNT_DIR" ]]; then
        hdiutil detach "$MOUNT_DIR" -quiet || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -f "$BACKGROUND_PATH" ]]; then
    echo "Missing DMG background: $BACKGROUND_PATH" >&2
    exit 1
fi

if ! PYTHONPATH="${VT_PACKAGING_PYTHONPATH:-${PYTHONPATH:-}}" python3 -c 'import ds_store, mac_alias' 2>/dev/null; then
    echo "Install Scripts/requirements-packaging.txt and set VT_PACKAGING_PYTHONPATH if using a custom directory." >&2
    exit 1
fi

mkdir -p "$ARTIFACTS_DIR"

PACKAGE_ARGUMENTS=(-onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates)
if [[ -n "${VT_PACKAGE_CACHE_PATH:-}" ]]; then
    PACKAGE_ARGUMENTS+=(-packageCachePath "$VT_PACKAGE_CACHE_PATH")
fi
if [[ -n "${VT_SOURCE_PACKAGES_PATH:-}" ]]; then
    PACKAGE_ARGUMENTS+=(-clonedSourcePackagesDirPath "$VT_SOURCE_PACKAGES_PATH")
fi

if [[ "${VT_SKIP_BUILD:-0}" != "1" ]]; then
    echo "Building $APP_NAME.app..."
    xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "${VT_DERIVED_DATA_PATH:-$WORK_DIR/DerivedData}" \
    "${PACKAGE_ARGUMENTS[@]}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    clean build
fi

APP_PATH="${VT_DERIVED_DATA_PATH:-$WORK_DIR/DerivedData}/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Build succeeded, but app was not found: $APP_PATH" >&2
    exit 1
fi

# Preserve the entitlements Xcode expanded for this app, including read-only
# folder access and the concrete Sparkle service names.
codesign -d --entitlements - --xml "$APP_PATH" > "$AD_HOC_ENTITLEMENTS_PATH" 2>/dev/null
/usr/libexec/PlistBuddy -c "Delete :com.apple.security.get-task-allow" "$AD_HOC_ENTITLEMENTS_PATH" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$AD_HOC_ENTITLEMENTS_PATH" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :com.apple.security.cs.disable-library-validation true" "$AD_HOC_ENTITLEMENTS_PATH"

codesign \
    --force \
    --sign - \
    --options runtime \
    --entitlements "$AD_HOC_ENTITLEMENTS_PATH" \
    "$APP_PATH"

"$SIGNING_CHECK_PATH" "$APP_PATH"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
DMG_PATH="$ARTIFACTS_DIR/$APP_NAME-$VERSION-local.dmg"
RW_DMG_PATH="$WORK_DIR/$APP_NAME-rw.dmg"
STAGING_DIR="$WORK_DIR/staging"

rm -f "$DMG_PATH" "$RW_DMG_PATH"
mkdir -p "$STAGING_DIR/.background"

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
cp "$BACKGROUND_PATH" "$STAGING_DIR/.background/background.png"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating writable DMG..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -format UDRW \
    -fs HFS+ \
    -ov \
    "$RW_DMG_PATH"

MOUNT_DIR=$(hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen | awk 'index($0, "/Volumes/") { print substr($0, index($0, "/Volumes/")); exit }')
if [[ -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
    echo "Could not mount DMG." >&2
    exit 1
fi
MOUNT_NAME="$(basename "$MOUNT_DIR")"

echo "Writing Finder layout..."
PYTHONPATH="${VT_PACKAGING_PYTHONPATH:-${PYTHONPATH:-}}" python3 "$ROOT_DIR/Scripts/dmg-layout.py" "$MOUNT_DIR"

sync
hdiutil detach "$MOUNT_DIR" -quiet
MOUNT_DIR=""

echo "Compressing DMG..."
hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -ov

echo "Created: $DMG_PATH"
