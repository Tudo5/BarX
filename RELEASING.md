# BarX — как выпускать обновления (пошагово)

Обновления работают через **Sparkle 2**: приложение читает `appcast.xml`, видит новую
версию, скачивает `.dmg`, проверяет **EdDSA-подпись** и ставит её сам.

Этот документ — для самостоятельного выпуска. Всё можно сделать без посторонней помощи.

---

## 0. Что должно быть настроено один раз (уже настроено)

- **Инструменты Sparkle**: `~/BarX-Sparkle-keys/bin/` (`generate_appcast`, `sign_update`, `BinaryDelta`).
- **Приватный ключ** — в Связке ключей, учётная запись **`com.ilya.BarX`**
  (тип «private key», имя «Private key for signing Sparkle updates»).
  Бэкап: `~/BarX-Sparkle-keys/ed25519-private.key` — **храни его, не теряй и не коммить**.
- **Публичный ключ** вшит в `Info.plist` (`SUPublicEDKey`).
- **`appcast.xml`** лежит в ветке `main`; приложение берёт его по адресу
  `https://raw.githubusercontent.com/Tudo5/BarX/main/appcast.xml`.
- **Репозиторий**: `https://github.com/Tudo5/BarX` (ветка `main`).
- **Проект на диске**: `~/Desktop/BarX`.

Проверить, что ключ на месте (необязательно):
```bash
~/BarX-Sparkle-keys/bin/generate_keys --account com.ilya.BarX -p
```
Должен напечатать публичный ключ `pBPVmIIK14KtxXyk1RzGtpDVba3iiAdG02W+dJS/Hqo=`.

---

## 1. Выпуск новой версии — 4 шага

> Пример: выпускаем версию **1.5.4**. Подставляй свой номер.

### Шаг 1. Собрать подписанный релиз (одна команда)

```bash
cd ~/Desktop/BarX
Scripts/sparkle-release.sh ~/BarX-Sparkle-keys/bin 1.5.4
```

Что делает скрипт:
1. ставит `CFBundleShortVersionString = 1.5.4`;
2. **увеличивает build-номер** (`CFBundleVersion`) — Sparkle сравнивает именно сборки;
3. собирает Release;
4. делает ad-hoc подпись кода (без неё `generate_appcast` откажется);
5. создаёт образ `build/release/BarX.dmg`;
6. генерирует `appcast.xml` с EdDSA-подписью.

Проверь, что всё получилось:
```bash
ls -lh build/release/BarX.dmg
grep -E "sparkle:version|shortVersionString|enclosure" appcast.xml
```
В `appcast.xml` должна появиться запись с твоей версией и ссылкой на `.../v1.5.4/BarX.dmg`.

### Шаг 2. Создать GitHub Release и загрузить DMG

Через сайт (самый простой и безопасный способ):
1. Открой https://github.com/Tudo5/BarX/releases/new
2. **Tag:** `v1.5.4` — ровно `v` + версия (обязательно совпадает с версией из шага 1).
3. **Title:** например `BarX 1.5.4`
4. **Description:** что нового (это увидят пользователи в окне обновления).
5. **Attach binaries:** прикрепи файл `build/release/BarX.dmg`.
   ⚠️ Имя файла должно остаться **`BarX.dmg`** (не переименовывай!).
6. **Publish release**.

### Шаг 3. Опубликовать фид обновлений

```bash
cd ~/Desktop/BarX
git add appcast.xml Info.plist
git commit -m "Release 1.5.4"
git push origin main
```

### Шаг 4. Проверить

- Фид отдаёт новую версию:
  ```bash
  curl -s https://raw.githubusercontent.com/Tudo5/BarX/main/appcast.xml | grep -E "sparkle:version|shortVersionString"
  ```
- Файл по ссылке скачивается (не 404):
  ```bash
  curl -sIL https://github.com/Tudo5/BarX/releases/download/v1.5.4/BarX.dmg | grep -iE "^HTTP/|content-length"
  ```
- На приложении **старой** версии: меню → «Проверить обновления» → появится окно Sparkle
  «Установить и перезапустить / Позже» → обновление ставится само.

---

## 2. Правила, которые нельзя нарушать

1. **Порядок:** сначала загрузить `.dmg` в релиз, **потом** пушить `appcast.xml`.
   Иначе пользователь нажмёт «Обновить», а файла ещё нет → ошибка скачивания (404).
2. **Версия и build обязаны расти.** Скрипт поднимает build сам; не откатывай их назад.
3. **Тег = `v<версия>`** и **имя файла = `BarX.dmg`** — иначе ссылка в фиде не совпадёт.
4. **`appcast.xml` не редактируй руками** — его генерирует `generate_appcast`.
5. **Не коммить приватный ключ** (`*.key`, `BarX-Sparkle-keys/` уже в `.gitignore`).
6. **Не теряй приватный ключ** — без него не подпишешь новые обновления.
   Держи бэкап `~/BarX-Sparkle-keys/ed25519-private.key` в менеджере паролей/на флешке.

---

## 3. Быстрый чек-лист (скопируй себе)

```
[ ] cd ~/Desktop/BarX
[ ] Scripts/sparkle-release.sh ~/BarX-Sparkle-keys/bin <версия>
[ ] Проверить: build/release/BarX.dmg существует, в appcast.xml новая версия
[ ] GitHub → Releases → New → tag v<версия> → прикрепить BarX.dmg (имя не менять) → Publish
[ ] curl проверить, что dmg скачивается (HTTP 200)
[ ] git add appcast.xml Info.plist && git commit -m "Release <версия>" && git push origin main
[ ] Проверить обновление в старом приложении
```

---

## 4. Частые ошибки и решения

| Симптом | Причина / решение |
|---|---|
| `fatal: not a git repository` | Ты не в папке проекта. Сначала `cd ~/Desktop/BarX`. |
| `generate_appcast: No usable archives found` | Сборка не подписалась ad-hoc. Убедись, что запускаешь актуальный `Scripts/sparkle-release.sh` (в нём есть `codesign … --identifier com.ilya.BarX`). |
| `Signing key not found for account ed25519` | Ключ лежит под аккаунтом `com.ilya.BarX`. Скрипт уже передаёт `--account com.ilya.BarX`; при ручном запуске добавь этот флаг. |
| Окно обновления есть, но скачивание падает (404) | Не совпали тег/имя файла. Тег должен быть `v<версия>`, файл — `BarX.dmg`, и он должен быть **уже загружен** в релиз. |
| macOS спрашивает доступ к Связке ключей | Разреши (кнопка «Разрешить»/«Всегда разрешать»). |
| Sparkle пишет «you're up to date», хотя версия новая | Возможен кэш фида. Подожди пару минут или перезапусти приложение; проверь, что `appcast.xml` реально на `main` (curl выше). |

---

## 5. Если релиз вышел с ошибкой (откат)

- Заменить/перевыпустить ассет: в GitHub Release → Edit → удалить старый `.dmg`, загрузить исправленный (имя `BarX.dmg`), при необходимости поднять версию/build и пересобрать.
- Вернуть старый фид: `git log appcast.xml` → `git revert`/`git checkout <коммит> -- appcast.xml` → закоммитить и запушить.
- Помни: пользователи, уже обновившиеся, остаются на новой версии — «откатить» их можно только выпуском ещё более новой версии.

---

## 6. Что пока НЕ настроено (для публичной раздачи людям)

- **Universal-сборка** — сейчас только Apple Silicon (arm64). Для Intel-Mac нужен universal-билд.
- **Подпись Apple + нотаризация** (Apple Developer, $99/год) — без этого у чужих людей
  Gatekeeper покажет «разработчик не подтверждён» (правый клик → «Открыть»).
  Sparkle-подпись (EdDSA) это **не** заменяет.

Когда это сделаем — добавим в этот документ шаги подписи/нотаризации.
