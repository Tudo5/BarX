# BarX — как выпускать обновления (пошагово)

Обновления работают через **Sparkle 2**. Приложение читает `appcast.xml`, видит новую
версию, скачивает `.dmg`, проверяет **EdDSA-подпись** и ставит её само.

## Архитектура: два репозитория

| Репозиторий | Видимость | Что внутри |
|---|---|---|
| `Tudo5/BarX` | **можно сделать приватным** | Исходный код проекта |
| `Tudo5/BarX-updates` | **публичный** | Только `appcast.xml` + `.dmg` (файлы обновлений) |

Приложение берёт фид отсюда:
`https://raw.githubusercontent.com/Tudo5/BarX-updates/main/appcast.xml`

Так исходники скрыты, а авто-обновления работают у всех.

---

## 0. Что настроено один раз

- **Инструменты Sparkle**: `~/BarX-Sparkle-keys/bin/`
- **Приватный ключ**: Связка ключей, аккаунт **`com.ilya.BarX`**;
  бэкап `~/BarX-Sparkle-keys/ed25519-private.key` (не терять, не коммитить).
- **Публичный ключ** — в `Info.plist` (`SUPublicEDKey`).
- **Фид** — в `Tudo5/BarX-updates` (публичный репозиторий).
- Проект на диске: `~/Desktop/BarX`.

Проверка ключа:
```bash
~/BarX-Sparkle-keys/bin/generate_keys --account com.ilya.BarX -p
```

---

## 1. Выпуск новой версии (пример: 1.5.6)

### Шаг 1. Собрать подписанный universal-релиз
```bash
cd ~/Desktop/BarX
Scripts/sparkle-release.sh ~/BarX-Sparkle-keys/bin 1.5.6
```
Скрипт: ставит версию, увеличивает build, собирает **universal (arm64+x86_64)**
в `/tmp` (вне iCloud), ad-hoc подписывает и **проверяет** подпись, делает
`build/release/BarX.dmg`, генерирует `appcast.xml` со ссылкой на `BarX-updates`.

Проверка:
```bash
ls -lh build/release/BarX.dmg
grep -E "sparkle:version|shortVersionString|enclosure" appcast.xml
```

### Шаг 2. Создать релиз в `BarX-updates` и загрузить DMG
1. https://github.com/Tudo5/BarX-updates/releases/new
2. **Tag:** `v1.5.6` (ровно `v` + версия)
3. **Title:** `BarX 1.5.6`, **Description:** что нового
4. **Attach:** `build/release/BarX.dmg` — имя не менять (**`BarX.dmg`**)
5. **Publish release**

### Шаг 3. Положить `appcast.xml` в `BarX-updates/main`
- Открой https://github.com/Tudo5/BarX-updates/blob/main/appcast.xml
- Карандаш (Edit) → вставь новое содержимое локального `appcast.xml` → **Commit changes**
  (или замени файл через «Add file → Upload files»).

### Шаг 4. Проверить
```bash
curl -s https://raw.githubusercontent.com/Tudo5/BarX-updates/main/appcast.xml | grep -E "sparkle:version|shortVersionString"
curl -sIL https://github.com/Tudo5/BarX-updates/releases/download/v1.5.6/BarX.dmg | grep -iE "^HTTP/|content-length"
```
На старом приложении: меню → «Проверить обновления» → окно Sparkle → «Установить и перезапустить».

---

## 2. Правила

1. **Порядок:** сначала `.dmg` в релиз `BarX-updates`, **потом** `appcast.xml`. Иначе 404.
2. **Версия и build растут** (build скрипт поднимает сам).
3. **Тег = `v<версия>`**, файл = **`BarX.dmg`**.
4. **`appcast.xml` руками не редактируй** — его генерирует `generate_appcast`.
5. **Приватный ключ не коммить и не терять.**
6. **Собирать только в `/tmp`** (Desktop синхронизируется iCloud → xattr ломают подпись; скрипт уже так делает).

---

## 3. Быстрый чек-лист

```
[ ] cd ~/Desktop/BarX
[ ] Scripts/sparkle-release.sh ~/BarX-Sparkle-keys/bin <версия>
[ ] BarX-updates → Releases → New → tag v<версия> → прикрепить BarX.dmg → Publish
[ ] BarX-updates → appcast.xml → Edit → вставить новый appcast → Commit
[ ] curl проверить фид и dmg (HTTP 200)
[ ] Проверить обновление в старом приложении
```

---

## 4. Частые ошибки

| Симптом | Решение |
|---|---|
| `not a git repository` | `cd ~/Desktop/BarX` |
| `resource fork / Finder detritus not allowed` | Сборка попала в iCloud-папку. Используй актуальный `sparkle-release.sh` (собирает в `/tmp`). |
| `No usable archives found` | Подпись не удалась — смотри вывод `codesign` в скрипте. |
| `Signing key not found for account ed25519` | Скрипт передаёт `--account com.ilya.BarX`; при ручном запуске добавь этот флаг. |
| Обновление 404 | Тег/имя файла не совпали, или dmg ещё не загружен, или appcast не обновлён. |

---

## 5. Сделать исходники приватными (когда захочешь)
1. https://github.com/Tudo5/BarX/settings → **Danger Zone**
2. **Change repository visibility** → **Make private** → подтвердить.
Авто-обновления продолжат работать (они идут через публичный `BarX-updates`).

---

## 6. Что пока НЕ настроено (для публичной раздачи людям)

- **Подпись Apple + нотаризация** (Apple Developer, $99/год): без этого у чужих людей
  Gatekeeper покажет «разработчик не подтверждён». Sparkle-подпись (EdDSA) это **не** заменяет.

> ✅ **Universal-сборка включена** (arm64 + x86_64). Проверка:
> `lipo -info build/Build/Products/Release/BarX.app/Contents/MacOS/BarX` → `x86_64 arm64`.
