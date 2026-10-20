import AppKit

/// Human-readable title and icon for a scan item. Raw folder names like `_cacache`
/// or `com.tencent.meeting.UpdateServer` stay visible as the subtitle.
@MainActor
enum ItemPresentation {
    struct Info {
        let title: String
        /// App icon when the item belongs to an installed app.
        let icon: NSImage?
        /// SF Symbol used when there is no app icon.
        let symbol: String
    }

    private static var cache: [URL: Info] = [:]
    private static var appIcons: [String: NSImage] = [:]

    /// Folder name → (title, symbol) for tool caches that have no app of their own.
    private static let known: [String: (String, String)] = [
        "_cacache": ("npm 缓存", "shippingbox.fill"),
        "uv": ("uv 包缓存", "shippingbox.fill"),
        "pip": ("pip 包缓存", "shippingbox.fill"),
        "Homebrew": ("Homebrew 下载", "mug.fill"),
        "org.swift.swiftpm": ("Swift 包缓存", "swift"),
        ".build": ("Swift 构建产物", "swift"),
        "__pycache__": ("Python 缓存", "chevron.left.forwardslash.chevron.right"),
        ".pytest_cache": ("pytest 缓存", "chevron.left.forwardslash.chevron.right"),
        ".mypy_cache": ("mypy 缓存", "chevron.left.forwardslash.chevron.right"),
        "node_modules": ("Node 依赖", "shippingbox.fill"),
        "recordings": ("闪电说旧录音", "waveform"),
        "Service Worker": ("Notion 离线缓存", "doc.text.fill")
    ]

    /// Folders whose name is not the app's bundle id or .app name.
    private static let aliases: [String: (bundleID: String, title: String)] = [
        "LarkShell": ("com.electron.lark", "飞书"),
        "Google": ("com.google.Chrome", "Google Chrome"),
        "Codex": ("com.openai.codex", "Codex"),
        "codex-runtimes": ("com.openai.codex", "Codex 运行时"),
        "Service Worker": ("notion.id", "Notion 离线缓存")
    ]

    static func info(for item: ScanItem) -> Info {
        if let hit = cache[item.id] { return hit }
        let value = resolve(item)
        cache[item.id] = value
        return value
    }

    /// Short part name inside a creative app group, e.g. "磁盘缓存".
    static func partTitle(for item: ScanItem) -> String {
        let name = item.name
        if name.hasPrefix("Disk Cache") { return "磁盘缓存" }
        if name.hasPrefix("Media Cache") { return "媒体缓存" }
        if name == "Peak Files" { return "音频峰值文件" }
        if name == "Render Files" { return "渲染文件 · \(item.url.deletingLastPathComponent().lastPathComponent)" }
        if name == "CacheClip" { return "渲染缓存 CacheClip" }
        return "应用缓存"
    }

    static func appIcon(bundleID: String) -> NSImage? {
        if let hit = appIcons[bundleID] { return hit }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons[bundleID] = icon
        return icon
    }

    private static func resolve(_ item: ScanItem) -> Info {
        let name = item.name
        if let app = CreativeApp.of(item) {
            return Info(title: "\(app.title) \(partTitle(for: item))", icon: appIcon(bundleID: app.bundleID), symbol: "film.stack")
        }
        if let alias = aliases[name], let icon = appIcon(bundleID: alias.bundleID) {
            return Info(title: alias.title, icon: icon, symbol: "app.fill")
        }
        if item.kind == .largeFile || item.kind == .project {
            // Real document icons (Keynote, PPT, PSD, Final Cut library…) read better than a generic glyph.
            return Info(title: name, icon: NSWorkspace.shared.icon(forFile: item.url.path), symbol: symbol(for: item))
        }
        if item.kind == .cache, let app = application(for: name) {
            let title = FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
            return Info(title: title, icon: NSWorkspace.shared.icon(forFile: app.path), symbol: "app.fill")
        }
        if let (title, symbol) = known[name] { return Info(title: title, icon: nil, symbol: symbol) }
        if name.hasSuffix("-updater") {
            return Info(title: "\(name.dropLast("-updater".count)) 更新包", icon: nil, symbol: "arrow.down.circle.fill")
        }
        return Info(title: name, icon: nil, symbol: symbol(for: item))
    }

    private static func symbol(for item: ScanItem) -> String {
        switch item.kind {
        case .cache: "arrow.triangle.2.circlepath"
        case .project: "film.stack.fill"
        case .largeFile: ["dmg", "pkg"].contains(item.url.pathExtension.lowercased()) ? "externaldrive.fill" : "doc.fill"
        case .review: "hand.raised.fill"
        case .folder: "folder.fill"
        }
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
        // Plain names like "Microsoft Edge".
        for directory in ["/Applications", NSHomeDirectory() + "/Applications"] {
            let url = URL(fileURLWithPath: directory).appending(path: name + ".app")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}
