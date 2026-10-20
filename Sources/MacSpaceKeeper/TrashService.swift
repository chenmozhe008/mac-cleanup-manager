import Foundation
import Darwin

struct TrashService {
    let policy: SafetyPolicy

    init(policy: SafetyPolicy = SafetyPolicy()) { self.policy = policy }

    func moveToTrash(_ item: ScanItem) throws -> URL {
        guard item.kind == .cache, item.canTrash else { throw TrashError.notEligible }
        let url = item.url.standardizedFileURL
        guard !policy.isProtected(url), policy.cacheDescription(for: url, isDirectory: true) != nil else { throw TrashError.notEligible }
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw TrashError.changed }
        let current = FileIdentity(device: UInt64(info.st_dev), inode: UInt64(info.st_ino))
        guard current == item.identity, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else { throw TrashError.changed }
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL? ?? url
    }

    /// Short Chinese reason for the cleanup report; raw Foundation messages are long and English.
    static func reason(for error: Error) -> String {
        if let trashError = error as? TrashError { return trashError.errorDescription ?? "未处理" }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteNoPermissionError, NSFileReadNoPermissionError: return "系统或其他账户的目录，没有权限移动"
            case NSFileNoSuchFileError: return "已不存在"
            default: break
            }
        }
        if nsError.domain == NSPOSIXErrorDomain, [Int(EPERM), Int(EACCES)].contains(nsError.code) {
            return "系统或其他账户的目录，没有权限移动"
        }
        return "移动失败"
    }
}

enum TrashError: LocalizedError {
    case notEligible
    case changed

    var errorDescription: String? {
        switch self {
        case .notEligible: "此项目不属于可清理缓存。"
        case .changed: "扫描后文件发生变化，请重新扫描。"
        }
    }
}
