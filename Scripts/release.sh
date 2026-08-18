#!/bin/bash
# Build an Apple Silicon, offline-capable Yaip disk image.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${YAIP_RELEASE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Yaip-release}"
DIST="$ROOT/dist"
MODE="${1:-candidate}"
ENTITLEMENTS="$ROOT/Config/Yaip.entitlements"

case "$MODE" in
    candidate|public) ;;
    *) echo "Use: $0 [candidate|public]" >&2; exit 2 ;;
esac

if [ "$MODE" = "public" ] && [ -z "${YAIP_DEVELOPMENT_TEAM:-}" ]; then
    echo "YAIP_DEVELOPMENT_TEAM is required for a signed public release." >&2
    exit 3
fi

development_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | grep -oE '"Apple Development:[^"]*"' \
        | head -1 | tr -d '"' || true
}

cd "$ROOT"
command -v xcodegen >/dev/null || { echo "xcodegen is required" >&2; exit 5; }
command -v create-dmg >/dev/null || { echo "create-dmg is required" >&2; exit 5; }

"$ROOT/Scripts/audit-public.sh"
xcodegen generate
xcodebuild -project Yaip.xcodeproj -scheme Yaip -configuration Release \
    -derivedDataPath "$DERIVED_DATA" clean

work="$(mktemp -d /tmp/yaip-release.XXXXXX)"
trap 'rm -rf "$work"' EXIT

if [ "$MODE" = "public" ]; then
    archive="$DERIVED_DATA/Yaip.xcarchive"
    export_dir="$DERIVED_DATA/DeveloperIDExport"
    export_options="$work/ExportOptions.plist"
    rm -rf "$archive" "$export_dir"
    cat > "$export_options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>${YAIP_DEVELOPMENT_TEAM}</string>
<key>destination</key><string>export</string>
</dict></plist>
EOF
    xcodebuild -project Yaip.xcodeproj -scheme Yaip -configuration Release \
        -destination 'generic/platform=macOS' -archivePath "$archive" \
        DEVELOPMENT_TEAM="$YAIP_DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic \
        -allowProvisioningUpdates archive
    xcodebuild -exportArchive -archivePath "$archive" \
        -exportPath "$export_dir" -exportOptionsPlist "$export_options" \
        -allowProvisioningUpdates
    build_app="$export_dir/Yaip.app"
else
    xcodebuild -project Yaip.xcodeproj -scheme Yaip -configuration Release \
        -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED_DATA" \
        ARCHS=arm64 ONLY_ACTIVE_ARCH=NO ENABLE_HARDENED_RUNTIME=YES build
    build_app="$DERIVED_DATA/Build/Products/Release/Yaip.app"
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$build_app/Contents/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$build_app/Contents/Info.plist")"
label="Yaip-${version}-apple-silicon"
[ "$MODE" = "candidate" ] && label="${label}-UNNOTARIZED"

app="$work/Yaip.app"
cp -R "$build_app" "$app"
python3 "$ROOT/Scripts/prepare-bundled-model.py" \
    --output "$app/Contents/Resources/Models/WhisperTiny"

cat > "$work/README.txt" <<EOF
Yaip ${version} (${build_number})

Requires macOS 14 or later and an Apple Silicon Mac.
Includes Whisper Tiny for offline transcription on first launch.

Install: drag Yaip to Applications, then open it.
Yaip will guide you through the permissions needed for global dictation.

Privacy: transcription runs locally. Dictation audio and history stay on this
Mac. Network access is used only when you choose to download a model.
EOF

xattr -cr "$app"
if [ "$MODE" = "public" ]; then
    model_archive="$DERIVED_DATA/Yaip-with-model.xcarchive"
    notarised_export="$work/NotarisedExport"
    rm -rf "$model_archive"
    cp -R "$archive" "$model_archive"
    rm -rf "$model_archive/Products/Applications/Yaip.app"
    cp -R "$app" "$model_archive/Products/Applications/"

    xcodebuild -exportArchive -archivePath "$model_archive" \
        -exportPath "$work/SignedModelExport" -exportOptionsPlist "$export_options" \
        -allowProvisioningUpdates

    upload_options="$work/UploadOptions.plist"
    cp "$export_options" "$upload_options"
    /usr/libexec/PlistBuddy -c 'Set :destination upload' "$upload_options"
    xcodebuild -exportArchive -archivePath "$model_archive" \
        -exportPath "$work/NotaryUpload" -exportOptionsPlist "$upload_options" \
        -allowProvisioningUpdates
    notarisation_attempt=1
    notarisation_attempts=20
    until xcodebuild -exportNotarizedApp -archivePath "$model_archive" \
        -exportPath "$notarised_export"; do
        if [ "$notarisation_attempt" -ge "$notarisation_attempts" ]; then
            echo "Notarised export was not ready after $notarisation_attempt attempts." >&2
            exit 7
        fi
        echo "Notarisation is still processing. Retrying in 15 seconds..."
        notarisation_attempt=$((notarisation_attempt + 1))
        sleep 15
    done
    rm -rf "$app"
    cp -R "$notarised_export/Yaip.app" "$app"
else
    identity="$(development_identity)"
    [ -n "$identity" ] || identity="-"
    codesign --force --sign "$identity" --options runtime --timestamp=none \
        --entitlements "$ENTITLEMENTS" "$app"
fi

codesign --verify --deep --strict --verbose=2 "$app"
file "$app/Contents/MacOS/Yaip" | grep -q 'arm64'
if strings "$app/Contents/MacOS/Yaip" | grep -Eq '/Users/[^/]+/'; then
    echo "Release executable contains a local user path." >&2
    exit 8
fi

fixture="$work/release-smoke.aiff"
say -v Karen -o "$fixture" "Yaip turns speech into text on this Mac."
arch -arm64 "$app/Contents/MacOS/Yaip" --verify-bundled-model "$fixture"

mkdir -p "$DIST"
rm -f "$DIST/${label}.dmg" "$DIST/${label}.sha256" "$DIST/${label}.json"
dmg_source="$work/dmg"
mkdir -p "$dmg_source"
cp -R "$app" "$dmg_source/"
create-dmg \
    --volname "Yaip ${version}" \
    --volicon "$app/Contents/Resources/AppIcon.icns" \
    --window-size 660 440 --icon-size 128 \
    --icon "Yaip.app" 180 210 --app-drop-link 480 210 \
    --add-file "Read Me.txt" "$work/README.txt" 330 355 \
    --hide-extension "Yaip.app" --format UDZO \
    "$DIST/${label}.dmg" "$dmg_source"

if [ "$MODE" = "public" ]; then
    xcrun stapler validate "$app"
    spctl -a -vv --type execute "$app"
fi

sha="$(shasum -a 256 "$DIST/${label}.dmg" | awk '{print $1}')"
printf '%s  %s\n' "$sha" "${label}.dmg" > "$DIST/${label}.sha256"
cat > "$DIST/${label}.json" <<EOF
{
  "name": "Yaip",
  "version": "${version}",
  "build": "${build_number}",
  "minimumMacOS": "14.0",
  "architectures": ["arm64"],
  "bundledModel": "OpenAI Whisper Tiny (WhisperKit Core ML)",
  "notarized": $([ "$MODE" = "public" ] && echo true || echo false),
  "sha256": "${sha}"
}
EOF

hdiutil verify "$DIST/${label}.dmg"
echo "Built $DIST/${label}.dmg"
if [ "$MODE" = "candidate" ]; then
    echo "Candidate builds are not for publication."
fi
