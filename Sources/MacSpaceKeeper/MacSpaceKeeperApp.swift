import AppKit
import SwiftUI

@main
struct MacSpaceKeeperApp: App {
    @StateObject private var store = ScanStore()

    init() {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup("Mac 清理管家") {
            MainView(store: store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("扫描") {
                Button("选择文件夹…") { store.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("重新扫描") { store.scan() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
