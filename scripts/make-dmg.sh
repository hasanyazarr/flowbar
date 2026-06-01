#!/usr/bin/env bash
# Paylaşılabilir .dmg üretir: Release derler, .app'i ayıklar, sürükle-bırak'lı disk imajı oluşturur.
# Kullanım: ./scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="Flowbar.xcodeproj"
SCHEME="Flowbar"
APP_NAME="Flowbar"
BUILD_DIR="$PWD/build"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DIST_DIR="$PWD/dist"

VERSION=$(grep -m1 "MARKETING_VERSION" "$PROJECT/project.pbxproj" | sed 's/[^0-9.]//g')
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_DIR" "$DIST_DIR"

echo "▸ Release arşivleniyor (v$VERSION)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration Release -destination 'platform=macOS' \
  -archivePath "$ARCHIVE" archive \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  | tail -3

# Arşivden .app'i kopyala (App Store dışı dağıtım için manuel ayıklama yeterli).
cp -R "$ARCHIVE/Products/Applications/$APP_NAME.app" "$EXPORT_DIR/"

# Ad-hoc imzala (imzasız .app Gatekeeper'da daha sorunlu).
codesign --force --deep --sign - "$EXPORT_DIR/$APP_NAME.app"

echo "▸ DMG hazırlanıyor…"
STAGE=$(mktemp -d)
cp -R "$EXPORT_DIR/$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$STAGE"

echo "✓ Oluşturuldu: $DMG_PATH"
# Sadece doğrudan çalıştırıldığında Finder'da göster; release.sh içinden çağrılınca atla.
if [[ "${REVEAL_DMG:-1}" == "1" ]]; then
  open -R "$DMG_PATH"
fi
