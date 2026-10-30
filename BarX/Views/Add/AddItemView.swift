//
//  AddItemView.swift
//  BarX
//
//  Добавление элемента в папку: приложение, папка или ссылка.
//  Окно переработано: выбор типа карточками, живой предпросмотр строки,
//  настоящая иконка файла (с возможностью взять значок из каталога),
//  перетаскивание файла/ссылки в окно и автоподстановка данных.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import ServiceManagement
import UserNotifications
import ApplicationServices

// MARK: - AddItemView

struct AddItemView: View {
    /// Компактный размер окна — для типов с одной строкой поля (приложение,
    /// папка, ссылка, deep link, Shortcuts). Кадр вида и размер окна берутся
    /// отсюда, чтобы не разъезжаться. Для многострочных действий (Shell/
    /// AppleScript) окно расширяется — см. `windowSize(for:)`.
    ///
    /// Высота = естественная высота контента (499) + запас 45 пт под плашку
    /// дубликата и отступ перед кнопками.
    static let windowSize = CGSize(width: 500, height: 544)

    /// Высота окна для типов с многострочным редактором (Shell/AppleScript):
    /// контенту нужно ~617 пт, +45 пт — слот под плашку дубликата.
    static let tallWindowHeight: CGFloat = 662

    static func windowSize(for type: AppItem.ItemType) -> CGSize {
        let isTall = type == .shell || type == .applescript
        return CGSize(
            width: windowSize.width,
            height: isTall ? tallWindowHeight : windowSize.height
        )
    }

    let presetId: UUID
    let onAdded: () -> Void

    @EnvironmentObject var appState: AppStateManager
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var animations = AnimationCenter.shared

    @State private var itemName = ""
    @State private var itemPath = ""
    @State private var selectedIcon = "app.fill"
    @State private var itemType: AppItem.ItemType = .application
    @State private var showingFilePicker = false
    @State private var showingShortcutPicker = false
    @State private var showingDeepLinkPicker = false
    /// Результат тестового запуска команды/скрипта в редакторе (nil — ещё не гоняли).
    @State private var testResult: ActionExecutor.CommandOutcome?
    @State private var isTestingRun = false
    @State private var duplicateWarning: String?
    @State private var useRealIcon = true
    @State private var customIconChosen = false
    @State private var isDropTargeted = false
    @FocusState private var isNameFieldFocused: Bool

    /// Стартовый тип элемента. По умолчанию — приложение; тесты используют
    /// его, чтобы замерить высоту формы в состояниях с редактором действий.
    init(
        presetId: UUID,
        onAdded: @escaping () -> Void,
        initialType: AppItem.ItemType = .application
    ) {
        self.presetId = presetId
        self.onAdded = onAdded
        self._itemType = State(initialValue: initialType)
        if initialType.isExecutableAction || initialType == .url {
            self._selectedIcon = State(initialValue: initialType.defaultIcon)
        }
    }

    var body: some View {
        ZStack {
            if let theme = themeManager.effectiveTheme {
                GradientBackground(theme: theme)
                    .ignoresSafeArea()
            }

            formContent
                .frame(
                    width: Self.windowSize(for: itemType).width,
                    height: Self.windowSize(for: itemType).height
                )
                .fileImporter(
                    isPresented: $showingFilePicker,
                    allowedContentTypes: [.application, .folder]
                ) { result in
                    switch result {
                    case .success(let url):
                        applyPickedFile(url)
                    case .failure(let error):
                        Log.error("Ошибка выбора файла: \(error.localizedDescription)")
                    }
                }
                .onDrop(
                    of: [.fileURL, .url, .plainText],
                    isTargeted: $isDropTargeted
                ) { providers in
                    handleDrop(providers)
                    return true
                }
                .overlay(dropOverlay)
                .animation(animations.quick, value: isDropTargeted)
                .onAppear { isNameFieldFocused = true }
                .onChange(of: itemType) { _, newType in
                    // Диалог расширяется под многострочный редактор действия
                    // и снова сжимается для обычных типов. Вызываем вне цикла
                    // обновления SwiftUI (async), чтобы не дёргать AppKit-окно
                    // синхронно внутри onChange — иначе при быстрых кликах было
                    // пере-entrant обновление и падение.
                    let size = Self.windowSize(for: newType)
                    DispatchQueue.main.async {
                        BarXWindowManager.shared.resizeWindow(id: "addItem", size: size)
                    }
                }
        }
    }

    /// Содержимое формы без кадра — по нему тест замеряет естественный размер
    /// и проверяет, что окно подогнано вплотную (без пустоты и без обрезки).
    var formContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            Divider()
                .background(Color.white.opacity(0.3))

            typeCards
            nameField
            payloadField
            iconSection

            if let duplicateWarning {
                SettingsHint(text: duplicateWarning, color: .yellow)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
            actionButtons
        }
        .padding(20)
        .sheet(isPresented: $showingShortcutPicker) {
            ShortcutPickerView(
                onPicked: { name in
                    itemPath = name
                    if trimmedName.isEmpty { itemName = name }
                    showingShortcutPicker = false
                },
                onClose: { showingShortcutPicker = false }
            )
            .environmentObject(appState)
            .frame(width: 420, height: 440)
        }
        .sheet(isPresented: $showingDeepLinkPicker) {
            DeepLinkPickerView(
                onPicked: { template in
                    itemPath = template
                    showingDeepLinkPicker = false
                },
                onClose: { showingDeepLinkPicker = false }
            )
            .environmentObject(appState)
            .frame(width: 460, height: 520)
        }
    }

    // MARK: - Тип элемента (карточки)

    private var typeCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Тип элемента")
                .font(.headline)
                .adaptiveTextColor()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    typeCard(.application, title: "Приложение", icon: "app.fill")
                    typeCard(.folder, title: "Папка", icon: "folder.fill")
                    typeCard(.url, title: "Ссылка", icon: "globe")
                    typeCard(.section, title: "Раздел", icon: "line.3.horizontal")
                }
                // Вторая строка — типы действий (исполняются, а не «открываются»).
                HStack(spacing: 8) {
                    typeCard(.shell, title: "Shell", icon: "terminal")
                    typeCard(.applescript, title: "Скрипт", icon: "doc.text")
                    typeCard(.shortcut, title: "Shortcuts", icon: "square.grid.2x2")
                    typeCard(.deeplink, title: "Схема", icon: "link")
                }
            }
        }
    }

    private func typeCard(
        _ type: AppItem.ItemType,
        title: String,
        icon: String
    ) -> some View {
        let isActive = itemType == type

        return Button {
            withAnimation(animations.quick) {
                itemType = type
                // Пока пользователь сам не выбрал значок — держим символ
                // по умолчанию для нового типа.
                if !customIconChosen {
                    selectedIcon = Self.defaultIcon(for: type)
                }
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                Text(title)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            // Плоская карточка: прозрачный фон, тонкая обводка. Выбранная
            // подсвечивается акцентом темы (как на макете), не «кирпичом».
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? accentColor.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isActive ? accentColor : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .foregroundStyle(isActive ? accentColor : Color.white.opacity(0.75))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    /// Акцентный цвет темы для подсветки выбранной карточки и кнопки.
    private var accentColor: Color {
        Color(hex: BarXSettings.appearanceAccent)
    }

    // MARK: - Шапка с живым предпросмотром

    /// Заголовок + компактный живой предпросмотр: иконка и название того,
    /// что добавится. Заменяет прежнюю отдельную карточку «Предпросмотр» —
    /// та дублировала поля ниже и съедала ~70 пт высоты окна.
    private var headerRow: some View {
        HStack(spacing: 12) {
            Text("Добавить элемент")
                .font(.title2.bold())
                .adaptiveTextColor()
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                ItemIconView(item: previewItem, size: 20)
                    .frame(width: 20, height: 20)
                Text(displayName)
                    .font(.caption)
                    .adaptiveTextColor()
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 200, alignment: .trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Поля

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Название")
                .font(.headline)
                .adaptiveTextColor()
            TextField("Введите название", text: $itemName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit { submitIfPossible() }
        }
    }

    // MARK: - Содержимое (зависит от типа)

    /// Поле ввода меняется по типу: путь/адрес для открытия, команда или
    /// скрипт для действий, имя для Shortcuts. Payload всех типов живёт в `path`.
    @ViewBuilder
    private var payloadField: some View {
        switch itemType {
        case .shell, .applescript:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(itemType == .shell ? "Команда" : "AppleScript")
                        .font(.headline)
                        .adaptiveTextColor()
                    Spacer()
                    // Тестовый запуск — видно, что команда реально выполняется,
                    // и её вывод/ошибка до сохранения элемента.
                    Button {
                        runActionTest()
                    } label: {
                        HStack(spacing: 5) {
                            if isTestingRun {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text(isTestingRun ? "Идёт…" : "Запустить")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                    .disabled(itemPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingRun)
                }

                TextEditor(text: $itemPath)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 66, maxHeight: 88)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if itemPath.isEmpty {
                            Text(itemType == .shell ? "например: open -a Safari" : "tell application \"Finder\"\n  activate\nend tell")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    }

                if let testResult {
                    testResultView(testResult)
                }
            }

        case .shortcut:
            VStack(alignment: .leading, spacing: 6) {
                Text("Имя команды Shortcuts")
                    .font(.headline)
                    .adaptiveTextColor()
                HStack {
                    TextField("Например: «Ночной режим»", text: $itemPath)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submitIfPossible() }
                    Button {
                        showingShortcutPicker = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                    .help("Выбрать из установленных команд")
                }
            }

        case .url:
            urlField

        case .deeplink:
            deepLinkField

        case .section:
            VStack(alignment: .leading, spacing: 6) {
                Text("Заголовок раздела")
                    .font(.headline)
                    .adaptiveTextColor()
                Text("Текст берётся из поля «Название» выше. Раздел только группирует элементы и не запускается.")
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .application, .folder, .action:
            VStack(alignment: .leading, spacing: 6) {
                Text("Путь")
                    .font(.headline)
                    .adaptiveTextColor()
                HStack {
                    TextField("/Applications/...", text: $itemPath)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submitIfPossible() }
                    Button("Выбрать") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Поля ссылок

    /// Обычная веб-ссылка: адрес, открывается браузером по умолчанию.
    private var urlField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Адрес ссылки")
                .font(.headline)
                .adaptiveTextColor()
            TextField("https://example.com", text: $itemPath)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submitIfPossible() }
        }
    }

    /// Ссылка приложения (deep link): поле + кнопка «Библиотека» и живая
    /// проверка схемы — видно, в каком приложении ссылка откроется.
    private var deepLinkField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ссылка приложения")
                .font(.headline)
                .adaptiveTextColor()
            HStack {
                TextField("spotify:track:…", text: $itemPath)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submitIfPossible() }
                Button {
                    showingDeepLinkPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical")
                        Text("Библиотека")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.small)
                .help("Выбрать из каталога схем популярных приложений")
            }
            deepLinkStatusRow
        }
    }

    /// Живая подсказка под полем deep link. Постоянная высота в одну строку,
    /// чтобы окно не «дышало» при вводе. Зелёная — схема известна (откроется
    /// в приложении из каталога), нейтральная — неизвестная или ещё не введена.
    private var deepLinkStatusRow: some View {
        let trimmed = trimmedPath
        let scheme = DeepLinkCatalog.scheme(from: trimmed)
        let app = scheme.flatMap { DeepLinkCatalog.app(forScheme: $0) }

        return HStack(spacing: 6) {
            if let app {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Откроется в «\(app.app)»")
                    .foregroundStyle(.green)
            } else if let scheme {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                Text("Неизвестная схема «\(scheme)»")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Введите ссылку вида app://…")
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .lineLimit(1)
        .frame(height: 18)
        .opacity(trimmed.isEmpty ? 0.7 : 1)
    }

    // MARK: - Иконка

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Иконка")
                    .font(.headline)
                    .adaptiveTextColor()
                Spacer()
                if canUseRealIcon {
                    HStack(spacing: 6) {
                        Text("Настоящая")
                            .font(.caption)
                            .adaptiveTextColor()
                            .opacity(0.8)
                        Toggle("", isOn: $useRealIcon)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .controlSize(.mini)
                    }
                }
            }

            if canUseRealIcon && useRealIcon {
                realIconPreview
            } else {
                IconPickerView(
                    categories: IconCatalog.essentials,
                    selectedIcon: iconBinding,
                    showsCategories: false,
                    gridHeight: 68,
                    columnCount: 8
                )
            }
        }
    }

    /// Настоящая иконка выбранного файла — компактное превью вместо сетки значков.
    private var realIconPreview: some View {
        HStack(spacing: 10) {
            ItemIconView(item: previewItem, size: 34)
                .frame(width: 34, height: 34)
            Text("Иконка будет взята из выбранного файла")
                .font(.caption)
                .adaptiveTextColor()
                .opacity(0.55)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Кнопки

    /// Кнопки действий — компактные, сгруппированы вправо (как на макете).
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Почему «Добавить» неактивна. Без этого серая кнопка выглядела
            // как «не работает» — теперь она прямо говорит, чего не хватает.
            if let reason = disabledReason {
                Text(reason)
                    .font(.caption)
                    .adaptiveTextColor()
                    .opacity(0.65)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            Button("Отмена") {
                BarXWindowManager.shared.closeWindow(id: "addItem")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.white)

            Button("Добавить") {
                addItem()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(accentColor)
            .disabled(disabledReason != nil)
        }
        .animation(animations.quick, value: disabledReason)
    }

    /// Причина, по которой «Добавить» неактивна, либо `nil`, если всё заполнено.
    private var disabledReason: String? {
        if trimmedName.isEmpty { return "Укажите название" }
        if itemType.requiresPath && trimmedPath.isEmpty { return missingPathHint }
        return nil
    }

    /// Подсказка под конкретный тип — что именно нужно заполнить в поле выше.
    private var missingPathHint: String {
        switch itemType {
        case .application, .folder: "Укажите путь"
        case .url: "Укажите адрес ссылки"
        case .deeplink: "Вставьте ссылку приложения"
        case .shell: "Введите команду"
        case .applescript: "Введите скрипт"
        case .shortcut: "Выберите команду"
        default: "Заполните поле выше"
        }
    }

    // MARK: - Подсветка при перетаскивании

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTargeted {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.25))
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .foregroundStyle(.white.opacity(0.7))
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 30))
                    Text("Перетащите приложение, папку или ссылку")
                        .font(.callout)
                }
                .adaptiveTextColor()
            }
            .padding(8)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    // MARK: - Производные значения

    private var canUseRealIcon: Bool {
        itemType == .application || itemType == .folder
    }

    private var trimmedName: String {
        itemName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPath: String {
        itemPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        guard trimmedName.isEmpty else { return trimmedName }
        switch itemType {
        case .shell: return "Новая команда"
        case .applescript: return "Новый скрипт"
        case .shortcut: return "Новая команда Shortcuts"
        case .deeplink: return "Новая ссылка приложения"
        case .folder: return "Новая папка"
        case .url: return "Новая ссылка"
        case .section: return "Новый раздел"
        case .application, .action: return "Новое приложение"
        }
    }

    private var previewItem: AppItem {
        AppItem(
            name: displayName,
            path: trimmedPath,
            icon: selectedIcon,
            preset: "",
            type: itemType,
            useRealIcon: useRealIcon
        )
    }

    /// Сетка значков пишет выбранную иконку и помечает её как ручной выбор,
    /// чтобы смена типа не затирала пользовательский значок.
    private var iconBinding: Binding<String> {
        Binding(
            get: { selectedIcon },
            set: { selectedIcon = $0; customIconChosen = true }
        )
    }

    private static func defaultIcon(for type: AppItem.ItemType) -> String {
        // Иконка по умолчанию живёт в модели — здесь только делегирование,
        // чтобы символы типов не разъезжались в разных местах.
        type.defaultIcon
    }

    // MARK: - Тестовый запуск команды/скрипта

    private func runActionTest() {
        guard !isTestingRun else { return }
        isTestingRun = true
        testResult = nil
        ActionExecutor.testRunAction(type: itemType, payload: itemPath) { result in
            testResult = result
            isTestingRun = false
        }
    }

    /// Компактная строка результата теста: статус + вывод в одну строку.
    /// Намеренно низкая (~30 пт), чтобы поглощалась запасом `Spacer` окна
    /// и не обрезалась снизу.
    private func testResultView(_ result: ActionExecutor.CommandOutcome) -> some View {
        let ok = result.succeeded
        let text = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(ok ? Color.green : Color.red)

            Text(ok ? "Выполнено" : (result.timedOut ? "Таймаут" : "Ошибка"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ok ? Color.green : Color.red)

            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Button {
                testResult = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Скрыть результат")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(ok ? 0.05 : 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke((ok ? Color.green : Color.red).opacity(0.35), lineWidth: 1)
        )
        .transition(.opacity)
    }

    // MARK: - Drag & drop и выбор файла

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(
                    forTypeIdentifier: UTType.fileURL.identifier,
                    options: nil
                ) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil)
                    else { return }
                    DispatchQueue.main.async { applyPickedFile(url) }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(
                    forTypeIdentifier: UTType.url.identifier,
                    options: nil
                ) { item, _ in
                    let raw: String?
                    if let url = item as? URL {
                        raw = url.absoluteString
                    } else if let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) {
                        raw = url.absoluteString
                    } else {
                        raw = item as? String
                    }
                    if let raw {
                        DispatchQueue.main.async { applyDroppedLink(raw) }
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(
                    forTypeIdentifier: UTType.plainText.identifier,
                    options: nil
                ) { item, _ in
                    guard let text = item as? String else { return }
                    DispatchQueue.main.async { applyDroppedLink(text) }
                }
                return
            }
        }
    }

    /// Подставляет данные выбранного/перетащенного файла: тип, путь, имя.
    private func applyPickedFile(_ url: URL) {
        let isApp = url.pathExtension.lowercased() == "app"
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = values?.isDirectory ?? false

        itemType = isDirectory && !isApp ? .folder : .application
        itemPath = url.path

        if trimmedName.isEmpty {
            itemName = isApp
                ? url.deletingPathExtension().lastPathComponent
                : url.lastPathComponent
        }

        // Настоящая иконка — по умолчанию; значок сбрасываем на символ типа.
        useRealIcon = true
        customIconChosen = false
        selectedIcon = Self.defaultIcon(for: itemType)
        duplicateWarning = nil
    }

    /// Подставляет перетащенную ссылку: тип URL и нормализованный адрес.
    private func applyDroppedLink(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.contains("://") {
            text = "https://" + text
        }
        guard let url = URL(string: text), url.host != nil else { return }

        itemType = .url
        itemPath = text
        if trimmedName.isEmpty {
            itemName = url.host ?? text
        }
        customIconChosen = false
        selectedIcon = Self.defaultIcon(for: .url)
        duplicateWarning = nil
    }

    // MARK: - Сохранение

    /// Enter в текстовом поле добавляет элемент, если форма уже заполнена.
    /// Условие повторяет `disabledReason`: пока кнопка «Добавить» неактивна,
    /// Enter тоже ничего не делает.
    private func submitIfPossible() {
        guard disabledReason == nil else { return }
        addItem()
    }

    private func addItem() {
        guard let index = appState.presets.firstIndex(where: { $0.id == presetId }) else {
            return
        }

        let name = trimmedName
        let path = trimmedPath

        // Дедупликация: раньше один и тот же элемент можно было добавить
        // в папку сколько угодно раз, и каждый клик открывал дубликат.
        // У раздела пути нет — сравниваем по названию, иначе два разных
        // заголовка сочлись бы дублем (оба с пустым path).
        let isDuplicate = appState.presets[index].items.contains { existing in
            guard existing.type == itemType else { return false }
            if itemType == .section {
                return existing.name.compare(name, options: .caseInsensitive) == .orderedSame
            }
            return existing.path.compare(path, options: .caseInsensitive) == .orderedSame
        }
        guard !isDuplicate else {
            duplicateWarning = "Элемент «\(name)» уже есть в этой папке."
            return
        }

        let item = AppItem(
            name: name,
            path: path,
            icon: selectedIcon,
            preset: appState.presets[index].name,
            type: itemType,
            useRealIcon: useRealIcon
        )

        _ = appState.addItem(item, toPreset: presetId)
        onAdded()
        BarXWindowManager.shared.closeWindow(id: "addItem")
    }
}
