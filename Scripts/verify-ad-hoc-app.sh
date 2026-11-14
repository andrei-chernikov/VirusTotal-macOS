#!/bin/zsh
set -euo pipefail

APP_PATH="${1:?Usage: verify-ad-hoc-app.sh /path/to/VirusTotal.app}"
[[ -d "$APP_PATH" ]] || { echo "App not found: $APP_PATH" >&2; exit 1; }
ENTITLEMENTS_PATH="$(mktemp "${TMPDIR:-/tmp}/virustotal-entitlements.XXXXXX")"
trap 'rm -f "$ENTITLEMENTS_PATH"' EXIT
codesign -d --entitlements - --xml "$APP_PATH" > "$ENTITLEMENTS_PATH" 2>/dev/null

for key in com.apple.security.app-sandbox \
           com.apple.security.cs.disable-library-validation \
           com.apple.security.files.user-selected.read-only \
           com.apple.security.files.bookmarks.app-scope \
           com.apple.security.network.client; do
    value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$ENTITLEMENTS_PATH")
    [[ "$value" == "true" ]] || { echo "Missing entitlement: $key" >&2; exit 1; }
done

if /usr/libexec/PlistBuddy -c "Print :com.apple.security.get-task-allow" "$ENTITLEMENTS_PATH" 2>/dev/null | /usr/bin/grep -q '^true$'; then
    echo "Release app unexpectedly allows debugger attachment." >&2
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "Ad-hoc app signing configuration is valid."
