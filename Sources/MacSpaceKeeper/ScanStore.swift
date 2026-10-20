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
        switch filter {
        case .all: return result.items
        case .caches: return result.items.filter { $0.kind == .cache }
        case .projects: return result.items.filter { $0.kind == .project || $0.kind == .largeFile || $0.kind == .review || $0.kind == .folder }
        }
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

    func selectFirstVisibleItem() {
        if !displayedItems.contains(where: { $0.id == selectedID }) {
            selectedID = displayedItems.first?.id
        }
    }

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
        if clearMessage { message = nil }
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
                    let caches = value.items.filter { $0.kind == .cache }
                    self.filter = caches.isEmpty ? .all : .caches
                    self.selectedID = (caches.first ?? value.items.first)?.id
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
        let scanPolicy = policy
        Task.detached(priority: .userInitiated) { [weak self] in
            var moved: [URL] = []
            var failures: [String] = []
            let service = TrashService(policy: scanPolicy)
            for item in items {
                do {
                    _ = try service.moveToTrash(item)
                    moved.append(item.id)
                } catch {
                    failures.append("\(item.name)：\(error.localizedDescription)")
                }
                let count = moved.count + failures.count
                await MainActor.run { self?.cleanedCount = count }
            }
            await MainActor.run {
                guard let self else { return }
                self.isCleaning = false
                self.selectedCleanupIDs.subtract(moved)
                let movedText = moved.isEmpty ? "没有项目被移动。" : "已将 \(moved.count) 项移入废纸篓；手动清空废纸篓后才会释放空间。"
                let failureText = failures.isEmpty ? "" : " \(failures.count) 项未处理：\(failures.joined(separator: "；"))"
                self.message = movedText + failureText
                if !moved.isEmpty { self.scan(clearMessage: false) }
            }
        }
    }
}

enum ItemFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case caches = "可清理缓存"
    case projects = "工程与人工审阅"
    var id: String { rawValue }
}
