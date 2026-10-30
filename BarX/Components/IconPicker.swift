//
//  IconPicker.swift
//  BarX
//
//  Выбор SF-символа: категории слева, значки справа, страницы и поиск.
//  Все переходы анимированы, недоступные символы скрываются.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Доступность SF Symbols

enum SFSymbolCatalog {
    private static var cache: [String: Bool] = [:]
    private static let lock = NSLock()

    /// Существует ли символ в этой версии macOS.
    static func isAvailable(_ name: String) -> Bool {
        lock.lock()
        if let cached = cache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let exists = NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil

        lock.lock()
        cache[name] = exists
        lock.unlock()
        return exists
    }

    /// Убирает из списка символы, которых нет в системе.
    static func available(_ names: [String]) -> [String] {
        names.filter { isAvailable($0) }
    }
}

enum IconCatalog {
    static let categories: [(name: String, icon: String, icons: [String])] = [
        (
            "Папки и файлы",
            "folder",
            [
                "folder", "folder.fill", "folder.circle", "folder.circle.fill",
                "folder.badge.plus", "folder.badge.minus", "folder.badge.person.crop",
                "doc", "doc.fill", "doc.text", "doc.text.fill", "doc.richtext",
                "doc.on.doc", "doc.on.doc.fill", "doc.zip", "doc.zip.fill",
                "archivebox", "archivebox.fill", "tray", "tray.fill", "tray.full",
                "tray.full.fill", "externaldrive", "externaldrive.fill",
                "doc.text.magnifyingglass", "doc.text.below.ecg"
            ]
        ),
        (
            "Игры",
            "gamecontroller",
            [
                "gamecontroller", "gamecontroller.fill",
                "dice", "dice.fill",
                "puzzlepiece", "puzzlepiece.fill",
                "ticket", "ticket.fill",
                "theatermasks", "theatermasks.fill",
                "crown", "crown.fill",
                "trophy", "trophy.fill", "trophy.circle", "trophy.circle.fill",
                "flag.checkered", "flag.checkered.2.crossed",
                "target", "scope", "dot.scope",
                "arcade.stick", "arcade.stick.console"
            ]
        ),
        (
            "Работа",
            "briefcase",
            [
                "briefcase", "briefcase.fill",
                "suitcase", "suitcase.fill",
                "building", "building.fill", "building.2", "building.2.fill",
                "banknote", "banknote.fill",
                "creditcard", "creditcard.fill",
                "chart.bar", "chart.bar.fill", "chart.pie", "chart.pie.fill",
                "chart.line.uptrend.xyaxis",
                "calendar", "calendar.circle", "calendar.circle.fill",
                "clock", "clock.fill", "clock.circle", "clock.circle.fill",
                "hourglass", "hourglass.bottomhalf.filled", "hourglass.tophalf.filled",
                "checklist", "list.bullet", "list.bullet.clipboard",
                "clipboard", "clipboard.fill",
                "printer", "printer.fill",
                "faxmachine", "scanner", "scanner.fill",
                "deskclock", "deskclock.fill"
            ]
        ),
        (
            "Учёба",
            "book",
            [
                "book", "book.fill", "book.closed", "book.closed.fill",
                "books.vertical", "books.vertical.fill",
                "text.book.closed", "text.book.closed.fill",
                "graduationcap", "graduationcap.fill",
                "pencil", "pencil.circle", "pencil.circle.fill",
                "pencil.and.outline", "pencil.tip", "pencil.tip.crop.circle",
                "highlighter", "ruler", "ruler.fill",
                "backpack", "backpack.fill",
                "studentdesk", "paperclip", "paperclip.circle", "paperclip.circle.fill",
                "doc.text.magnifyingglass"
            ]
        ),
        (
            "Медиа",
            "music.note",
            [
                "music.note", "music.note.list", "music.quarternote.3",
                "headphones", "headphones.circle", "headphones.circle.fill",
                "speaker.wave.2", "speaker.wave.2.fill",
                "play.circle", "play.circle.fill",
                "film", "film.fill", "film.stack", "film.stack.fill",
                "video", "video.fill", "video.circle", "video.circle.fill",
                "photo", "photo.fill", "photo.on.rectangle", "photo.stack", "photo.stack.fill",
                "camera", "camera.fill", "camera.circle", "camera.circle.fill",
                "tv", "tv.fill", "tv.circle", "tv.circle.fill",
                "mic", "mic.fill", "mic.circle", "mic.circle.fill",
                "waveform", "waveform.circle", "waveform.circle.fill",
                "recordingtape"
            ]
        ),
        (
            "Связь",
            "message",
            [
                "message", "message.fill", "message.circle", "message.circle.fill",
                "bubble.left", "bubble.left.fill",
                "bubble.right", "bubble.right.fill",
                "envelope", "envelope.fill", "envelope.circle", "envelope.circle.fill",
                "envelope.open", "envelope.open.fill",
                "phone", "phone.fill", "phone.circle", "phone.circle.fill",
                "phone.arrow.up.right", "phone.arrow.down.left",
                "video.badge.plus", "video.badge.checkmark",
                "paperplane", "paperplane.fill", "paperplane.circle", "paperplane.circle.fill",
                "at", "at.circle", "at.circle.fill",
                "megaphone", "megaphone.fill"
            ]
        ),
        (
            "Символы",
            "star",
            [
                "star", "star.fill", "star.circle", "star.circle.fill",
                "star.square", "star.square.fill",
                "heart", "heart.fill", "heart.circle", "heart.circle.fill",
                "heart.square", "heart.square.fill",
                "sparkles", "sparkle",
                "crown", "crown.fill",
                "flame", "flame.fill",
                "bolt", "bolt.fill", "bolt.circle", "bolt.circle.fill",
                "rosette",
                "seal", "seal.fill",
                "shield", "shield.fill", "shield.lefthalf.filled",
                "checkmark.seal", "checkmark.seal.fill",
                "medal", "medal.fill"
            ]
        ),
        (
            "Инструменты",
            "gear",
            [
                "gear", "gearshape", "gearshape.fill", "gearshape.2", "gearshape.2.fill",
                "gear.circle", "gear.circle.fill",
                "wrench", "wrench.fill", "wrench.adjustable", "wrench.adjustable.fill",
                "hammer", "hammer.fill", "hammer.circle", "hammer.circle.fill",
                "screwdriver", "screwdriver.fill",
                "paintbrush", "paintbrush.fill", "paintbrush.pointed", "paintbrush.pointed.fill",
                "paintpalette", "paintpalette.fill",
                "scissors", "scissors.circle", "scissors.circle.fill",
                "bandage", "bandage.fill",
                "cross.case", "cross.case.fill",
                "stethoscope", "syringe", "syringe.fill",
                "pills", "pills.fill", "pills.circle", "pills.circle.fill"
            ]
        ),
        (
            "Устройства",
            "laptopcomputer",
            [
                "laptopcomputer", "laptopcomputer.and.iphone",
                "desktopcomputer", "display", "display.2",
                "macpro.gen1", "macpro.gen2", "macpro.gen3",
                "macmini", "macmini.fill",
                "iphone", "iphone.gen1", "iphone.gen2", "iphone.gen3",
                "ipad", "ipad.gen1", "ipad.gen2",
                "applewatch", "applewatch.side.right",
                "airpods", "airpods.gen3", "airpodsmax", "airpodpro",
                "keyboard", "keyboard.fill",
                "mouse", "mouse.fill",
                "printer", "printer.fill",
                "scanner", "scanner.fill",
                "headphones", "headphones.circle",
                "tv.and.mediabox", "tv.and.hifispeaker.fill",
                "homepod", "homepod.fill", "homepodmini", "homepodmini.fill",
                "appletv", "appletv.fill"
            ]
        ),
        (
            "Природа",
            "sun.max",
            [
                "sun.max", "sun.max.fill", "sun.max.circle", "sun.max.circle.fill",
                "moon", "moon.fill", "moon.stars", "moon.stars.fill",
                "cloud", "cloud.fill", "cloud.sun", "cloud.sun.fill",
                "cloud.rain", "cloud.rain.fill", "cloud.snow", "cloud.snow.fill",
                "cloud.bolt", "cloud.bolt.fill", "cloud.bolt.rain", "cloud.bolt.rain.fill",
                "cloud.fog", "cloud.fog.fill", "cloud.moon", "cloud.moon.fill",
                "snowflake", "wind", "tornado", "hurricane",
                "drop", "drop.fill", "drop.circle", "drop.circle.fill",
                "leaf", "leaf.fill", "leaf.circle", "leaf.circle.fill",
                "tree", "tree.fill", "tree.circle", "tree.circle.fill",
                "camera.macro", "camera.macro.circle",
                "flame", "flame.fill"
            ]
        ),
        (
            "Животные",
            "pawprint",
            [
                "pawprint", "pawprint.fill", "pawprint.circle", "pawprint.circle.fill",
                "hare", "hare.fill", "tortoise", "tortoise.fill",
                "ant", "ant.fill", "ant.circle", "ant.circle.fill",
                "ladybug", "ladybug.fill",
                "bird", "bird.fill", "fish", "fish.fill",
                "dog", "dog.fill", "cat", "cat.fill",
                "lizard", "lizard.fill",
                "butterfly", "butterfly.fill",
                "teddybear", "teddybear.fill",
                "fossil.shell", "fossil.shell.fill"
            ]
        ),
        (
            "Еда",
            "cup.and.saucer",
            [
                "cup.and.saucer", "cup.and.saucer.fill",
                "mug", "mug.fill",
                "wineglass", "wineglass.fill",
                "fork.knife", "fork.knife.circle", "fork.knife.circle.fill",
                "takeoutbag.and.cup.and.straw", "takeoutbag.and.cup.and.straw.fill",
                "birthday.cake", "birthday.cake.fill",
                "carrot", "carrot.fill",
                "popcorn", "popcorn.fill",
                "waterbottle", "waterbottle.fill",
                "frying.pan", "frying.pan.fill",
                "kettle", "kettle.fill",
                "refrigerator", "refrigerator.fill"
            ]
        ),
        (
            "Транспорт",
            "car",
            [
                "car", "car.fill", "car.2", "car.2.fill",
                "car.circle", "car.circle.fill",
                "bus", "bus.fill", "bus.doubledecker", "bus.doubledecker.fill",
                "tram", "tram.fill", "tram.circle", "tram.circle.fill",
                "airplane", "airplane.circle", "airplane.circle.fill",
                "airplane.departure", "airplane.arrival",
                "bicycle", "bicycle.circle", "bicycle.circle.fill",
                "scooter", "scooter.circle",
                "fuelpump", "fuelpump.fill", "fuelpump.circle", "fuelpump.circle.fill",
                "location", "location.fill", "location.circle", "location.circle.fill",
                "location.north", "location.north.fill",
                "location.north.circle", "location.north.circle.fill",
                "map", "map.fill", "map.circle", "map.circle.fill",
                "sailboat", "sailboat.fill", "ferry", "ferry.fill",
                "helmet", "helmet.fill"
            ]
        ),
        (
            "Покупки",
            "cart",
            [
                "cart", "cart.fill", "cart.circle", "cart.circle.fill",
                "cart.badge.plus", "cart.badge.minus",
                "bag", "bag.fill", "bag.circle", "bag.circle.fill",
                "bag.badge.plus", "bag.badge.minus",
                "basket", "basket.fill",
                "creditcard", "creditcard.fill", "creditcard.circle", "creditcard.circle.fill",
                "giftcard", "giftcard.fill",
                "gift", "gift.fill", "gift.circle", "gift.circle.fill",
                "wand.and.stars", "wand.and.rays"
            ]
        ),
        (
            "Дом",
            "house",
            [
                "house", "house.fill", "house.circle", "house.circle.fill",
                "house.lodge", "house.lodge.fill",
                "bed.double", "bed.double.fill", "bed.double.circle", "bed.double.circle.fill",
                "sofa", "sofa.fill",
                "chair", "chair.lounge", "chair.lounge.fill",
                "lamp", "lamp.desk", "lamp.desk.fill", "lamp.table", "lamp.table.fill",
                "lightbulb", "lightbulb.fill", "lightbulb.circle", "lightbulb.circle.fill",
                "lock", "lock.fill", "lock.circle", "lock.circle.fill",
                "lock.open", "lock.open.fill",
                "key", "key.fill",
                "bell", "bell.fill", "bell.circle", "bell.circle.fill",
                "bell.badge", "bell.badge.fill",
                "shower", "shower.fill",
                "bathtub", "bathtub.fill",
                "toilet", "toilet.fill",
                "washer", "washer.fill", "dryer", "dryer.fill"
            ]
        ),
        (
            "Спорт",
            "figure.walk",
            [
                "figure.walk", "figure.run", "figure.hiking", "figure.climbing",
                "figure.yoga", "figure.strengthtraining.traditional",
                "figure.pool.swim", "figure.outdoor.cycle",
                "figure.basketball", "figure.soccer", "figure.tennis",
                "figure.golf", "figure.skiing.downhill",
                "dumbbell", "dumbbell.fill",
                "sportscourt", "sportscourt.fill",
                "tennis.racket", "tennisball", "tennisball.fill",
                "basketball", "basketball.fill", "basketball.circle", "basketball.circle.fill",
                "soccerball", "soccerball.circle", "soccerball.circle.fill",
                "baseball", "baseball.fill", "baseball.circle", "baseball.circle.fill",
                "football", "football.fill", "football.circle", "football.circle.fill",
                "volleyball", "volleyball.fill", "volleyball.circle", "volleyball.circle.fill",
                "trophy", "trophy.fill", "trophy.circle", "trophy.circle.fill"
            ]
        ),
        (
            "Разное",
            "circle",
            [
                "link", "link.circle", "link.circle.fill", "link.badge.plus",
                "network", "personalhotspot", "wifi", "wifi.circle", "wifi.circle.fill",
                "antenna.radiowaves.left.and.right",
                "globe", "globe.americas", "globe.americas.fill",
                "globe.europe.africa", "globe.europe.africa.fill",
                "globe.asia.australia", "globe.asia.australia.fill",
                "hand.thumbsup", "hand.thumbsup.fill", "hand.thumbsup.circle", "hand.thumbsup.circle.fill",
                "hand.thumbsdown", "hand.thumbsdown.fill",
                "hand.raised", "hand.raised.fill", "hand.raised.circle", "hand.raised.circle.fill",
                "hand.wave", "hand.wave.fill",
                "eye", "eye.fill", "eye.circle", "eye.circle.fill",
                "eye.slash", "eye.slash.fill",
                "brain", "brain.head.profile",
                "face.smiling", "face.smiling.fill", "face.smiling.inverse",
                "person", "person.fill", "person.circle", "person.circle.fill",
                "person.2", "person.2.fill", "person.3", "person.3.fill",
                "figure.stand", "figure.wave"
            ]
        ),
        (
            "Фигуры",
            "circle.fill",
            [
                "circle", "circle.fill", "circle.circle", "circle.circle.fill",
                "square", "square.fill", "square.circle", "square.circle.fill",
                "triangle", "triangle.fill", "triangle.circle", "triangle.circle.fill",
                "diamond", "diamond.fill", "diamond.circle", "diamond.circle.fill",
                "hexagon", "hexagon.fill", "octagon", "octagon.fill",
                "rectangle", "rectangle.fill", "capsule", "capsule.fill",
                "oval", "oval.fill", "oval.portrait", "oval.portrait.fill",
                "rhombus", "rhombus.fill",
                "seal", "seal.fill",
                "shield", "shield.fill", "shield.lefthalf.filled",
                "flag", "flag.fill", "flag.circle", "flag.circle.fill",
                "bookmark", "bookmark.fill", "bookmark.circle", "bookmark.circle.fill"
            ]
        ),
        (
            "Стрелки",
            "arrow.up",
            [
                "arrow.up", "arrow.down", "arrow.left", "arrow.right",
                "arrow.up.right", "arrow.down.left", "arrow.up.left", "arrow.down.right",
                "arrow.up.circle", "arrow.up.circle.fill",
                "arrow.down.circle", "arrow.down.circle.fill",
                "arrow.left.circle", "arrow.left.circle.fill",
                "arrow.right.circle", "arrow.right.circle.fill",
                "arrow.triangle.2.circlepath",
                "arrow.clockwise", "arrow.counterclockwise",
                "chevron.up", "chevron.down", "chevron.left", "chevron.right",
                "chevron.up.circle", "chevron.up.circle.fill",
                "chevron.down.circle", "chevron.down.circle.fill",
                "chevron.left.circle", "chevron.left.circle.fill",
                "chevron.right.circle", "chevron.right.circle.fill"
            ]
        ),
    ]

    /// Компактный набор для быстрых мест (элементы папок, компактные диалоги).
    static var essentials: [(name: String, icon: String, icons: [String])] {
        [("Основные", "square.grid.2x2", essentialsIcons)]
    }

    private static let essentialsIcons: [String] = [
        "app.fill", "app", "folder", "folder.fill", "doc", "doc.fill",
        "link", "globe", "gear", "gearshape", "hammer", "wrench",
        "star", "star.fill", "heart", "heart.fill", "bolt", "bolt.fill",
        "flame", "leaf", "book", "book.fill", "graduationcap",
        "briefcase", "gamecontroller", "music.note", "photo", "video",
        "film", "mic", "headphones", "speaker.wave.2", "camera", "camera.fill",
        "envelope", "message", "phone", "paperplane", "calendar", "clock",
        "map", "location", "cloud", "sun.max", "moon", "snowflake",
        "terminal", "safari", "network", "display", "iphone", "ipad",
        "laptopcomputer", "desktopcomputer", "keyboard", "mouse",
        "printer", "externaldrive", "archivebox", "tray", "bubble.left",
        "checklist", "list.bullet", "chart.bar", "creditcard", "banknote",
        "cart", "bag", "gift", "paintbrush", "paintpalette", "scissors",
        "ruler", "pencil", "highlighter", "lock", "lock.open", "key",
        "shield", "eye", "magnifyingglass", "sparkles", "crown", "trophy",
        "flag", "tag", "pin", "bookmark", "wand.and.stars", "puzzlepiece"
    ]

    /// Все значки одной плоской категории — для компактных диалогов.
    static var flat: [(name: String, icon: String, icons: [String])] {
        [("Все значки", "square.grid.2x2", categories.flatMap { $0.icons })]
    }
}

// MARK: - IconPickerView
// Прежний вид: категории слева, значки справа.
// Отличия: страницы листаются целиком (без второй, горизонтальной
// прокрутки — из-за неё часть значков была недостижима), недоступные
// в этой macOS символы скрыты, все переходы анимированы.

struct IconPickerView: View {
    let categories: [(name: String, icon: String, icons: [String])]
    @Binding var selectedIcon: String
    var showsCategories: Bool = true
    /// Высота области со значками.
    var gridHeight: CGFloat = 178
    /// Колонок в сетке значков.
    var columnCount: Int = 9

    @State private var activeCategoryName: String?
    @State private var query = ""
    @State private var page = 0
    @State private var availableIcons: [String: [String]] = [:]
    @State private var hoveredIcon: String?

    private let animations = AnimationCenter.shared
    private let rows = 2

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if showsCategories && !isSearching {
                categoriesColumn
                Divider().background(Color.white.opacity(0.2))
            }
            iconsColumn
        }
        .onAppear(perform: prepareInitialIcons)
        .onChange(of: activeCategoryName) { _, _ in
            withAnimation(animations.spring) { page = 0 }
        }
    }

    // MARK: Левая колонка — категории

    private var categoriesColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Категория")
                .font(.system(size: 11, weight: .semibold))
                .adaptiveTextColor()
                .opacity(0.6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(categories, id: \.name) { category in
                        categoryRow(category)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: gridHeight)
        }
        .frame(width: 140)
    }

    private func categoryRow(_ category: (name: String, icon: String, icons: [String])) -> some View {
        let isActive = category.name == activeCategory?.name

        return Button {
            activeCategoryName = category.name
        } label: {
            HStack(spacing: 7) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(category.name)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.6)
                        .transition(.opacity.combined(with: .offset(x: -3)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.white.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .adaptiveTextColor()
            .opacity(isActive ? 1 : 0.75)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverLift()
    }

    // MARK: Правая колонка — значки

    private var iconsColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            iconsHeader
            iconsGrid
            pageControls
        }
        .frame(maxWidth: .infinity)
    }

    private var iconsHeader: some View {
        HStack(spacing: 8) {
            searchField
                // В компактном режиме плашки выбора нет — поиск занимает всю
                // строку; в полном он ограничен, чтобы не упираться в плашку.
                .frame(maxWidth: showsCategories ? 190 : .infinity)

            Spacer(minLength: 4)

            // Плашка текущего выбора — только в полном режиме (с категориями).
            // В компактном она дублирует подсвеченный значок и выглядит как
            // случайная кнопка, поэтому убрана.
            if showsCategories {
                HStack(spacing: 5) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 13))
                        .adaptiveTextColor()
                        .transition(.scale.combined(with: .opacity))
                    Text(selectedIcon)
                        .font(.system(size: 9, design: .monospaced))
                        .adaptiveTextColor()
                        .opacity(0.55)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                )
                .animation(animations.bouncy, value: selectedIcon)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .adaptiveTextColor()
                .opacity(0.5)
            TextField("Найти значок…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .adaptiveTextColor()
            if !query.isEmpty {
                Button {
                    withAnimation(animations.quick) { query = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        .adaptiveTextColor()
                        .opacity(0.5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
    }

    private var iconsGrid: some View {
        ZStack {
            // Плоская подложка без обводки — только лёгкая группировка плиток.
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.04))

            if pageIcons.isEmpty {
                Text("Значки не найдены")
                    .font(.system(size: 11))
                    .adaptiveTextColor()
                    .opacity(0.5)
                    .animatedAppear()
            } else if isSearching {
                // Результаты поиска могут не поместиться на страницу
                ScrollView(.vertical, showsIndicators: true) {
                    iconGridContent
                }
                .id(pageKey)
                .transition(animations.pageTransition)
            } else {
                iconGridContent
                    .id(pageKey)
                    .transition(animations.pageTransition)
            }
        }
        .frame(height: gridHeight)
        .animation(animations.spring, value: pageKey)
    }

    private var iconGridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 5) {
            ForEach(pageIcons, id: \.self) { icon in
                IconTile(
                    name: icon,
                    isSelected: selectedIcon == icon,
                    isHovered: hoveredIcon == icon
                ) {
                    selectedIcon = icon
                }
                .onHover { hovering in
                    hoveredIcon = hovering ? icon : nil
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var pageControls: some View {
        HStack(spacing: 10) {
            if !isSearching && totalPages > 1 {
                pageArrow(systemName: "chevron.left", enabled: page > 0) {
                    withAnimation(animations.spring) { page -= 1 }
                }

                Text("\(page + 1) / \(totalPages)")
                    .font(.system(size: 10, weight: .medium))
                    .adaptiveTextColor()
                    .opacity(0.55)
                    .monospacedDigit()

                pageArrow(systemName: "chevron.right", enabled: page < totalPages - 1) {
                    withAnimation(animations.spring) { page += 1 }
                }
            } else {
                Text(isSearching
                     ? "Найдено: \(visibleIcons.count)"
                     : "Значков: \(visibleIcons.count)")
                    .font(.system(size: 10))
                    .adaptiveTextColor()
                    .opacity(0.5)
            }

            Spacer()

            Text("недоступные в этой macOS скрыты")
                .font(.system(size: 9))
                .adaptiveTextColor()
                .opacity(0.35)
        }
        .frame(height: 20)
    }

    private func pageArrow(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(enabled ? 0.14 : 0.05))
                )
                .adaptiveTextColor()
                .opacity(enabled ? 0.9 : 0.3)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .hoverLift(enabled)
    }

    // MARK: Данные

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeCategory: (name: String, icon: String, icons: [String])? {
        if let name = activeCategoryName,
           let found = categories.first(where: { $0.name == name }) {
            return found
        }
        return categories.first
    }

    /// Все доступные значки текущего набора (с учётом поиска).
    private var visibleIcons: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            var result: [String] = []
            for category in categories {
                result.append(contentsOf: available(for: category))
            }
            var seen = Set<String>()
            return result
                .filter { $0.localizedCaseInsensitiveContains(trimmed) }
                .filter { seen.insert($0).inserted }
        }

        guard let category = activeCategory else { return [] }
        return available(for: category)
    }

    /// Значки текущей страницы (при поиске — все найденные в прокрутке).
    private var pageIcons: [String] {
        if isSearching { return visibleIcons }
        let perPage = pageSize
        let start = page * perPage
        guard start < visibleIcons.count else { return [] }
        return Array(visibleIcons[start..<min(start + perPage, visibleIcons.count)])
    }

    private var pageSize: Int {
        max(1, columnCount) * rows
    }

    private var totalPages: Int {
        let count = visibleIcons.count
        guard count > 0 else { return 1 }
        return Int(ceil(Double(count) / Double(pageSize)))
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: max(3, columnCount))
    }

    /// Ключ для анимации смены содержимого сетки.
    /// При поиске ключ постоянный — иначе сетка анимировалась бы на каждую букву.
    private var pageKey: String {
        if isSearching { return "search-results" }
        return "\(activeCategory?.name ?? "")-\(page)"
    }

    /// Доступные значки категории (кэшируется).
    private func available(for category: (name: String, icon: String, icons: [String])) -> [String] {
        if let cached = availableIcons[category.name] { return cached }
        let filtered = SFSymbolCatalog.available(category.icons)
        DispatchQueue.main.async {
            availableIcons[category.name] = filtered
        }
        return filtered
    }

    /// Считаем значки только для первой категории — остальные лениво.
    private func prepareInitialIcons() {
        guard activeCategoryName == nil else { return }
        guard let first = categories.first else { return }
        activeCategoryName = first.name
        availableIcons[first.name] = SFSymbolCatalog.available(first.icons)
    }
}

// MARK: - IconTile

struct IconTile: View {
    let name: String
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    private let animations = AnimationCenter.shared

    /// Акцент темы — тот же, что у карточек типов и кнопки «Добавить»,
    /// чтобы выделение значка выглядело единообразно с остальным диалогом.
    private var accentColor: Color { Color(hex: BarXSettings.appearanceAccent) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: name)
                    .font(.system(size: 17))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isSelected ? accentColor.opacity(0.16) :
                                Color.white.opacity(isHovered ? 0.17 : 0.07)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? accentColor :
                                (isHovered ? Color.white.opacity(0.25) : Color.clear),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                    .adaptiveTextColor()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(accentColor)
                        .offset(x: 3, y: -3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isHovered ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(animations.bouncy, value: isSelected)
        .animation(animations.hover, value: isHovered)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.set() }
        }
        .help(name)
    }
}
