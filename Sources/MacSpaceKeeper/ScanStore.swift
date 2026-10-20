import AppKit
import Foundation
import SwiftUI

@MainActor
final class ScanStore: ObservableObject {
    @Published var root = FileManager.default.homeDirectoryForCurrentUser
    @Published var result: ScanResult?
    @Published var isScanning = false
    @Published var progress = ScanProgress(scannedCount: 0, currentFolder: "")
    @Published var message: String?
    @Published var cleanupReport: CleanupReport?
    @Published var selectedID: URL?
    @Published var selectedCleanupIDs: Set<URL> = []
    @Published var showTrashConfirmation = false
    @Published var showAbout = false
    @Published var aboutTab: AboutTab = .intro
    @Published var isCleaning = false
    @Published var cleanedCount = 0
    @Published var filter: ItemFilter = .caches {
        didSet { UserDefaults.standard.set(filter.rawValue, forKey: Keys.lastFilter) }
    }
    @Published var hoveredID: URL?
    /// Items found so far in the running scan, newest last.
    @Published var liveFound: [ScanItem] = []
    @Published var savedFolders: [URL] = []
    @Published var hasFullDiskAccess = false
    /// Same-name rows (e.g. hundreds of __pycache__) that the user expanded.
    @Published var expandedGroups: Set<String> = []

    let policy = SafetyPolicy()
    private var scanID = UUID()
    private var scanTask: Task<Void, Never>?
    private var quickMode = false

    private enum Keys {
        static let savedFolders = "savedFolders"
        static let scanSizes = "scanSizes"
        static let lastFilter = "lastFilter"
        static let lastScope = "lastScope"
        static let scanDates = "scanDates"
    }

    init() {
        savedFolders = (UserDefaults.standard.stringArray(forKey: Keys.savedFolders) ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        refreshFullDiskAccess()
        loadLastResult()
    }

    // MARK: Derived data

    var displayedItems: [ScanItem] { items(in: filter) }

    func items(in category: ItemFilter) -> [ScanItem] {
        result?.items.filter { category.contains($0) } ?? []
    }

    var scopeTitle: String {
        if quickMode { return "快速扫描" }
        if root.path == policy.home.path { return "完整扫描" }
        return root.lastPathComponent
    }

    var isQuickScope: Bool { quickMode }

    /// "正在快速扫描" / "正在完整扫描" / "正在扫描「Coding」"
    var scanningTitle: String {
        if quickMode { return "正在快速扫描" }
        if root.path == policy.home.path { return "正在完整扫描" }
        return "正在扫描「\(root.lastPathComponent)」"
    }

    var notScannedTitle: String {
        if quickMode { return "还没做过快速扫描" }
        if root.path == policy.home.path { return "还没做过完整扫描" }
        return "还没扫描过「\(root.lastPathComponent)」"
    }

    var selectedItem: ScanItem? { displayedItems.first { $0.id == selectedID } }

    var eligibleItems: [ScanItem] {
        result?.items.filter { $0.kind == .cache && $0.canTrash } ?? []
    }

    /// Cleanable items in the current category (footer actions work per category).
    var eligibleInFilter: [ScanItem] {
        displayedItems.filter { $0.kind == .cache && $0.canTrash }
    }

    var selectedCleanupItems: [ScanItem] {
        eligibleItems.filter { selectedCleanupIDs.contains($0.id) }
    }

    var selectedCleanupBytes: Int64 { Self.sum(selectedCleanupItems) }

    /// Apps to quit before cleaning the current selection.
    var appsToQuit: [String] {
        var names: [String] = []
        for item in selectedCleanupItems {
            let name: String?
            if let app = CreativeApp.of(item) {
                name = app.title
            } else if item.risk == .b {
                name = ItemPresentation.info(for: item).title
            } else {
                name = nil
            }
            if let name, !names.contains(name) { names.append(name) }
        }
        return names
    }

    /// Fraction of the last scan of the same scope, when one is known.
    var estimatedProgress: Double? {
        guard let expected = scanSizes[scopeKey], expected > 0 else { return nil }
        return min(Double(progress.scannedCount) / Double(expected), 0.99)
    }

    static func sum(_ items: [ScanItem]) -> Int64 {
        items.reduce(0) { sum, item in
            let addition = sum.addingReportingOverflow(item.bytes)
            return addition.overflow ? Int64.max : addition.partialValue
        }
    }

    // MARK: Selection

    func setCleanupSelected(_ item: ScanItem, selected: Bool) {
        guard !isCleaning, item.kind == .cache, item.canTrash,
              eligibleItems.contains(where: { $0.id == item.id }) else { return }
        if selected {
            selectedCleanupIDs.insert(item.id)
        } else {
            selectedCleanupIDs.remove(item.id)
        }
    }

    func selectAllEligible() {
        guard !isCleaning else { return }
        selectedCleanupIDs.formUnion(eligibleInFilter.map(\.id))
    }

    /// Regenerable caches (risk A, outside creative apps) need no app to be quit: the safe one-click pick.
    func selectReusable() {
        guard !isCleaning else { return }
        selectedCleanupIDs = Set(eligibleItems.filter { $0.risk == .a && CreativeApp.of($0) == nil }.map(\.id))
    }

    func setGroupSelected(_ items: [ScanItem], selected: Bool) {
        guard !isCleaning else { return }
        let ids = items.filter { $0.kind == .cache && $0.canTrash }.map(\.id)
        if selected { selectedCleanupIDs.formUnion(ids) } else { selectedCleanupIDs.subtract(ids) }
    }

    func clearCleanupSelection() {
        guard !isCleaning else { return }
        selectedCleanupIDs.subtract(eligibleInFilter.map(\.id))
    }

    func selectCategory(_ category: ItemFilter) {
        filter = category
        selectedID = nil
    }

    // MARK: Locations

    func chooseFolder() {
        guard !isCleaning else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "添加"
        if panel.runModal() == .OK, let url = panel.url {
            addSavedFolder(url)
            selectLocation(url, quick: false)
        }
    }

    func addSavedFolder(_ url: URL) {
        let url = url.standardizedFileURL
        guard url.path != policy.home.path, !savedFolders.contains(url) else { return }
        savedFolders.append(url)
        persistSavedFolders()
    }

    func removeSavedFolder(_ url: URL) {
        savedFolders.removeAll { $0 == url }
        persistSavedFolders()
    }

    private func persistSavedFolders() {
        UserDefaults.standard.set(savedFolders.map(\.path), forKey: Keys.savedFolders)
    }

    func setRoot(_ url: URL) {
        guard !isCleaning else { return }
        scanTask?.cancel()
        scanTask = nil
        scanID = UUID()
        root = url.standardizedFileURL
        result = nil
        selectedID = nil
        selectedCleanupIDs.removeAll()
        message = nil
        cleanupReport = nil
        isScanning = false
        progress = ScanProgress(scannedCount: 0, currentFolder: "")
    }

    /// Switch to a location and show its last result. Scanning only starts from the scan button.
    func selectLocation(_ url: URL, quick: Bool) {
        guard !isScanning, !isCleaning else { return }
        setRoot(quick ? policy.home : url)
        quickMode = quick
        showSavedResult()
    }

    func isCurrentScope(_ url: URL, quick: Bool) -> Bool {
        quick ? quickMode : (!quickMode && root.path == url.standardizedFileURL.path)
    }

    func lastScanDate(_ url: URL, quick: Bool) -> Date? {
        scanDates[Self.scopeKey(root: url.standardizedFileURL, quick: quick)].map(Date.init(timeIntervalSince1970:))
    }

    var hasHistory: Bool { !scanDates.isEmpty }

    func scanLocation(_ url: URL) {
        setRoot(url)
        quickMode = false
        scan()
    }

    func scanKnownCaches() {
        setRoot(policy.home)
        quickMode = true
        scan()
    }

    // MARK: Permissions

    /// ~/Library/Safari is readable only with Full Disk Access, so it is a reliable probe.
    func refreshFullDiskAccess() {
        let probe = policy.home.appending(path: "Library/Safari").path
        hasFullDiskAccess = (try? FileManager.default.contentsOfDirectory(atPath: probe)) != nil
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func openApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Scanning

    private var scopeKey: String { Self.scopeKey(root: root, quick: quickMode) }

    private static func scopeKey(root: URL, quick: Bool) -> String { quick ? "quick" : root.path }

    private var scanDates: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: Keys.scanDates) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.scanDates) }
    }

    private var scanSizes: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: Keys.scanSizes) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.scanSizes) }
    }

    func scan(clearMessage: Bool = true) {
        guard !isScanning, !isCleaning else { return }
        isScanning = true
        liveFound = []
        progress = ScanProgress(scannedCount: 0, currentFolder: root.path)
        if clearMessage {
            message = nil
            cleanupReport = nil
        }
        let thisScan = UUID()
        scanID = thisScan
        let scanRoot = root
        let scanPolicy = policy
        let isQuick = quickMode
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            let store = self
            let onProgress: @Sendable (ScanProgress) -> Void = { update in
                Task { @MainActor in
                    guard let store, store.scanID == thisScan, store.isScanning else { return }
                    if update.scannedCount >= store.progress.scannedCount { store.progress = update }
                }
            }
            var scanner = DiskScanner(policy: scanPolicy)
            scanner.onFound = { item in
                Task { @MainActor in
                    guard let store, store.scanID == thisScan, store.isScanning else { return }
                    // A cache folder replaces anything already listed inside it, same as the final result.
                    if item.kind == .cache {
                        let prefix = item.url.path + "/"
                        store.liveFound.removeAll { $0.url.path.hasPrefix(prefix) }
                    }
                    store.liveFound.append(item)
                }
            }
            let output = Result {
                var value = try isQuick ? scanner.scanKnownCaches(onProgress: onProgress) : scanner.scan(scanRoot, onProgress: onProgress)
                value.chatApps = scanner.chatAppUsage()
                return value
            }
            await MainActor.run {
                guard let self, self.scanID == thisScan else { return }
                self.scanTask = nil
                self.isScanning = false
                switch output {
                case .success(let value):
                    self.result = value
                    self.selectedCleanupIDs.removeAll()
                    self.filter = ItemFilter.allCases.first { category in value.items.contains { category.contains($0) } } ?? .caches
                    self.selectedID = nil
                    self.scanSizes[self.scopeKey] = value.scannedCount
                    self.saveResult(value)
                case .failure(let error):
                    self.message = error is CancellationError ? "扫描已取消。" : error.localizedDescription
                }
            }
        }
    }

    func cancelScan() {
        guard isScanning else { return }
        scanTask?.cancel()
        scanTask = nil
        scanID = UUID()
        isScanning = false
        message = "扫描已取消。"
        // Return to this location's previous result instead of an empty screen.
        showSavedResult()
    }

    // MARK: Saved results (one per location)

    private var resultsDirectory: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "MacSpaceKeeper/results")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func resultURL(for key: String) -> URL {
        let name = Data(key.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return resultsDirectory.appending(path: "\(name).json")
    }

    private func saveResult(_ value: ScanResult) {
        if let data = try? JSONEncoder().encode(value) { try? data.write(to: resultURL(for: scopeKey), options: .atomic) }
        scanDates[scopeKey] = value.scannedAt.timeIntervalSince1970
        UserDefaults.standard.set(scopeKey, forKey: Keys.lastScope)
    }

    /// Shows the current location's previous scan. Cleanup still re-checks each path's identity before moving.
    private func showSavedResult() {
        UserDefaults.standard.set(scopeKey, forKey: Keys.lastScope)
        guard let data = try? Data(contentsOf: resultURL(for: scopeKey)),
              let value = try? JSONDecoder().decode(ScanResult.self, from: data) else {
            result = nil
            return
        }
        result = value
        // Reopen on the category last viewed.
        if let saved = UserDefaults.standard.string(forKey: Keys.lastFilter).flatMap(ItemFilter.init(rawValue:)) {
            filter = saved
        } else {
            filter = ItemFilter.allCases.first { category in value.items.contains { category.contains($0) } } ?? .caches
        }
    }

    /// On launch: reopen the location viewed last (migrating the old single last-scan file once).
    private func loadLastResult() {
        let legacy = resultsDirectory.deletingLastPathComponent().appending(path: "last-scan.json")
        if let data = try? Data(contentsOf: legacy), let value = try? JSONDecoder().decode(ScanResult.self, from: data) {
            root = value.root
            quickMode = value.isQuickScan
            saveResult(value)
            try? FileManager.default.removeItem(at: legacy)
        }
        guard let key = UserDefaults.standard.string(forKey: Keys.lastScope) else { return }
        quickMode = key == "quick"
        root = quickMode ? policy.home : URL(fileURLWithPath: key)
        showSavedResult()
    }

    // MARK: Cleanup

    func trashSelectedItems() {
        let items = selectedCleanupItems
        guard !items.isEmpty, !isCleaning else { return }
        showTrashConfirmation = false
        isCleaning = true
        cleanedCount = 0
        message = nil
        cleanupReport = nil
        let scanPolicy = policy
        Task.detached(priority: .userInitiated) { [weak self] in
            var moved: [URL] = []
            var movedBytes: Int64 = 0
            var failures: [CleanupReport.Failure] = []
            let service = TrashService(policy: scanPolicy)
            for item in items {
                do {
                    _ = try service.moveToTrash(item)
                    moved.append(item.id)
                    let addition = movedBytes.addingReportingOverflow(item.bytes)
                    movedBytes = addition.overflow ? Int64.max : addition.partialValue
                } catch {
                    failures.append(CleanupReport.Failure(id: item.id, name: item.name, reason: TrashService.reason(for: error)))
                }
                let count = moved.count + failures.count
                await MainActor.run { self?.cleanedCount = count }
            }
            await MainActor.run {
                guard let self else { return }
                self.isCleaning = false
                self.selectedCleanupIDs.subtract(moved)
                self.cleanupReport = CleanupReport(movedCount: moved.count, movedBytes: movedBytes, failures: failures)
                if !moved.isEmpty { self.scan(clearMessage: false) }
            }
        }
    }
}

enum ItemFilter: String, CaseIterable, Identifiable {
    case caches = "可清理缓存"
    case creative = "剪辑与设计软件"
    case chat = "微信与企业微信"
    case review = "谨慎处理"
    case large = "大文件与工程"
    var id: String { rawValue }

    func contains(_ item: ScanItem) -> Bool {
        let creative = CreativeApp.of(item) != nil
        switch self {
        case .caches: return item.kind == .cache && !creative
        case .creative: return creative
        case .chat: return false
        case .review: return item.kind == .review && !creative
        case .large: return item.kind == .project || item.kind == .largeFile
        }
    }
}
