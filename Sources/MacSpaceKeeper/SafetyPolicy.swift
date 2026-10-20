import Foundation

struct SafetyPolicy: Sendable {
    let home: URL
    let protectedRoots: [URL]
    let extraProtectedRoots: [URL]

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, extraProtected: [URL] = []) {
        let canonicalHome = CanonicalPath.url(home)
        self.home = canonicalHome
        self.extraProtectedRoots = extraProtected.map(CanonicalPath.url)
        let names = [
            "Library/Application Support/RecordingInbox",
            "Library/Application Support/LarkShell",
            "Library/Application Support/Codex",
            "Library/Application Support/Shandianshuo",
            "Library/Containers/com.tencent.xinWeChat",
            "Library/Containers/com.tencent.WeWorkMac",
            "Library/Caches/ms-playwright",
            ".cache/whisper",
            "Library/Developer/Xcode",
            ".ssh", ".aws", ".codex", ".Trash",
            "Coding/skills-backup"
        ]
        protectedRoots = names.map { canonicalHome.appending(path: $0) }
            + extraProtectedRoots
    }

    func isProtected(_ url: URL) -> Bool {
        let path = CanonicalPath.url(url).path
        if extraProtectedRoots.contains(where: { path == $0.path || path.hasPrefix($0.path + "/") }) { return true }
        let codexCache = ["Library/Application Support/Codex/Cache", "Library/Application Support/Codex/Code Cache",
                          "Library/Application Support/Shandianshuo/recordings"]
            .map { home.appending(path: $0).path }
        if codexCache.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { return false }
        return protectedRoots.contains { protected in
            path == protected.path || path.hasPrefix(protected.path + "/")
        }
    }

    func allowedChildren(ofProtectedRoot url: URL) -> [URL]? {
        let path = CanonicalPath.url(url).path
        if extraProtectedRoots.contains(where: { path == $0.path || path.hasPrefix($0.path + "/") }) { return nil }
        if path == home.appending(path: "Library/Application Support/Codex").path {
            return ["Cache", "Code Cache"].map { url.appending(path: $0) }
        }
        if path == home.appending(path: "Library/Application Support/Shandianshuo").path {
            return [url.appending(path: "recordings")]
        }
        return nil
    }

    func isProject(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ["fcpbundle", "xcodeproj", "xcworkspace", "logicx", "band", "als",
            "aep", "aepx", "blend", "blend1", "blend2", "drp", "dra", "fig"].contains(ext) {
            return true
        }
        let path = CanonicalPath.url(url).path
        return ["Library/Application Support/Figma", "Library/Application Support/Blender",
                "Library/Application Support/Blackmagic Design/DaVinci Resolve"]
            .contains { path == home.appending(path: $0).path }
    }

    func reviewDescription(for url: URL, isDirectory: Bool) -> String? {
        guard isDirectory else { return nil }
        let path = CanonicalPath.url(url).path
        // Only the outermost node_modules; nested ones are already counted inside it.
        if url.lastPathComponent == "node_modules", hasNodeManifest(near: url),
           !url.deletingLastPathComponent().path.contains("/node_modules") {
            return "这是项目的依赖文件夹。删掉后要重新安装，可能影响正在做的工程，所以这里只显示占用，由你在工程里决定。"
        }
        if path == home.appending(path: "Library/Application Support/Shandianshuo/recordings").path {
            return "闪电说的录音。这里只统计超过 15 天的旧录音，删不删由你逐条决定。"
        }
        if path == home.appending(path: "Library/Application Support/Notion/Partitions/notion/Service Worker").path {
            return "Notion 的离线缓存可能包含还没同步的改动。这里只显示占用，请先在 Notion 里确认已经同步，再自行处理。"
        }
        if url.lastPathComponent == "Render Files", path.contains(".fcpbundle/") {
            return "Final Cut 的渲染文件。请在 Final Cut 中选中资源库，选择「文件 → 删除已生成的资源库文件」，建议只删除未使用的渲染文件。这里不直接清理。"
        }
        if url.lastPathComponent == "CacheClip" {
            return "达芬奇的渲染缓存。请先确认对应的工程和缓存位置，再在达芬奇里用「删除渲染缓存」清理。这里不直接清理。"
        }
        return nil
    }

    func cacheDescription(for url: URL, isDirectory: Bool) -> String? {
        guard isDirectory, !isProtected(url), !isProject(url) else { return nil }
        let name = url.lastPathComponent
        let path = CanonicalPath.url(url).path

        // Library/Caches is a cache namespace, but only its direct children become actions.
        let libraryCaches = home.appending(path: "Library/Caches").path
        if CanonicalPath.url(url.deletingLastPathComponent()).path == libraryCaches {
            if name.hasPrefix("com.apple.") || ["GeoServices", "SharedImageCache", "OTFileCache", "CloudKit", "FamilyCircle", "familycircled"].contains(name) {
                return nil
            }
            if name == "Adobe" {
                return nil
            }
            if name == "Blender" {
                return "Blender 的应用缓存，不包含 .blend 工程和用户设置，下次打开时会重新生成。"
            }
            if name == "Homebrew" {
                return "Homebrew 的下载缓存。如果要清理旧版本，请先在 Homebrew 里预览，本应用不会运行 brew cleanup。"
            }
            return "应用缓存，下次使用时会重新生成。清理前请先退出对应的应用。"
        }
        let appSupportCaches = home.appending(path: "Library/Application Support/Caches").path
        if CanonicalPath.url(url.deletingLastPathComponent()).path == appSupportCaches,
           name.hasSuffix("-updater") {
            return "应用更新时下载的安装包，下次更新时可能需要重新下载。"
        }

        let directCaches = [
            (".cache/codex-runtimes", "Codex 的运行时缓存，下次使用时可能需要重新下载。"),
            (".cache/uv", "uv 的包缓存，下次安装依赖时可能需要重新下载。"),
            (".cache/pip", "pip 的包缓存，下次安装依赖时可能需要重新下载。"),
            (".npm/_cacache", "npm 的包缓存，下次安装依赖时可能需要重新下载。"),
            ("Library/Application Support/Codex/Cache", "Codex 的界面缓存。清理前请先退出 Codex。"),
            ("Library/Application Support/Codex/Code Cache", "Codex 的代码缓存。清理前请先退出 Codex。"),
            ("Library/Application Support/Adobe/Common/Media Cache Files", "Adobe 的媒体缓存。清理前请先退出 Adobe 的应用。"),
            ("Library/Application Support/Adobe/Common/Media Cache", "Adobe 的媒体缓存。清理前请先退出 Adobe 的应用。"),
            ("Library/Application Support/Adobe/Common/Peak Files", "Adobe 的音频峰值缓存。清理前请先退出 Adobe 的应用。"),
            ("Library/Application Support/Notion/Partitions/notion/Cache", "Notion 的浏览器缓存。清理前请先退出 Notion。"),
            ("Library/Application Support/Notion/Partitions/notion/Code Cache", "Notion 的代码缓存。清理前请先退出 Notion。")
        ]
        if let match = directCaches.first(where: { path == home.appending(path: $0.0).path }) {
            return match.1
        }
        if name.hasPrefix("Disk Cache"), path.contains("/Library/Caches/Adobe/After Effects/") {
            return "After Effects 的磁盘缓存。清理前请先退出 AE，也可以在 AE 的设置里清空。"
        }

        // Build artifacts inside projects. The source and the project root stay untouched.
        if name == ".build", FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appending(path: "Package.swift").path) {
            return "Swift 的构建产物，下次构建时会重新生成。"
        }
        if ["__pycache__", ".pytest_cache", ".mypy_cache"].contains(name) {
            return "开发工具生成的缓存，运行时会重新生成。"
        }
        if name == "cache", url.deletingLastPathComponent().lastPathComponent == ".next" {
            return "Next.js 的构建缓存，下次构建时会重新生成。"
        }
        // Never infer that arbitrary folders named Cache inside a bundle are safe.
        if path.contains(".fcpbundle/") { return nil }
        return nil
    }

    var quickScanLocations: [URL] {
        let libraryCaches = home.appending(path: "Library/Caches")
        let cacheChildren = (try? FileManager.default.contentsOfDirectory(at: libraryCaches, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let extra = [
            ".cache/codex-runtimes", ".cache/uv", ".cache/pip", ".npm/_cacache",
            "Library/Application Support/Codex/Cache", "Library/Application Support/Codex/Code Cache",
            "Library/Application Support/Adobe/Common/Media Cache Files",
            "Library/Application Support/Adobe/Common/Media Cache",
            "Library/Application Support/Adobe/Common/Peak Files",
            "Library/Application Support/Notion/Partitions/notion/Cache",
            "Library/Application Support/Notion/Partitions/notion/Code Cache",
            "Library/Application Support/Notion/Partitions/notion/Service Worker"
        ].map { home.appending(path: $0) }
        let aeRoot = home.appending(path: "Library/Caches/Adobe/After Effects")
        let aeVersions = (try? FileManager.default.contentsOfDirectory(at: aeRoot, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let aeCaches = aeVersions.flatMap {
            (try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        }.filter { $0.lastPathComponent.hasPrefix("Disk Cache") }
        let updaterRoot = home.appending(path: "Library/Application Support/Caches")
        let updaters = (try? FileManager.default.contentsOfDirectory(at: updaterRoot, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let recordings = home.appending(path: "Library/Application Support/Shandianshuo/recordings")
        return (cacheChildren + extra + aeCaches + updaters + [recordings]).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true &&
                (cacheDescription(for: $0, isDirectory: true) != nil || reviewDescription(for: $0, isDirectory: true) != nil)
        }
    }

    func risk(for url: URL, kind: ScanKind) -> ScanRisk {
        guard kind == .cache else { return .c }
        let path = CanonicalPath.url(url).path
        let relative = path.hasPrefix(home.path + "/") ? String(path.dropFirst(home.path.count + 1)) : ""
        if relative.hasPrefix(".cache/") || relative == ".npm/_cacache" ||
            (relative.hasPrefix("Library/Application Support/Caches/") && relative.hasSuffix("-updater")) ||
            relative == "Library/Caches/Homebrew" ||
            relative.hasPrefix("Library/Application Support/Adobe/Common/") ||
            relative.hasPrefix("Library/Caches/Adobe/After Effects/") {
            return .a
        }
        // Build artifacts and tool caches regenerate on the next build/run; no app needs quitting.
        let name = url.lastPathComponent
        if [".build", "__pycache__", ".pytest_cache", ".mypy_cache"].contains(name) ||
            (name == "cache" && url.deletingLastPathComponent().lastPathComponent == ".next") {
            return .a
        }
        return .b
    }

    private func hasNodeManifest(near url: URL) -> Bool {
        let parent = url.deletingLastPathComponent()
        return FileManager.default.fileExists(atPath: parent.appending(path: "package.json").path)
    }
}
