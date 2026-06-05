#!/usr/bin/env bash
# Tek komutla sürüm çıkarır: versiyonu artırır, DMG üretir, /Applications'a kurar,
# git tag atar ve GitHub Release oluşturup DMG'yi asset olarak yükler.
#
# Kullanım:
#   ./scripts/release.sh patch     # 1.0.0 -> 1.0.1  (varsayılan)
#   ./scripts/release.sh minor     # 1.0.0 -> 1.1.0
#   ./scripts/release.sh major     # 1.0.0 -> 2.0.0
#   ./scripts/release.sh 1.2.3     # doğrudan bu versiyonu kullan
#
# Atlamak için ortam değişkenleri:
#   SKIP_INSTALL=1   /Applications'a kurmayı atla
#   SKIP_TAG=1       git tag atmayı atla
#   SKIP_GH=1        GitHub Release oluşturmayı atla
#   SKIP_COMMIT=1    versiyon bump'ını commit'lemeyi atla
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="Flowbar.xcodeproj"
APP_NAME="Flowbar"
PBXPROJ="$PROJECT/project.pbxproj"
DIST_DIR="$PWD/dist"

# --- Mevcut versiyonu oku ---
CURRENT=$(grep -m1 "MARKETING_VERSION" "$PBXPROJ" | sed 's/[^0-9.]//g')
[[ -z "$CURRENT" ]] && { echo "✗ MARKETING_VERSION okunamadı"; exit 1; }

# --- Yeni versiyonu hesapla ---
BUMP="${1:-patch}"
if [[ "$BUMP" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  NEW="$BUMP"
else
  IFS='.' read -r MA MI PA <<< "$CURRENT"
  # x.x veya tek haneli eski formatları da tolere et
  MA=${MA:-0}; MI=${MI:-0}; PA=${PA:-0}
  case "$BUMP" in
    major) MA=$((MA+1)); MI=0; PA=0 ;;
    minor) MI=$((MI+1)); PA=0 ;;
    patch) PA=$((PA+1)) ;;
    *) echo "✗ Geçersiz argüman: '$BUMP' (patch|minor|major|x.y.z)"; exit 1 ;;
  esac
  NEW="$MA.$MI.$PA"
fi

TAG="v$NEW"
echo "▸ Sürüm: $CURRENT → $NEW"

# --- Güvenlik kontrolleri ---
# Tag çakışmasını yalnızca gerçekten tag atacaksak engelle (local-only kurulumda atla).
if [[ "${SKIP_TAG:-0}" != "1" ]] && git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "✗ '$TAG' tag'i zaten var. Daha yüksek bir versiyon seç."; exit 1
fi

# --- pbxproj içindeki tüm MARKETING_VERSION'ları güncelle ---
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $NEW;/g" "$PBXPROJ"
# Build numarasını da artır (her sürümde tekil olsun diye)
NEXT_BUILD=$(($(date +%s)))
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $NEXT_BUILD;/g" "$PBXPROJ"

# --- DMG üret (make-dmg.sh'yi yeniden kullan) ---
echo "▸ DMG üretiliyor…"
REVEAL_DMG=0 ./scripts/make-dmg.sh

DMG_PATH="$DIST_DIR/$APP_NAME-$NEW.dmg"
[[ -f "$DMG_PATH" ]] || { echo "✗ Beklenen DMG bulunamadı: $DMG_PATH"; exit 1; }
echo "✓ DMG: $DMG_PATH"

# --- /Applications'a kur ---
if [[ "${SKIP_INSTALL:-0}" != "1" ]]; then
  echo "▸ /Applications'a kuruluyor…"
  WAS_RUNNING=0
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    WAS_RUNNING=1
    osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || pkill -x "$APP_NAME" || true
    sleep 1
  fi
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$PWD/build/export/$APP_NAME.app" "/Applications/$APP_NAME.app"
  # Kendi ürettiğimiz .app'te quarantine olmamalı ama garanti olsun
  xattr -dr com.apple.quarantine "/Applications/$APP_NAME.app" 2>/dev/null || true
  echo "✓ Kuruldu: /Applications/$APP_NAME.app"
  if [[ "$WAS_RUNNING" == "1" ]]; then
    open "/Applications/$APP_NAME.app"
    echo "✓ Yeniden başlatıldı"
  fi
fi

# --- Versiyon bump'ını commit'le ---
if [[ "${SKIP_COMMIT:-0}" != "1" ]]; then
  if [[ -n "$(git status --porcelain "$PBXPROJ")" ]]; then
    git add "$PBXPROJ"
    git commit -q -m "chore(release): bump version to $NEW" \
      -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
    echo "✓ Commit: version bump $NEW"
  fi
fi

# --- Git tag at ---
if [[ "${SKIP_TAG:-0}" != "1" ]]; then
  git tag -a "$TAG" -m "$APP_NAME $NEW"
  echo "✓ Tag: $TAG (push için: git push origin main --tags)"
fi

# --- GitHub Release oluştur ---
if [[ "${SKIP_GH:-0}" != "1" ]]; then
  if command -v gh >/dev/null 2>&1; then
    echo "▸ GitHub Release oluşturuluyor…"
    git push -q origin main 2>/dev/null || echo "  (uyarı: main push edilemedi, elle push gerekebilir)"
    git push -q origin "$TAG" 2>/dev/null || true
    gh release create "$TAG" "$DMG_PATH" \
      --title "$APP_NAME $NEW" \
      --notes "Automated release. Download the DMG and drag Flowbar.app into /Applications." \
      && echo "✓ GitHub Release: $TAG" \
      || echo "✗ GitHub Release oluşturulamadı (gh auth login? remote?)"
  else
    echo "⚠ gh CLI yok, GitHub Release atlandı. (brew install gh)"
  fi
fi

echo
echo "🎉 $APP_NAME $NEW yayında."
