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
            return "项目依赖目录；重建可能耗时，且可能影响当前工程。只提示占用，由你在工程内决定。"
        }
        if path == home.appending(path: "Library/Application Support/Shandianshuo/recordings").path {
            return "闪电说录音；只统计超过 15 天的旧录音，仍需你逐项决定。"
        }
        if path == home.appending(path: "Library/Application Support/Notion/Partitions/notion/Service Worker").path {
            return "Notion 离线缓存可能含尚未同步的改动；只提示占用，请在 Notion 确认同步状态后处理。"
        }
        if url.lastPathComponent == "Render Files", path.contains(".fcpbundle/") {
            return "Final Cut 渲染文件；请在 Final Cut 中选中资源库，使用“文件 → 删除已生成的资源库文件”，优先选择仅删除未使用的渲染文件。这里不直接清理。"
        }
        if url.lastPathComponent == "CacheClip" {
            return "DaVinci Resolve 渲染缓存；请先确认对应工程和缓存位置，再在 Resolve 中使用删除渲染缓存功能。这里不直接清理。"
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
                return "Blender 应用缓存；不含 .blend 工程和用户设置，重新打开时可能再生成。"
            }
            if name == "Homebrew" {
                return "Homebrew 下载缓存；旧版本清理请先在 Homebrew 中预览，应用不会执行 brew cleanup。"
            }
            return "应用缓存；下次使用时可能重新生成，清理前请退出对应应用。"
        }
        let appSupportCaches = home.appending(path: "Library/Application Support/Caches").path
        if CanonicalPath.url(url.deletingLastPathComponent()).path == appSupportCaches,
           name.hasSuffix("-updater") {
            return "应用更新下载缓存；下次更新可能重新下载。"
        }

        let directCaches = [
            (".cache/codex-runtimes", "Codex 运行时缓存；下次使用可能重新下载。"),
            (".cache/uv", "uv 包缓存；下次安装依赖可能重新下载。"),
            (".cache/pip", "pip 包缓存；下次安装依赖可能重新下载。"),
            (".npm/_cacache", "npm 包缓存；下次安装依赖可能重新下载。"),
            ("Library/Application Support/Codex/Cache", "Codex 界面缓存；请退出 Codex 后再处理。"),
            ("Library/Application Support/Codex/Code Cache", "Codex 代码缓存；请退出 Codex 后再处理。"),
            ("Library/Application Support/Adobe/Common/Media Cache Files", "Adobe 媒体缓存；请退出 Adobe 应用后再处理。"),
            ("Library/Application Support/Adobe/Common/Media Cache", "Adobe 媒体缓存；请退出 Adobe 应用后再处理。"),
            ("Library/Application Support/Adobe/Common/Peak Files", "Adobe 音频峰值缓存；请退出 Adobe 应用后再处理。"),
            ("Library/Application Support/Notion/Partitions/notion/Cache", "Notion 浏览器缓存；请退出 Notion 后再处理。"),
            ("Library/Application Support/Notion/Partitions/notion/Code Cache", "Notion 代码缓存；请退出 Notion 后再处理。")
        ]
        if let match = directCaches.first(where: { path == home.appending(path: $0.0).path }) {
            return match.1
        }
        if name.hasPrefix("Disk Cache"), path.contains("/Library/Caches/Adobe/After Effects/") {
            return "After Effects 磁盘缓存；请退出 AE 后处理，也可在 AE 设置中清空缓存。"
        }

        // Build artifacts inside projects. The source and the project root stay untouched.
        if name == ".build", FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appending(path: "Package.swift").path) {
            return "Swift 构建产物；下次构建会重新生成。"
        }
        if ["__pycache__", ".pytest_cache", ".mypy_cache"].contains(name) {
            return "开发工具生成的缓存；运行时会重新生成。"
        }
        if name == "cache", url.deletingLastPathComponent().lastPathComponent == ".next" {
            return "Next.js 构建缓存；下次构建会重新生成。"
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
