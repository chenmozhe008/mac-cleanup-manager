import AppKit

/// Human-readable title and app icon for a scan item. Raw folder names like `_cacache`
/// or `com.tencent.meeting.UpdateServer` stay visible as the subtitle.
@MainActor
enum ItemPresentation {
    struct Info {
        let title: String
        let icon: NSImage?
    }

    private static var cache: [URL: Info] = [:]

    private static let known: [String: String] = [
        "_cacache": "npm 缓存",
        "codex-runtimes": "Codex 运行时",
        "uv": "uv 包缓存",
        "pip": "pip 包缓存",
        "Homebrew": "Homebrew 下载",
        "org.swift.swiftpm": "Swift 包缓存",
        ".build": "Swift 构建产物",
        "__pycache__": "Python 缓存",
        ".pytest_cache": "pytest 缓存",
        ".mypy_cache": "mypy 缓存",
        "node_modules": "Node 依赖",
        "Render Files": "Final Cut 渲染文件",
        "CacheClip": "DaVinci 渲染缓存",
        "Media Cache Files": "Adobe 媒体缓存",
        "Media Cache": "Adobe 媒体缓存",
        "Peak Files": "Adobe 音频峰值",
        "recordings": "闪电说录音",
        "Service Worker": "Notion 离线缓存"
    ]

    /// Cache folders whose name is not the app's bundle id or .app name.
    private static let aliases: [String: (bundleID: String, title: String?)] = [
        "LarkShell": ("com.electron.lark", nil),
        "Google": ("com.google.Chrome", nil),
        "Codex": ("com.openai.codex", "Codex")
    ]

    static func info(for item: ScanItem) -> Info {
        if let hit = cache[item.id] { return hit }
        let value = resolve(item)
        cache[item.id] = value
        return value
    }

    private static func resolve(_ item: ScanItem) -> Info {
        let name = item.name
        if let alias = aliases[name], let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: alias.bundleID) {
            let title = alias.title ?? FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
            return Info(title: title, icon: NSWorkspace.shared.icon(forFile: app.path))
        }
        if item.kind == .cache || item.kind == .folder, let app = application(for: name) {
            let title = FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
            return Info(title: title, icon: NSWorkspace.shared.icon(forFile: app.path))
        }
        if let friendly = known[name] { return Info(title: friendly, icon: nil) }
        if name.hasPrefix("Disk Cache") { return Info(title: "After Effects 磁盘缓存", icon: nil) }
        if name.hasSuffix("-updater") {
            return Info(title: "\(name.dropLast("-updater".count)) 更新包", icon: nil)
        }
        return Info(title: name, icon: nil)
    }

    private static func application(for name: String) -> URL? {
        // Bundle-id style folders: try the full id, then drop trailing parts
        // (com.tencent.meeting.UpdateServer → com.tencent.meeting).
        if name.contains("."), !name.hasPrefix(".") {
            var parts = name.split(separator: ".").map(String.init)
            while parts.count >= 3 {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: parts.joined(separator: ".")) { return url }
                parts.removeLast()
            }
            return nil
        }
        // Plain names like "Codex" or "Microsoft Edge".
        for directory in ["/Applications", NSHomeDirectory() + "/Applications"] {
            let url = URL(fileURLWithPath: directory).appending(path: name + ".app")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}
