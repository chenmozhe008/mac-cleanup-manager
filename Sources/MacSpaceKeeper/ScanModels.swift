import Foundation

enum ScanKind: String, Codable, Sendable {
    case cache = "可再生缓存"
    case project = "项目或资源库"
    case largeFile = "大文件"
    case review = "在原软件处理"
    case folder = "文件夹"
}

enum ScanRisk: String, Codable, Sendable {
    case a = "A · 可再生缓存"
    case b = "B · 应用缓存"
    case c = "C · 人工判断"
}

struct ScanItem: Identifiable, Codable, Sendable {
    let id: URL
    let url: URL
    let kind: ScanKind
    let risk: ScanRisk
    let bytes: Int64
    let note: String
    let canTrash: Bool
    let identity: FileIdentity

    var name: String { url.lastPathComponent }
}

struct FileIdentity: Equatable, Codable, Sendable {
    let device: UInt64
    let inode: UInt64
}

struct ScanResult: Codable, Sendable {
    let root: URL
    let isQuickScan: Bool
    let items: [ScanItem]
    let totalBytes: Int64
    let volumeTotalBytes: Int64?
    let volumeFreeBytes: Int64?
    let skippedCount: Int
    let scannedCount: Int
    let scannedAt: Date
    /// WeChat / WeCom data size, measured read-only and never offered for cleanup.
    var chatApps: [ChatAppUsage] = []
}

struct ChatAppUsage: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    /// nil when macOS denied reading the app's data (needs Full Disk Access).
    let bytes: Int64?
}

struct CleanupReport: Sendable {
    struct Failure: Sendable, Identifiable {
        let id: URL
        let name: String
        let reason: String
    }

    let movedCount: Int
    let movedBytes: Int64
    let failures: [Failure]
}

struct ScanProgress: Sendable {
    let scannedCount: Int
    let currentFolder: String
}

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        if bytes == 0 { return "0 B" }
        if bytes < 1_000 { return "< 1 KB" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
