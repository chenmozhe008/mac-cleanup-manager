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
    @Published var isCleaning = false
    @Published var cleanedCount = 0
    @Published var filter: ItemFilter = .caches

    let policy = SafetyPolicy()
    private var scanID = UUID()
    private var scanTask: Task<Void, Never>?
    private var quickMode = false


    var displayedItems: [ScanItem] {
        guard let result else { return [] }
        return result.items.filter { filter.contains($0.kind) }
    }

    func items(in category: ItemFilter) -> [ScanItem] {
        result?.items.filter { category.contains($0.kind) } ?? []
    }

    var scopeTitle: String {
        if result?.isQuickScan == true || (isScanning && quickMode) { return "常见缓存" }
        if root.path == policy.home.path { return "我的文件" }
        return root.lastPathComponent
    }

    var selectedItem: ScanItem? { displayedItems.first { $0.id == selectedID } }

    var eligibleItems: [ScanItem] {
        result?.items.filter { $0.kind == .cache && $0.canTrash } ?? []
    }

    var selectedCleanupItems: [ScanItem] {
        eligibleItems.filter { selectedCleanupIDs.contains($0.id) }
    }

    var selectedCleanupBytes: Int64 {
        selectedCleanupItems.reduce(0) { sum, item in
            let addition = sum.addingReportingOverflow(item.bytes)
            return addition.overflow ? Int64.max : addition.partialValue
        }
    }

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
        selectedCleanupIDs = Set(eligibleItems.map(\.id))
    }

    func clearCleanupSelection() {
        guard !isCleaning else { return }
        selectedCleanupIDs.removeAll()
    }

    func selectCategory(_ category: ItemFilter) {
        filter = category
        selectedID = nil
    }

    var isQuickScope: Bool { quickMode }

    func chooseFolder() {
        guard !isCleaning else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "扫描此文件夹"
        if panel.runModal() == .OK, let url = panel.url { scanLocation(url) }
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

    func scan(clearMessage: Bool = true) {
        guard !isScanning, !isCleaning else { return }
        isScanning = true
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
            let progressStore = self
            let output = Result {
                let scanner = DiskScanner(policy: scanPolicy)
                return try isQuick ? scanner.scanKnownCaches { update in
                    Task { @MainActor in
                        guard let progressStore, progressStore.scanID == thisScan, progressStore.isScanning else { return }
                        if update.scannedCount >= progressStore.progress.scannedCount { progressStore.progress = update }
                    }
                } : scanner.scan(scanRoot) { update in
                    Task { @MainActor in
                        guard let progressStore, progressStore.scanID == thisScan, progressStore.isScanning else { return }
                        if update.scannedCount >= progressStore.progress.scannedCount { progressStore.progress = update }
                    }
                }
            }
            await MainActor.run {
                guard let self, self.scanID == thisScan else { return }
                self.scanTask = nil
                self.isScanning = false
                switch output {
                case .success(let value):
                    self.result = value
                    self.selectedCleanupIDs.removeAll()
                    self.filter = ItemFilter.allCases.first { category in value.items.contains { category.contains($0.kind) } } ?? .caches
                    self.selectedID = nil
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
    }

    func revealSelected() {
        guard let selectedItem else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedItem.url])
    }

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
    case caches = "可放心清理"
    case review = "需要你判断"
    case large = "大文件与工程"
    case folders = "目录占用"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .caches: "sparkles"
        case .review: "hand.raised"
        case .large: "shippingbox"
        case .folders: "folder"
        }
    }

    func contains(_ kind: ScanKind) -> Bool {
        switch self {
        case .caches: kind == .cache
        case .review: kind == .review
        case .large: kind == .project || kind == .largeFile
        case .folders: kind == .folder
        }
    }
}
