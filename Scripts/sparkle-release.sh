#!/bin/bash
#
#  Выпуск подписанного обновления BarX через Sparkle 2.
#
#  Что делает:
#    1) ставит версию в корневой Info.plist;
#    2) собирает Release (universal: arm64 + x86_64);
#    3) ad-hoc подписывает и ПРОВЕРЯЕТ подпись;
#    4) упаковывает .app в .dmg;
#    5) генерирует appcast.xml с EdDSA-подписью (ключ — из Связки ключей).
#
#  Использование:
#    Scripts/sparkle-release.sh <каталог-bin-Sparkle> <версия> [build]
#
#  Пример:
#    Scripts/sparkle-release.sh ~/BarX-Sparkle-keys/bin 1.5.5
#
#  ВАЖНО (для публичной раздачи):
#    Скрипт НЕ подписывает код сертификатом Apple (CODE_SIGNING_ALLOWED=NO +
#    ad-hoc). Для чужих Mac нужен Apple Developer: codesign сертификатом +
#    notarize. Sparkle проверяет EdDSA-подпись обновления, но НЕ заменяет notarization.
#
#  ВАЖНО (iCloud):
#    Проект на Рабочем столе синхронизируется через iCloud; File Provider
#    навешивает xattr на вложенный Sparkle.framework, из-за чего codesign
#    отказывается подписывать. Поэтому сборка/подпись/упаковка идут в /tmp.
#
set -euo pipefail

SPARKLE_BIN="${1:?Укажите каталог bin инструментов Sparkle (generate_appcast, sign_update)}"
VERSION="${2:?Укажите версию, например 1.5.5}"
ACCOUNT="${SPARKLE_ACCOUNT:-com.ilya.BarX}"

cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

WORK="$(mktemp -d /tmp/barx-release.XXXXXX)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo "==> Версия $VERSION в Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
# Sparkle сравнивает обновления по CFBundleVersion (сборке) — её тоже увеличиваем.
if [ -n "${3:-}" ]; then
  BUILD="$3"
else
  CUR_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist)
  BUILD=$((CUR_BUILD + 1))
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" Info.plist
echo "    short=$VERSION  build=$BUILD"

echo "==> Сборка Release (universal) в $WORK"
xcodebuild -project BarX.xcodeproj -scheme BarX -configuration Release \
  -derivedDataPath "$WORK/dd" -clonedSourcePackagesDirPath "$WORK/spm" \
  CODE_SIGNING_ALLOWED=NO ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build >/dev/null

APP="$WORK/dd/Build/Products/Release/BarX.app"

echo "==> ad-hoc подпись + проверка"
xattr -cr "$APP"
codesign --force --deep --sign - --identifier "com.ilya.BarX" "$APP"
codesign --verify --deep --strict "$APP"

STAGE="$WORK/release"
mkdir -p "$STAGE"

echo "==> Упаковка DMG"
DMG="$STAGE/BarX.dmg"
hdiutil create -volname "BarX" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

echo "==> Генерация appcast.xml (EdDSA)"
"$SPARKLE_BIN/generate_appcast" \
  --account "$ACCOUNT" \
  --download-url-prefix "https://github.com/Tudo5/BarX-updates/releases/download/v$VERSION/" \
  -o appcast.xml \
  "$STAGE"

# Копия DMG в проект для удобства (сам DMG подписывать не нужно)
mkdir -p build/release
cp "$DMG" build/release/BarX.dmg

echo
echo "Готово. DMG: build/release/BarX.dmg"
echo "  1) Загрузите build/release/BarX.dmg в релиз Tudo5/BarX-updates под тегом v$VERSION"
echo "  2) Положите appcast.xml в ветку main репозитория Tudo5/BarX-updates"
echo "  3) Проверьте обновление в старом приложении"
