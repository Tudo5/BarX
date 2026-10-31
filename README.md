# BarX

Приложение для **строки меню macOS**: панель быстрого запуска приложений, папки с
наборами, Launcher с глобальной горячей клавишей, темы и гибкие настройки.

- **Платформа:** macOS 15.6+
- **Технологии:** SwiftUI + AppKit, без сторонних зависимостей (кроме Sparkle для обновлений)
- **Авто-обновления:** [Sparkle 2](https://sparkle-project.org)

## Возможности
- Панель Bar с быстрым запуском приложений и перестановкой.
- Папки (presets) с элементами разных типов: приложение, папка, ссылка,
  раздел, Shell, AppleScript, Shortcuts, deep link («Схема»).
- Launcher с глобальной горячей клавишей.
- Темы оформления, настройки анимаций и внешнего вида.
- Экспорт/импорт настроек и данных, автоматические обновления.

## Сборка

Нужен **Xcode** (проект собирается под macOS 15.6+). В этом окружении
`xcode-select` указывает на CommandLineTools, поэтому нужен явный `DEVELOPER_DIR`:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project BarX.xcodeproj -scheme BarX -configuration Debug \
  -derivedDataPath /tmp/barx-build CODE_SIGNING_ALLOWED=NO build
```

Зависимость Sparkle подтягивается через Swift Package Manager автоматически.

Быстрая проверка компиляции без полной сборки:
```bash
swiftc -typecheck -module-cache-path /tmp/mc -sdk "$(xcrun --show-sdk-path)" \
  $(find BarX -name "*.swift")
```

## Обновления

Обновления раздаются через **Sparkle**. Канал обновлений — отдельный публичный
репозиторий **`Tudo5/BarX-updates`** (только `appcast.xml` и `.dmg`).
Приложение читает фид по адресу из `Info.plist` (`SUFeedURL`):
`https://raw.githubusercontent.com/Tudo5/BarX-updates/main/appcast.xml`

Как выпускать обновления — см. [RELEASING.md](RELEASING.md).

## Структура
```
BarX/
├── App/          точка входа, AppDelegate, уведомления
├── Core/         настройки, анимации, исполнение действий, утилиты
├── Models/       модели данных (AppItem, Preset, Theme…)
├── Managers/     состояние, темы, Launcher, горячие клавиши, окна, обновления
├── Components/   переиспользуемые UI-компоненты
└── Views/        меню, настройки, Launcher, диалоги добавления, обновления
Scripts/          сборка DMG и выпуск релизов
```

## Лицензия
Не указана. Все права принадлежат автору.
