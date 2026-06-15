#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SAVER_NAME="BauhausClock"
SAVER_PATH="$BUILD_DIR/$SAVER_NAME.saver"
SDK_PATH="$(xcrun --show-sdk-path)"

echo "═══════════════════════════════════════════════"
echo "  Building Bauhaus Clock Screensaver (Native)"
echo "═══════════════════════════════════════════════"

# ── Step 1: Create .saver bundle structure ──
echo ""
echo "→ Step 1: Assembling .saver bundle..."
rm -rf "$SAVER_PATH"
mkdir -p "$SAVER_PATH/Contents/MacOS"
mkdir -p "$SAVER_PATH/Contents/Resources"

# Copy Info.plist
cp "$PROJECT_DIR/BauhausClock/Info.plist" "$SAVER_PATH/Contents/Info.plist"

# ── Step 2: Compile Swift → bundle binary ──
echo ""
echo "→ Step 2: Compiling Swift..."

SWIFT_FILES=(
  "$PROJECT_DIR/BauhausClock/Palettes.swift"
  "$PROJECT_DIR/BauhausClock/ClockRenderer.swift"
  "$PROJECT_DIR/BauhausClock/ConfigureSheetController.swift"
  "$PROJECT_DIR/BauhausClock/ClockScreenSaverView.swift"
)

swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macos13.0 \
  -emit-library \
  -module-name "$SAVER_NAME" \
  -o "$SAVER_PATH/Contents/MacOS/$SAVER_NAME" \
  -Xlinker -bundle \
  -Xlinker -rpath -Xlinker @loader_path/Frameworks \
  -framework ScreenSaver \
  -framework AppKit \
  -framework CoreText \
  -O \
  "${SWIFT_FILES[@]}"

# Verify binary type
FILE_TYPE=$(file "$SAVER_PATH/Contents/MacOS/$SAVER_NAME")
echo "  $FILE_TYPE"

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Build successful!"
echo "  Output: $SAVER_PATH"
echo ""
echo "  To install:"
echo "    open \"$SAVER_PATH\""
echo ""
echo "  Or copy manually:"
echo "    cp -R \"$SAVER_PATH\" ~/Library/Screen\\ Savers/"
echo "═══════════════════════════════════════════════"
