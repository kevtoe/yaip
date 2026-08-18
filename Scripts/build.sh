#!/bin/bash
# Build, test, run and package Yaip.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${YAIP_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Yaip-build}"
SCHEME="Yaip"
DESTINATION="platform=macOS,arch=arm64"

cd "$ROOT"
command -v xcodegen >/dev/null 2>&1 || {
    echo "xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
}
xcodegen generate

build() {
    xcodebuild -project Yaip.xcodeproj -scheme "$SCHEME" \
        -configuration "$1" -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" "${@:2}"
}

stable_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | grep -oE '"(Apple Development|Developer ID Application)[^"]*"' \
        | head -1 | tr -d '"' || true
}

resign() {
    local app="$1"
    [ -d "$app" ] || return 0
    local identity
    identity=$(stable_identity)
    if [ -z "$identity" ]; then
        echo "No development certificate found. The app remains ad-hoc signed." >&2
        return 0
    fi
    xattr -cr "$app"
    codesign --force --deep --sign "$identity" --timestamp=none "$app"
    echo "Signed local build with an available development identity."
}

verify_public_boundary() {
    "$ROOT/Scripts/audit-public.sh"
    build Release clean
    build Release build
    local app="$DERIVED_DATA/Build/Products/Release/Yaip.app"
    codesign --verify --deep --strict "$app"
    file "$app/Contents/MacOS/Yaip" | grep -q 'arm64'
    if strings "$app/Contents/MacOS/Yaip" | grep -Eq '/Users/[^/]+/'; then
        echo "Release executable contains a local user path." >&2
        exit 8
    fi
    echo "Public source and release boundary verified."
}

case "${1:-build}" in
    build)
        build Debug build
        resign "$DERIVED_DATA/Build/Products/Debug/Yaip.app"
        ;;
    test)
        build Debug test
        ;;
    integration)
        fixture="$DERIVED_DATA/sample.aiff"
        mkdir -p "$DERIVED_DATA"
        say -v Karen -o "$fixture" \
            "The quick brown fox jumps over the lazy dog. Yaip is a local transcription app for the Mac."
        TEST_RUNNER_YAIP_INTEGRATION=1 \
        TEST_RUNNER_YAIP_SAMPLE_AUDIO="$fixture" \
        TEST_RUNNER_YAIP_LOCAL_WHISPER_MODEL="$HOME/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-tiny" \
        TEST_RUNNER_YAIP_LOCAL_WHISPER_TOKENIZER="$HOME/Documents/huggingface/models/openai/whisper-tiny" \
        TEST_RUNNER_YAIP_LOCAL_PARAKEET_MODEL="$HOME/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3" \
            build Debug test
        ;;
    run)
        build Debug build
        resign "$DERIVED_DATA/Build/Products/Debug/Yaip.app"
        pkill -f "Yaip.app/Contents/MacOS/Yaip" 2>/dev/null || true
        open "$DERIVED_DATA/Build/Products/Debug/Yaip.app"
        ;;
    install)
        build Release build
        app="$DERIVED_DATA/Build/Products/Release/Yaip.app"
        destination="$HOME/Applications/Yaip.app"
        mkdir -p "$HOME/Applications"
        rm -rf "$destination"
        cp -R "$app" "$destination"
        resign "$destination"
        codesign --verify --deep --strict "$destination"
        open "$destination"
        ;;
    verify-public-boundary)
        verify_public_boundary
        ;;
    release)
        "$ROOT/Scripts/release.sh" candidate
        ;;
    public-release)
        "$ROOT/Scripts/release.sh" public
        ;;
    *)
        echo "Use: build | test | integration | run | install | verify-public-boundary | release | public-release" >&2
        exit 1
        ;;
esac
