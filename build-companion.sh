#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="BauhausClock"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
SDK_PATH="$(xcrun --show-sdk-path)"

echo "═══════════════════════════════════════════════"
echo "  Building Bauhaus Clock Companion App"
echo "═══════════════════════════════════════════════"

# ── Step 1: Create .app bundle structure ──
echo ""
echo "→ Step 1: Assembling .app bundle..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$PROJECT_DIR/CompanionApp/Info.plist" "$APP_PATH/Contents/Info.plist"

# ── Step 2: Compile Swift → app binary ──
echo ""
echo "→ Step 2: Compiling Swift..."

SWIFT_FILES=(
  "$PROJECT_DIR/BauhausClock/Palettes.swift"
  "$PROJECT_DIR/BauhausClock/ClockRenderer.swift"
  "$PROJECT_DIR/CompanionApp/SettingsViewModel.swift"
  "$PROJECT_DIR/CompanionApp/SettingsView.swift"
  "$PROJECT_DIR/CompanionApp/BauhausClockApp.swift"
)

swiftc \
  -parse-as-library \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macos13.0 \
  -o "$APP_PATH/Contents/MacOS/$APP_NAME" \
  -framework AppKit \
  -framework SwiftUI \
  -framework CoreText \
  -framework ScreenSaver \
  -O \
  "${SWIFT_FILES[@]}"

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Build successful!"
echo "  Output: $APP_PATH"
echo ""
echo "  To run:"
echo "    open \"$APP_PATH\""
echo ""
echo "  Or directly:"
echo "    \"$APP_PATH/Contents/MacOS/$APP_NAME\""
echo "═══════════════════════════════════════════════"
