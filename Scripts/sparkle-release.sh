#!/bin/bash
#
#  Выпуск подписанного обновления BarX через Sparkle 2.
#
#  Что делает:
#    1) ставит версию в корневой Info.plist;
#    2) собирает Release;
#    3) упаковывает .app в .dmg;
#    4) генерирует appcast.xml с EdDSA-подписью (ключ — из Связки ключей).
#
#  Использование:
#    Scripts/sparkle-release.sh <каталог-bin-Sparkle> <версия>
#
#  Пример:
#    Scripts/sparkle-release.sh /tmp/sparkle-dist/bin 1.5.2
#
#  ВАЖНО (для публичной раздачи):
#    Скрипт НЕ подписывает код (CODE_SIGNING_ALLOWED=NO). Для чужих Mac
#    нужен Apple Developer: codesign всех бинарей + notarize. Sparkle
#    проверяет EdDSA-подпись обновления, но НЕ заменяет notarization.
#
set -euo pipefail

SPARKLE_BIN="${1:?Укажите каталог bin инструментов Sparkle (generate_appcast, sign_update)}"
VERSION="${2:?Укажите версию, например 1.5.2}"
ACCOUNT="${SPARKLE_ACCOUNT:-com.ilya.BarX}"

cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

echo "==> Версия $VERSION в Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist

echo "==> Сборка Release"
xcodebuild -project BarX.xcodeproj -scheme BarX -configuration Release \
  -derivedDataPath build -clonedSourcePackagesDirPath build/SourcePackages \
  CODE_SIGNING_ALLOWED=NO build >/dev/null

APP="build/Build/Products/Release/BarX.app"
STAGE="build/release"
rm -rf "$STAGE" && mkdir -p "$STAGE"

echo "==> Упаковка DMG"
DMG="$STAGE/BarX.dmg"
rm -f "$DMG"
hdiutil create -volname "BarX" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

echo "==> Генерация appcast.xml (EdDSA)"
"$SPARKLE_BIN/generate_appcast" \
  --account "$ACCOUNT" \
  --download-url-prefix "https://github.com/Tudo5/BarX/releases/download/v$VERSION/" \
  -o appcast.xml \
  "$STAGE"

echo
echo "Готово."
echo "  1) Загрузите  $DMG  в GitHub Releases под тегом  v$VERSION"
echo "  2) Закоммитьте  appcast.xml  в ветку main и запушьте"
echo "  3) Проверьте обновление: старое приложение → «Проверить обновления»"
