#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Unity-iPhone.xcodeproj"
SCHEME="Unity-iPhone"
CONFIG="Release"
METHOD="${1:-unsigned}"
TEAM="${DEVELOPMENT_TEAM:-}"
BUNDLE_ID="${BUNDLE_ID:-com.DefaultCompany.DragonBoy002}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUT="$ROOT/ios-build/out"
ARCHIVE="$OUT/NroChamPa.xcarchive"
EXPORT_DIR="$OUT/ipa"
APP_NAME="NroFunz"
PROFILE_NAME="${PROVISIONING_PROFILE_NAME:-}"

[[ "$(uname -s)" == Darwin ]] || { echo 'Requires macOS' >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo 'Missing Xcode' >&2; exit 1; }
[[ -d "$PROJECT" ]] || { echo "Missing project $PROJECT" >&2; exit 1; }
for lib in Libraries/libiPhone-lib.a Libraries/libil2cpp.a; do
  file="$ROOT/$lib"
  [[ -f "$file" ]] || { echo "Missing $lib" >&2; exit 1; }
  [[ "$(head -c 8 "$file")" == '!<arch>' ]] || { echo "Invalid library/LFS pointer: $lib" >&2; exit 1; }
done
case "$METHOD" in
  unsigned|development|ad-hoc|app-store-connect) ;;
  *) echo "Invalid method: $METHOD" >&2; exit 1 ;;
esac
if [[ "$METHOD" != unsigned ]]; then
  [[ -n "$TEAM" && -n "$PROFILE_NAME" ]] || { echo 'Signed build requires DEVELOPMENT_TEAM and PROVISIONING_PROFILE_NAME' >&2; exit 1; }
fi
mkdir -p "$OUT"
rm -rf "$ARCHIVE" "$EXPORT_DIR" "$OUT/DerivedData"
ARGS=( -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" -destination 'generic/platform=iOS' CURRENT_PROJECT_VERSION="$BUILD_NUMBER" )
[[ -n "$BUNDLE_ID" ]] && ARGS+=(PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID")
if [[ "$METHOD" == unsigned ]]; then
  xcodebuild "${ARGS[@]}" -derivedDataPath "$OUT/DerivedData" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
  APP="$OUT/DerivedData/Build/Products/$CONFIG-iphoneos/$APP_NAME.app"
  if [[ ! -d "$APP" ]]; then
    echo "App not found: $APP. Actual apps:" >&2
    find "$OUT/DerivedData/Build/Products" -maxdepth 3 -name '*.app' -print >&2 || true
    exit 1
  fi
  mkdir -p "$OUT/Payload"
  cp -R "$APP" "$OUT/Payload/"
  (cd "$OUT" && zip -qry "$APP_NAME-unsigned.ipa" Payload)
  rm -rf "$OUT/Payload"
  echo "Unsigned IPA: $OUT/$APP_NAME-unsigned.ipa"
  exit 0
fi
ARGS+=(DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME")
xcodebuild "${ARGS[@]}" -archivePath "$ARCHIVE" archive
PLIST="$OUT/ExportOptions.plist"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>$METHOD</string>
<key>teamID</key><string>$TEAM</string>
<key>signingStyle</key><string>manual</string>
<key>provisioningProfiles</key><dict><key>$BUNDLE_ID</key><string>$PROFILE_NAME</string></dict>
<key>stripSwiftSymbols</key><true/>
</dict></plist>
PLIST_EOF
mkdir -p "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$PLIST" -exportPath "$EXPORT_DIR"
find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -print
