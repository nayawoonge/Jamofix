#!/bin/bash
# JamoFix.app 번들 + 배포용 DMG 생성 (Xcode 불필요)
# 사용: Scripts/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="JamoFix"
VERSION="0.2.1"
BUNDLE_ID="dev.jamofix.app"
DIST="dist"
APP_DIR="$DIST/$APP.app"

echo "▸ 릴리즈 빌드..."
swift build -c release

echo "▸ 앱 번들 구성..."
rm -rf "$DIST"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/$APP" "$APP_DIR/Contents/MacOS/$APP"

# 아이콘 (없으면 생성)
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "▸ 아이콘 생성..."
    mkdir -p Resources
    swift Scripts/make-icon.swift Resources
fi
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>       <string>$APP</string>
    <key>CFBundleIdentifier</key>       <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>             <string>$APP</string>
    <key>CFBundleDisplayName</key>      <string>$APP</string>
    <key>CFBundleDevelopmentRegion</key> <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ko</string>
    </array>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>          <string>$VERSION</string>
    <key>CFBundleIconFile</key>         <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>NSHighResolutionCapable</key>  <true/>
    <key>LSApplicationCategoryType</key> <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key> <string>© 2026 JamoFix</string>
</dict>
</plist>
PLIST

echo "▸ ad-hoc 서명..."
codesign --force --deep --sign - "$APP_DIR"

echo "▸ DMG 생성..."
STAGING="$DIST/dmg-staging"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP" -srcfolder "$STAGING" -ov -format UDZO \
    "$DIST/$APP-$VERSION.dmg" >/dev/null
rm -rf "$STAGING"

echo ""
echo "완료:"
echo "  앱  → $APP_DIR"
echo "  DMG → $DIST/$APP-$VERSION.dmg"
echo ""
echo "설치: DMG를 열고 $APP.app을 Applications로 드래그"
echo "주의: ad-hoc 서명이라 다른 맥에서는 우클릭→열기(또는 quarantine 해제)가 필요합니다."
