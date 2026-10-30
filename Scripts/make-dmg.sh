#!/bin/bash
#
# make-dmg.sh — сборка красиво оформленного DMG для BarX.
#
# Что делает:
#   1. собирает Release-версию приложения;
#   2. подписывает её ad-hoc (локальный запуск без сертификата);
#   3. создаёт образ с фоном, стрелкой и раскладкой иконок;
#   4. кладёт готовый .dmg на Рабочий стол.
#
# Запуск:  bash Scripts/make-dmg.sh
#
# Требуется: Xcode (xcodebuild) и доступ к Finder для раскладки.
# Если macOS спросит «Терминал запрашивает доступ к Finder» — разрешите:
# без этого фон и позиции иконок возьмутся из Scripts/dmg/layout.dsstore.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="BarX"                      # имя .app и тома
BUNDLE_ID="com.ilya.BarX"
VOL_NAME="BarX"                      # уточняется версией ниже
TITLE_SUFFIX="(Global Update)"       # подпись в имени файла
ICON_SRC="Assets.xcassets/AppIcon.appiconset/BarX_1024x1024.png"
BG_SRC="Scripts/dmg/background.png"
LAYOUT_SRC="Scripts/dmg/layout.dsstore"

WORK="$(mktemp -d /tmp/barx-dmg.XXXXXX)"
STAGE="$WORK/stage"
RW="$WORK/rw.dmg"

cleanup() {
  [ -d "/Volumes/$VOL_NAME" ] && hdiutil detach "/Volumes/$VOL_NAME" -force >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

say() { printf '\033[1;35m▸\033[0m %s\n' "$1"; }

# --- 1. сборка ---------------------------------------------------------------
if [ ! -d /Applications/Xcode.app ]; then
  echo "Не найден Xcode в /Applications — установите его или соберите .app вручную." >&2
  exit 1
fi
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

say "Собираю Release-версию…"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath "$WORK/dd" CODE_SIGNING_ALLOWED=NO build >"$WORK/build.log" 2>&1 \
  || { echo "Сборка не удалась, подробности: $WORK/build.log" >&2; tail -20 "$WORK/build.log"; exit 1; }

BUILT_APP="$WORK/dd/Build/Products/Release/$APP_NAME.app"
[ -d "$BUILT_APP" ] || { echo "Не найден собранный $APP_NAME.app" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUILT_APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUILT_APP/Contents/Info.plist")"
VOL_NAME="$APP_NAME $VERSION"

say "Версия: $VERSION (build $BUILD)"

# --- 2. подпись --------------------------------------------------------------
say "Подписываю ad-hoc…"
xattr -cr "$BUILT_APP"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$BUILT_APP" >/dev/null 2>&1 \
  || say "предупреждение: подпись не удалась, приложение всё равно попадёт в образ"

# --- 3. содержимое тома ------------------------------------------------------
say "Готовлю содержимое тома…"
mkdir -p "$STAGE/.background"
cp -R "$BUILT_APP" "$STAGE/"
ln -sf /Applications "$STAGE/Applications"
# важно: Finder рисует фон 1 пиксель = 1 точка, поэтому 1x-версия
# должна быть ровно размером окна (660x420), а @2x — вдвое больше для Retina
if [ -f "$BG_SRC" ]; then
  cp "$BG_SRC" "$STAGE/.background/background.png"
  BG2X="${BG_SRC%.png}@2x.png"
  [ -f "$BG2X" ] && cp "$BG2X" "$STAGE/.background/background@2x.png" \
    && say "фон: 1x $(sips -g pixelWidth "$BG_SRC" | awk '/pixelWidth/{print $2}')px + @2x"
else
  say "фон не найден: $BG_SRC"
fi

# готовая раскладка (фон + позиции иконок) — запасной вариант,
# если Finder-автоматизация недоступна
[ -f "$LAYOUT_SRC" ] && cp "$LAYOUT_SRC" "$STAGE/.DS_Store"

# иконка тома из иконки приложения
if [ -f "$ICON_SRC" ]; then
  ICONSET="$WORK/icon.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 64 128 256 512; do
    sips -z "$s" "$s" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null 2>&1 || true
    d=$((s * 2))
    sips -z "$d" "$d" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null 2>&1 || true
  done
  iconutil -c icns "$ICONSET" -o "$WORK/VolumeIcon.icns" >/dev/null 2>&1 \
    && say "иконка тома готова" || say "иконку тома собрать не удалось (не критично)"
fi

# --- 4. образ (RW) и раскладка ----------------------------------------------
say "Создаю образ…"
hdiutil create -srcfolder "$STAGE" -volname "$VOL_NAME" -fs HFS+ -format UDRW -ov "$WORK/rw" >/dev/null

say "Монтирую для раскладки…"
hdiutil attach "$RW" -nobrowse -noautoopen >/dev/null
sleep 2
MOUNT="/Volumes/$VOL_NAME"

apply_layout() {
  osascript <<APPLESCRIPT >/dev/null 2>&1
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {240, 160, 900, 580}
    set vo to the icon view options of container window
    set arrangement of vo to not arranged
    set icon size of vo to 128
    set text size of vo to 13
    set background picture of vo to file ".background:background.png"
    set position of item "$APP_NAME.app" of container window to {165, 198}
    set position of item "Applications" of container window to {495, 198}
    update without registering applications
  end tell
end tell
APPLESCRIPT
}

if [ -d "$MOUNT" ] && apply_layout; then
  say "Раскладка применена (фон, позиции иконок, размер окна)"
else
  say "Finder недоступен — использую готовую раскладку из $LAYOUT_SRC"
fi

# иконку тома кладём ПОСЛЕ раскладки: Finder «съедает» её при открытии
[ -f "$WORK/VolumeIcon.icns" ] && cp "$WORK/VolumeIcon.icns" "$MOUNT/.VolumeIcon.icns" 2>/dev/null || true
[ -d "$MOUNT/.background" ] && SetFile -a V "$MOUNT/.background" 2>/dev/null || true
SetFile -a C "$MOUNT" 2>/dev/null || true
osascript -e "tell application \"Finder\" to close window of disk \"$VOL_NAME\"" >/dev/null 2>&1 || true
sync
sleep 3

say "Размонтирую…"
hdiutil detach "$MOUNT" >/dev/null 2>&1 || { sleep 4; hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true; }

# --- 5. сжатие и проверка ----------------------------------------------------
say "Сжимаю…"
FINAL="$WORK/$APP_NAME $VERSION $TITLE_SUFFIX.dmg"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$WORK/out" >/dev/null
CONVERTED="$WORK/out.dmg"
[ -f "$CONVERTED" ] || { echo "не удалось сжать образ" >&2; exit 1; }
mv "$CONVERTED" "$FINAL"

say "Проверяю раскладку…"
# В сжатом (UDZO) образе данные заархивированы, поэтому побайтовый поиск
# .DS_Store даёт ложный минус. Проверяем на несжатом RW-образе, а если
# удаётся — монтируем готовый файл и читаем .DS_Store как обычный файл.
python3 - "$RW" <<'PY' || true
import sys
raw = open(sys.argv[1], 'rb').read()
off = raw.find(b'\x00\x00\x00\x01Bud1')
if off < 0:
    print('   .DS_Store не найден — раскладка не сохранилась')
    raise SystemExit
blob = raw[off:off + 16384]
has_bg = b'background' in blob
has_pos = (165).to_bytes(4, 'big') in blob and (495).to_bytes(4, 'big') in blob
print(f"   фон: {'есть' if has_bg else 'НЕТ'} | позиции иконок: {'есть' if has_pos else 'НЕТ'}")
PY

VERIFY_MNT="$WORK/verify"
mkdir -p "$VERIFY_MNT"
if hdiutil attach "$FINAL" -nobrowse -readonly -mountpoint "$VERIFY_MNT" >/dev/null 2>&1; then
  python3 - "$VERIFY_MNT/.DS_Store" <<'PY' || true
import os, sys
p = sys.argv[1]
if not os.path.exists(p):
    print('   в готовом образе .DS_Store нет')
    raise SystemExit
d = open(p, 'rb').read()
has_bg = b'background' in d
has_pos = (165).to_bytes(4, 'big') in d and (495).to_bytes(4, 'big') in d
print(f"   в готовом образе: фон {'есть' if has_bg else 'НЕТ'} | "
      f"позиции {'есть' if has_pos else 'НЕТ'} | .DS_Store {len(d)} б")
PY
  [ -f "$VERIFY_MNT/.background/background.png" ] && echo "   файл фона на месте" || echo "   файла фона нет"
  hdiutil detach "$VERIFY_MNT" >/dev/null 2>&1 || hdiutil detach "$VERIFY_MNT" -force >/dev/null 2>&1 || true
fi

# --- 6. результат ------------------------------------------------------------
DEST="$HOME/Desktop/$(basename "$FINAL")"
cp "$FINAL" "$DEST"
say "Готово: $DEST"
ls -lh "$DEST"
echo
echo "Запуск: откройте образ, перетащите BarX в «Программы»."
echo "Если macOS скажет «разработчик не подтверждён» — правый клик по BarX → «Открыть»."
