import Foundation
import Darwin

enum CanonicalPath {
    static func url(_ input: URL) -> URL {
        guard let pointer = realpath(input.path, nil) else { return input.standardizedFileURL }
        defer { free(pointer) }
        return URL(fileURLWithPath: String(cString: pointer), isDirectory: input.hasDirectoryPath)
    }
}
