import Foundation
import Darwin

struct TrashService {
    let policy: SafetyPolicy

    init(policy: SafetyPolicy = SafetyPolicy()) { self.policy = policy }

    /// Moves a regenerable cache, or an item the user confirmed (`SafetyPolicy.decisionNote`). Everything else is refused.
    func moveToTrash(_ item: ScanItem) throws -> URL {
        let url = item.url.standardizedFileURL
        guard !policy.isProtected(url) else { throw TrashError.notEligible }
        let decided = policy.decisionNote(for: item) != nil
        if !decided {
            guard item.kind == .cache, item.canTrash, policy.cacheDescription(for: url, isDirectory: true) != nil else { throw TrashError.notEligible }
        }
        // Caches and decided folders are directories; only a decided large file may be a regular file.
        let isDirectory = item.kind != .largeFile
        let expectedType = isDirectory ? mode_t(S_IFDIR) : mode_t(S_IFREG)
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw TrashError.changed }
        let current = FileIdentity(device: UInt64(info.st_dev), inode: UInt64(info.st_ino))
        guard current == item.identity, (info.st_mode & mode_t(S_IFMT)) == expectedType else { throw TrashError.changed }
        try Self.ensureUnused(url, isDirectory: isDirectory)
        // The usage check can take time; revalidate identity immediately before moving.
        guard lstat(url.path, &info) == 0,
              FileIdentity(device: UInt64(info.st_dev), inode: UInt64(info.st_ino)) == item.identity,
              (info.st_mode & mode_t(S_IFMT)) == expectedType else { throw TrashError.changed }
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL? ?? url
    }

    /// Fail closed when the OS cannot establish that no process has files open here.
    static func ensureUnused(_ url: URL, isDirectory: Bool = true) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-n", "-P", "-t"] + (isDirectory ? ["+D", url.path] : [url.path])
        let output = Pipe()
        process.standardOutput = output
        let errors = Pipe()
        process.standardError = errors
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { throw TrashError.usageUnknown }
        guard finished.wait(timeout: .now() + 8) == .success else {
            process.terminate()
            throw TrashError.usageUnknown
        }
        let openFiles = output.fileHandleForReading.readDataToEndOfFile()
        let diagnostics = errors.fileHandleForReading.readDataToEndOfFile()
        // lsof may return 1 while still reporting matching PIDs on macOS.
        if !openFiles.isEmpty || process.terminationStatus == 0 { throw TrashError.inUse }
        guard process.terminationStatus == 1, diagnostics.isEmpty else { throw TrashError.usageUnknown }
    }

    /// Short Chinese reason for the cleanup report; raw Foundation messages are long and English.
    static func reason(for error: Error) -> String {
        if let trashError = error as? TrashError { return trashError.errorDescription ?? "未处理" }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteNoPermissionError, NSFileReadNoPermissionError: return "系统或其他账户的文件夹，没有权限移动"
            case NSFileNoSuchFileError: return "已不存在"
            default: break
            }
        }
        if nsError.domain == NSPOSIXErrorDomain, [Int(EPERM), Int(EACCES)].contains(nsError.code) {
            return "系统或其他账户的文件夹，没有权限移动"
        }
        return "移动失败"
    }
}

enum TrashError: LocalizedError {
    case notEligible
    case changed
    case inUse
    case usageUnknown

    var errorDescription: String? {
        switch self {
        case .notEligible: "不在可清理范围"
        case .changed: "扫描后有变化，请重新扫描"
        case .inUse: "正在使用，退出相关应用后再清一次"
        case .usageUnknown: "无法确认是否正在使用，已跳过"
        }
    }
}
