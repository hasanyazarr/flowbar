#!/usr/bin/env bash
# Geliştirme döngüsü: derle, eski sürümü kapat, yenisini başlat.
# Kullanım: ./scripts/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="Flowbar"
CONFIG="Debug"

echo "▸ Derleniyor ($CONFIG)…"
xcodebuild -project Flowbar.xcodeproj -scheme "$SCHEME" \
  -configuration "$CONFIG" -destination 'platform=macOS' build \
  | tail -3

APP=$(find "$HOME/Library/Developer/Xcode/DerivedData/Flowbar-"*/Build/Products/"$CONFIG" \
  -maxdepth 1 -name "Flowbar.app" 2>/dev/null | head -1)

if [[ -z "${APP:-}" ]]; then
  echo "✗ Derlenmiş .app bulunamadı" >&2
  exit 1
fi

echo "▸ Çalışan sürüm kapatılıyor…"
pkill -x Flowbar 2>/dev/null || true
sleep 0.4

echo "▸ Başlatılıyor: $APP"
open "$APP"
echo "✓ Menubar'da ⏱ ikonuna bak."
