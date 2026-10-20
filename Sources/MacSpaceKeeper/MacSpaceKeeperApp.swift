import AppKit
import SwiftUI

@main
struct MacSpaceKeeperApp: App {
    @StateObject private var store = ScanStore()

    // The Dock uses the bundle's AppIcon.icns. Setting applicationIconImage at runtime
    // bypasses the system squircle mask and shows a raw square.

    var body: some Scene {
        WindowGroup("Mac 清理管家") {
            MainView(store: store)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button("关于 Mac 清理管家") { store.showAbout = true }
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
