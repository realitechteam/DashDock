#!/bin/bash
# DashDock Release Script
# Generates a signed release with Sparkle auto-update support
#
# Prerequisites:
#   1. Generate EdDSA keypair (one-time): ./scripts/release.sh generate-keys
#   2. Build and release: ./scripts/release.sh build <version>
#
# The appcast.xml must be hosted at: https://realitech.dev/dashdock/appcast.xml
# The .dmg files must be hosted at: https://realitech.dev/dashdock/releases/

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="$PROJECT_ROOT/releases"
SPARKLE_BIN=""

# Find Sparkle tools from SPM build
find_sparkle_tools() {
    local derived_data="$HOME/Library/Developer/Xcode/DerivedData"
    SPARKLE_BIN=$(find "$derived_data" -name "generate_keys" -path "*/Sparkle/bin/*" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)

    if [ -z "$SPARKLE_BIN" ]; then
        echo "Sparkle tools not found. Build the project in Xcode first to download the SPM package."
        echo "Then re-run this script."
        exit 1
    fi
}

generate_keys() {
    find_sparkle_tools
    echo "Generating EdDSA keypair for Sparkle..."
    echo ""
    echo "IMPORTANT: This generates a private key stored in your Keychain."
    echo "The public key will be printed below — add it to Config.xcconfig as SPARKLE_ED_PUBLIC_KEY"
    echo ""
    "$SPARKLE_BIN/generate_keys"
}

build_release() {
    local VERSION=$1

    echo "Building DashDock v$VERSION..."

    # Update version in Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PROJECT_ROOT/DashDock/Resources/Info.plist"

    # Increment build number
    local CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PROJECT_ROOT/DashDock/Resources/Info.plist")
    local NEW_BUILD=$((CURRENT_BUILD + 1))
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PROJECT_ROOT/DashDock/Resources/Info.plist"

    echo "Version: $VERSION (build $NEW_BUILD)"

    # Generate project
    cd "$PROJECT_ROOT"
    xcodegen generate 2>&1

    # Build release
    xcodebuild -project DashDock.xcodeproj \
        -scheme DashDock \
        -configuration Release \
        build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
        2>&1 | grep -E "(error:|BUILD|SUCCEEDED|FAILED)" | tail -5

    # Create release directory
    mkdir -p "$RELEASE_DIR"

    # Create DMG
    local DMG_NAME="DashDock-v${VERSION}.dmg"
    local DMG_PATH="$RELEASE_DIR/$DMG_NAME"
    local STAGING="/tmp/DashDock-release-staging"

    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    cp -R "$BUILD_DIR/DashDock.app" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"

    hdiutil create \
        -volname "DashDock v$VERSION" \
        -srcfolder "$STAGING" \
        -ov \
        -format UDZO \
        "$DMG_PATH" 2>&1

    rm -rf "$STAGING"

    echo ""
    echo "DMG created: $DMG_PATH"
    echo "Size: $(du -h "$DMG_PATH" | cut -f1)"

    # Sign the DMG with Sparkle EdDSA
    find_sparkle_tools
    echo ""
    echo "Signing DMG with EdDSA..."
    local SIGN_OUTPUT=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" 2>&1)
    local SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*\(sparkle:edSignature="[^"]*"\).*/\1/p')
    if [ -z "$SIGNATURE" ]; then
        echo "Failed to parse Sparkle signature output: $SIGN_OUTPUT"
        exit 1
    fi
    echo "Signature: $SIGNATURE"

    local DMG_SIZE=$(stat -f%z "$DMG_PATH")

    # Generate appcast entry
    cat > "$RELEASE_DIR/appcast-entry-v${VERSION}.xml" << EOF
        <item>
            <title>Version $VERSION</title>
            <sparkle:version>$NEW_BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>DashDock v$VERSION</h2>
                <ul>
                    <li>Update description here</li>
                </ul>
            ]]></description>
            <pubDate>$(date -R)</pubDate>
            <enclosure
                url="https://realitech.dev/dashdock/releases/$DMG_NAME"
                $SIGNATURE
                length="$DMG_SIZE"
                type="application/octet-stream" />
        </item>
EOF

    echo ""
    echo "============================================"
    echo "Release v$VERSION ready!"
    echo "============================================"
    echo ""
    echo "Files:"
    echo "  DMG: $DMG_PATH"
    echo "  Appcast entry: $RELEASE_DIR/appcast-entry-v${VERSION}.xml"
    echo ""
    echo "Next steps:"
    echo "  1. Edit $RELEASE_DIR/appcast-entry-v${VERSION}.xml to add release notes"
    echo "  2. Upload DMG to https://realitech.dev/dashdock/releases/"
    echo "  3. Insert the <item> entry into appcast.xml"
    echo "  4. Upload appcast.xml to https://realitech.dev/dashdock/appcast.xml"
}

# Main
case "${1:-help}" in
    generate-keys)
        generate_keys
        ;;
    build)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 build <version>"
            echo "Example: $0 build 1.1.0"
            exit 1
        fi
        build_release "$2"
        ;;
    *)
        echo "DashDock Release Script"
        echo ""
        echo "Usage:"
        echo "  $0 generate-keys    Generate EdDSA keypair (one-time setup)"
        echo "  $0 build <version>  Build release DMG and sign for Sparkle"
        echo ""
        echo "Example:"
        echo "  $0 generate-keys"
        echo "  $0 build 1.1.0"
        ;;
esac
