import Foundation
import Darwin

struct DiskScanner: Sendable {
    let policy: SafetyPolicy
    let largeFileThreshold: Int64

    init(policy: SafetyPolicy = SafetyPolicy(), largeFileThreshold: Int64 = 1_000_000_000) {
        self.policy = policy
        self.largeFileThreshold = largeFileThreshold
    }

    func scan(_ input: URL, onProgress: @Sendable (ScanProgress) -> Void = { _ in }) throws -> ScanResult {
        let root = CanonicalPath.url(input)
        guard root.isFileURL else { throw ScanError.invalidRoot }
        let values = try root.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw ScanError.invalidRoot }
        var items: [ScanItem] = []
        var skipped = 0
        var scanned = 0
        let rootDevice = try identity(root).device
        onProgress(ScanProgress(scannedCount: 0, currentFolder: root.path))
        let total = try walk(root, root: root, rootDevice: rootDevice, depth: 0, insideProject: false, items: &items, skipped: &skipped, scanned: &scanned, onProgress: onProgress)
        items.sort { $0.bytes > $1.bytes }
        let filesystem = try? FileManager.default.attributesOfFileSystem(forPath: root.path)
        let volumeTotal = (filesystem?[.systemSize] as? NSNumber)?.int64Value
        let volumeFree = (filesystem?[.systemFreeSize] as? NSNumber)?.int64Value
        return ScanResult(root: root, isQuickScan: false, items: items, totalBytes: total, volumeTotalBytes: volumeTotal, volumeFreeBytes: volumeFree, skippedCount: skipped, scannedCount: scanned, scannedAt: Date())
    }

    func scanKnownCaches(onProgress: @Sendable (ScanProgress) -> Void = { _ in }) throws -> ScanResult {
        let root = policy.home
        let rootDevice = try identity(root).device
        var items: [ScanItem] = []
        var skipped = 0
        var scanned = 0
        var total: Int64 = 0
        onProgress(ScanProgress(scannedCount: 0, currentFolder: root.path))
        for location in policy.quickScanLocations {
            try Task<Never, Never>.checkCancellation()
            onProgress(ScanProgress(scannedCount: scanned, currentFolder: location.path))
            let bytes = try walk(location, root: root, rootDevice: rootDevice, depth: 1, insideProject: false, items: &items, skipped: &skipped, scanned: &scanned, onProgress: onProgress)
            let addition = total.addingReportingOverflow(bytes)
            total = addition.overflow ? Int64.max : addition.partialValue
        }
        items.sort { $0.bytes > $1.bytes }
        let filesystem = try? FileManager.default.attributesOfFileSystem(forPath: root.path)
        return ScanResult(root: root, isQuickScan: true, items: items, totalBytes: total,
                          volumeTotalBytes: (filesystem?[.systemSize] as? NSNumber)?.int64Value,
                          volumeFreeBytes: (filesystem?[.systemFreeSize] as? NSNumber)?.int64Value,
                          skippedCount: skipped, scannedCount: scanned, scannedAt: Date())
    }

    private func walk(_ url: URL, root: URL, rootDevice: UInt64, depth: Int, insideProject: Bool, items: inout [ScanItem], skipped: inout Int, scanned: inout Int, onProgress: @Sendable (ScanProgress) -> Void) throws -> Int64 {
        try Task<Never, Never>.checkCancellation()
        scanned += 1
        if scanned.isMultiple(of: 200) {
            onProgress(ScanProgress(scannedCount: scanned, currentFolder: url.deletingLastPathComponent().path))
        }
        guard let metadata = try? metadata(url) else { skipped += 1; return 0 }
        if metadata.identity.device != rootDevice || metadata.isLink { skipped += 1; return 0 }
        let allowedProtectedChildren = policy.allowedChildren(ofProtectedRoot: url)
        if policy.isProtected(url), allowedProtectedChildren == nil {
            skipped += 1
            return 0
        }

        if !metadata.isDirectory {
            if policy.isProject(url), !insideProject, url != root, metadata.size >= 50_000_000 {
                items.append(item(url, kind: .project, bytes: metadata.size, note: "工程文件；只提示占用，不提供删除操作。", canTrash: false, identity: metadata.identity))
            } else if !insideProject, url != root,
                      metadata.size >= largeFileThreshold || (metadata.size >= 100_000_000 && ["dmg", "pkg"].contains(url.pathExtension.lowercased())) {
                let installer = ["dmg", "pkg"].contains(url.pathExtension.lowercased())
                let note = installer ? "安装包可能是旧版本，也可能是保留的交付资料；只提示占用，请在 Finder 中自行判断。" : "大文件仅提示；请在 Finder 中自行决定是否处理。"
                items.append(item(url, kind: .largeFile, bytes: metadata.size, note: note, canTrash: false, identity: metadata.identity))
            }
            return metadata.size
        }

        let project = policy.isProject(url)
        let cacheNote = !insideProject ? policy.cacheDescription(for: url, isDirectory: true) : nil
        let reviewNote = policy.reviewDescription(for: url, isDirectory: true)
        let children: [URL]
        if let allowedProtectedChildren {
            children = allowedProtectedChildren.filter { FileManager.default.fileExists(atPath: $0.path) }
            skipped += 1
        } else {
            do {
                children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            } catch {
                skipped += 1
                return 0
            }
        }
        var sum: Int64 = 0
        for child in children {
            let value = try walk(child, root: root, rootDevice: rootDevice, depth: depth + 1, insideProject: insideProject || project, items: &items, skipped: &skipped, scanned: &scanned, onProgress: onProgress)
            let addition = sum.addingReportingOverflow(value)
            sum = addition.overflow ? Int64.max : addition.partialValue
        }
        if url != root {
            if project {
                let note = url.lastPathComponent == "Figma" ? "Figma 本地数据可能包含未同步的离线改动；只显示占用，请在 Figma 内处理。" : "项目工程或应用数据；只显示占用，不提供删除操作。"
                items.append(item(url, kind: .project, bytes: sum, note: note, canTrash: false, identity: metadata.identity))
            } else if let reviewNote {
                if url.path == policy.home.appending(path: "Library/Application Support/Shandianshuo/recordings").path {
                    let old = oldRecordingSummary(at: url)
                    if old.count > 0 {
                        items.append(item(url, kind: .review, bytes: old.bytes, note: "超过 15 天的录音 \(old.count) 条。\(reviewNote)", canTrash: false, identity: metadata.identity))
                    }
                } else {
                    items.append(item(url, kind: .review, bytes: sum, note: reviewNote, canTrash: false, identity: metadata.identity))
                }
            } else if let cacheNote {
                // Hide descendants of a suggested cache to avoid overlapping actions.
                items.removeAll { $0.url.path.hasPrefix(url.path + "/") }
                items.append(item(url, kind: .cache, bytes: sum, note: cacheNote, canTrash: true, identity: metadata.identity))
            } else if depth == 1 {
                items.append(item(url, kind: .folder, bytes: sum, note: "目录总量；仅供定位，不提供删除操作。", canTrash: false, identity: metadata.identity))
            }
        }
        return sum
    }

    private func item(_ url: URL, kind: ScanKind, bytes: Int64, note: String, canTrash: Bool, identity: FileIdentity) -> ScanItem {
        ScanItem(id: url, url: url, kind: kind, risk: policy.risk(for: url, kind: kind), bytes: bytes, note: note, canTrash: canTrash, identity: identity)
    }

    private func oldRecordingSummary(at root: URL) -> (count: Int, bytes: Int64) {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]) else { return (0, 0) }
        let cutoff = Date().addingTimeInterval(-15 * 24 * 60 * 60)
        var count = 0
        var bytes: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]),
                  values.isRegularFile == true, let date = values.contentModificationDate, date < cutoff else { continue }
            count += 1
            let addition = bytes.addingReportingOverflow(Int64(values.fileSize ?? 0))
            bytes = addition.overflow ? Int64.max : addition.partialValue
        }
        return (count, bytes)
    }

    private func metadata(_ url: URL) throws -> (identity: FileIdentity, isDirectory: Bool, isLink: Bool, size: Int64) {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw ScanError.unreadable(url) }
        let type = info.st_mode & mode_t(S_IFMT)
        return (FileIdentity(device: UInt64(info.st_dev), inode: UInt64(info.st_ino)), type == mode_t(S_IFDIR), type == mode_t(S_IFLNK), max(0, info.st_size))
    }

    private func identity(_ url: URL) throws -> FileIdentity { try metadata(url).identity }
}

enum ScanError: LocalizedError {
    case invalidRoot
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .invalidRoot: "请选择一个本地文件夹。"
        case .unreadable(let url): "无法读取：\(url.path)"
        }
    }
}
