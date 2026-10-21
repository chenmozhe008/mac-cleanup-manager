import AppKit
import SwiftUI

@main
struct QingoApp: App {
    @StateObject private var store = ScanStore()

    init() {
        LegacyMigration.run()
    }

    // The Dock uses the bundle's AppIcon.icns. Setting applicationIconImage at runtime
    // bypasses the system squircle mask and shows a raw square.

    var body: some Scene {
        WindowGroup("小清 Mac 清理工具") {
            MainView(store: store)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button("关于小清") { store.showAbout = true }
            }
            CommandMenu("外观") {
                Picker("外观", selection: $store.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
            }
            CommandMenu("扫描") {
                Button("选择文件夹…") { store.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("重新扫描") { store.scan() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
