//
//  ItemIcon.swift
//  BarX
//
//  Иконка элемента папки/панели: настоящая иконка файла приложения или папки
//  (NSWorkspace), а для ссылок/действий и как запасной вариант — SF-символ
//  из поля `AppItem.icon`. Загрузка асинхронная, масштаб — через
//  `NSImage.resized` (потокобезопасный, рисует через NSBitmapImageRep).
//

import SwiftUI
import AppKit

struct ItemIconView: View {
    let item: AppItem
    /// Слот под иконку в пунктах.
    var size: CGFloat = 20

    @State private var realIcon: NSImage?
    @State private var isLoadingIcon = false

    var body: some View {
        Group {
            if let realIcon {
                Image(nsImage: realIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: item.icon)
                    .font(.system(size: max(size * 0.9, 10)))
                    .adaptiveTextColor()
                    .frame(width: size, height: size)
            }
        }
        .onAppear { loadIcon() }
        .onChange(of: item.path) { _, _ in
            realIcon = nil
            loadIcon()
        }
        .onChange(of: item.useRealIcon) { _, _ in
            realIcon = nil
            loadIcon()
        }
    }

    private func loadIcon() {
        guard item.prefersRealIcon, realIcon == nil, !isLoadingIcon else { return }
        isLoadingIcon = true
        let path = item.path
        // К render подаём изображение в 2 раза крупнее — чтобы на Retina
        // иконка была чёткой, а не размытой.
        let target = NSSize(width: size * 2, height: size * 2)
        DispatchQueue.global(qos: .userInitiated).async {
            let icon = NSWorkspace.shared.icon(forFile: path)
            guard icon.size.width > 0 else {
                DispatchQueue.main.async { isLoadingIcon = false }
                return
            }
            let resized = icon.resized(to: target)
            DispatchQueue.main.async {
                realIcon = resized
                isLoadingIcon = false
            }
        }
    }
}
