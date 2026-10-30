# BarX — контекст проекта

> Этот файл автоматически подгружается в контекст каждой новой сессии DSH,
> работающей в этом каталоге. Держите его актуальным: это «долговременная память» проекта.

## Что это

**BarX** — приложение для строки меню macOS (SwiftUI + AppKit, без сторонних зависимостей
кроме неиспользуемого SwiftPM-пакета `HotKey`). Даёт панель быстрого запуска приложений,
папки с наборами, Launcher с глобальной горячей клавишей, темы и настройки.

- Bundle ID: `com.ilya.BarX` (подставляется в `Info.plist` как `$(PRODUCT_BUNDLE_IDENTIFIER)`)
- **Версия и билд** — в корневом `Info.plist` (`CFBundleShortVersionString` / `CFBundleVersion`);
  сборка использует `GENERATE_INFOPLIST_FILE = NO` + `INFOPLIST_FILE = Info.plist`,
  поэтому экран «О программе» читает их оттуда автоматически. Чтобы версия подставлялась,
  в `Info.plist` есть `CFBundleExecutable = $(EXECUTABLE_NAME)` и `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)`
- Язык интерфейса и комментариев: **русский**
- Один таргет приложения + `BarXTests` / `BarXUITests`

## Сборка и проверка

`xcode-select` указывает на CommandLineTools, поэтому **нужен явный DEVELOPER_DIR**:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project BarX.xcodeproj -scheme BarX -configuration Debug \
  -derivedDataPath /tmp/barx-build CODE_SIGNING_ALLOWED=NO build
```

Быстрая проверка компиляции без SwiftPM (в разы быстрее):

```bash
swiftc -typecheck -module-cache-path /tmp/mc -sdk "$(xcrun --show-sdk-path)" \
  $(find BarX -name "*.swift")
```

Требования к результату: **0 ошибок и 0 предупреждений**. После правок всегда проверять.
Песочница может блокировать кэш SwiftPM в `~/Library/Caches` — тогда нужен доступ вне
рабочей папки либо проверка через `swiftc -typecheck`.

## Структура (папка `BarX/` — синхронизированная группа Xcode)

Новые файлы внутри `BarX/` **не нужно добавлять в проект вручную** — они подхватываются
автоматически (`PBXFileSystemSynchronizedRootGroup` в `project.pbxproj`).

```
BarX/
├── App/BarXApp.swift              точка входа (@main), AppDelegate, уведомления
├── Core/
│   ├── AnimationCenter.swift      ВСЕ анимации и их настройки
│   ├── BarXSettings.swift         ключи UserDefaults, значения по умолчанию, автозапуск,
│   │                              разрешения, применение системных настроек
│   ├── BarXBackup.swift           экспорт/импорт настроек и данных
│   ├── KeyCodeHelper.swift        коды клавиш, разбор горячих комбинаций
│   ├── AppTypes.swift             SettingsCategory, FileAccessHelper
│   └── NotificationHelper.swift   системные уведомления
├── Models/Models.swift            AppItem, Preset, Theme, GradientDirection
├── Managers/                      AppState, Theme, Launcher, Hotkey, Window, Update
├── Components/                    IconPicker, Styling, HotkeyRecorder, BarXActionButton
└── Views/
    ├── Menu/                      BarXMenuView, BarPanelView, FoldersAndItems
    ├── Settings/                  окно настроек + 8 разделов
    ├── Launcher/                  LauncherWindowView, панель сведений
    ├── Add/                       диалоги добавления (панель, папка, элемент, из Finder)
    └── Update/                    окно обновления
```

## Ключевые архитектурные решения

1. **Настройки** — единый источник: `BarXSettings.defaultValues` (регистрируются в
   UserDefaults), чтение через `BarXSettings.<ключ>` или `@AppStorage` с тем же ключом.
   Новый ключ обязан попасть в `defaultValues` **и** в `BarXBackup.preferenceKeys`.
   **Каждая настройка обязана иметь потребителя** — иначе тумблер становится декоративным.
2. **Анимации** — только через `AnimationCenter.shared` (`hover`, `quick`, `press`,
   `standard`, `layout`, `spring`, `bouncy`, `pulse`, переходы). Захардкоженные
   `withAnimation(.easeInOut(duration: 0.2))` не добавлять.
   `layout` — для перестроения списков (без пружины, чтобы не «дёргалось»).
3. **Идентичность приложений** — сравнивать **по пути**, а не по `UUID`:
   сканирование создаёт новые `UUID` при каждом запуске. Используйте
   `AppStateManager.isSameApp(_:_:)`.
4. **Папки (presets)** живут в `presetsData` и обязаны восстанавливаться при запуске.
5. **Темы** — встроенный список из 18 тем в `ThemeManager` не менять без запроса.
   Цвета текста и hex кэшируются; после изменения набора тем вызывать `reloadThemes()`.
6. **Иконки** — только через `IconPickerView` + `IconCatalog`.
   `SFSymbolCatalog` отсеивает символы, отсутствующие в текущей macOS
   (иначе они рисуются пустыми клетками).
7. **UI настроек** — компоненты `SettingsCard` / `SettingsInfoRow` / `SettingsHint`
   (в `Views/Settings/SettingsComponents.swift`), текст — `.adaptiveTextColor()`,
   чтобы читался на любой теме.

## Грабли, на которые уже наступали (не повторять)

- Не анимировать макет списка по числу элементов и не делать каскад на каждую строку при
  смене фильтра — список начинает «дёргаться». Высота списка должна быть стабильной,
  внешний `ScrollView` не должен пересчитывать контент.
- Не делать `DispatchQueue.main.asyncAfter` перед выполнением действия — клик становится
  «вязким». Сначала действие, потом анимация результата.
- Не смешивать две навигации в одной сетке (страницы + внутренняя прокрутка) — часть
  элементов становится недостижимой.
- `NSWindow.delegate` — слабая ссылка: делегат нужно удерживать.
- Окно, открываемое повторно, нужно **пересобирать**, иначе в нём остаются старые настройки.
- «Сброс настроек» не должен удалять данные пользователя (панель, папки, темы) —
  для данных есть отдельная операция.
- `Set.remove` внутри `withAnimation` возвращает значение — писать `_ =` или разбивать.
- `NSImage.lockFocus()`/`unlockFocus()` — **не потокобезопасны** (общий графический
  контекст). Значки масштабируются из `DispatchQueue.global()`, поэтому `NSImage.resized`
  рисует через `NSBitmapImageRep` + локальный `NSGraphicsContext`. Через `lockFocus`
  приложение падало при выборе многих приложений сразу (гонка).

## Текущее состояние (на момент последней правки)

Реализовано: модульная структура, раздел настроек **«Анимации»** с 13 параметрами,
панель Bar с двумя видами и перестановкой, Launcher с панелью сведений, папки с
переименованием и дублированием, «Приложения» со списком/сеткой и массовыми операциями,
общий выбор иконок с фильтрацией недоступных символов, «О программе» с контактом
Telegram `@Dreamssport`.

Известные хвосты: `Views/Add/AddToFolder*` не существует (создание папки — `AddFolderView`);
класс `UpdateManager` удалён, живой только `BarXUpdateManager`.

## Проверка перед завершением задачи

1. `swiftc -typecheck` — 0 ошибок и предупреждений.
2. Полная сборка `xcodebuild` — `** BUILD SUCCEEDED **`.
3. Убедиться, что каждая новая настройка где-то читается (grep по ключу).
4. Временные каталоги сборки удалить; в проекте не должно появляться мусора
   (`.DS_Store`, `default.profraw`).
