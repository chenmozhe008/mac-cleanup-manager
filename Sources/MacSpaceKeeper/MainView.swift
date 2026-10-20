import AppKit
import SwiftUI

private enum BrandAsset {
    static let icon = Bundle.main.url(forResource: "AppIcon-source", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))
}

struct MainView: View {
    @ObservedObject var store: ScanStore

    private var hasResult: Bool { store.result != nil && !store.isScanning }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            content
                .navigationTitle(hasResult ? store.filter.rawValue : "Mac 清理管家")
                .navigationSubtitle(subtitle)
                .inspector(isPresented: Binding(get: { store.showInspector && hasResult }, set: { store.showInspector = $0 })) {
                    inspector
                        .inspectorColumnWidth(min: 240, ideal: 280, max: 360)
                }
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $store.showTrashConfirmation) { cleanupReviewSheet }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var subtitle: String {
        guard hasResult else { return "" }
        let items = store.displayedItems
        return "\(items.count.formatted()) 项 · \(ByteFormat.string(totalBytes(items)))"
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("快速扫描常见缓存") { store.scanKnownCaches() }
                Button("完整扫描我的文件") { store.scanLocation(FileManager.default.homeDirectoryForCurrentUser) }
                if !otherVolumes.isEmpty {
                    Divider()
                    ForEach(otherVolumes, id: \.self) { volume in
                        Button("扫描 \(volume.lastPathComponent)") { store.scanLocation(volume) }
                    }
                }
                Divider()
                Button("选择文件夹…") { store.chooseFolder() }
            } label: {
                Label(store.result == nil && !store.isScanning ? "扫描位置" : store.scopeTitle, systemImage: "scope")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(store.isCleaning)
            .help("选择扫描范围")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if store.isScanning {
                Button { store.cancelScan() } label: { Label("停止扫描", systemImage: "stop.fill") }
                    .help("停止扫描")
            } else {
                Button { store.scan() } label: { Label("重新扫描", systemImage: "arrow.clockwise") }
                    .disabled(store.result == nil || store.isCleaning)
                    .help("重新扫描当前范围")
            }
            Button { store.showInspector.toggle() } label: { Label("详情", systemImage: "sidebar.right") }
                .disabled(!hasResult)
                .help("显示或隐藏详情")
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: Binding<ItemFilter?>(
            get: { hasResult ? store.filter : nil },
            set: { if let value = $0 { store.filter = value; store.selectFirstVisibleItem() } }
        )) {
            Section("扫描结果") {
                if hasResult {
                    ForEach(ItemFilter.allCases) { category in
                        let items = store.items(in: category)
                        if category == .caches || !items.isEmpty {
                            sidebarRow(category, items: items).tag(category)
                        }
                    }
                } else {
                    Text(store.isScanning ? "扫描中…" : "扫描后在这里分类")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { diskGauge }
    }

    private func sidebarRow(_ category: ItemFilter, items: [ScanItem]) -> some View {
        HStack {
            Label(category.rawValue, systemImage: category.symbol)
            Spacer(minLength: 6)
            Text(ByteFormat.string(totalBytes(items)))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var diskGauge: some View {
        let url = store.result?.root ?? store.root
        if let capacity = volumeCapacity(url), capacity.total > 0 {
            let low = capacity.free < 6 * 1_073_741_824
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                    Text(volumeName(url))
                        .lineLimit(1)
                }
                .font(.callout.weight(.medium))
                ProgressView(value: Double(capacity.total - capacity.free), total: Double(capacity.total))
                    .tint(low ? .orange : .accentColor)
                Text("剩余 \(ByteFormat.string(capacity.free)) · 共 \(ByteFormat.string(capacity.total))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(low ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                if let result = store.result, !store.isScanning {
                    Text("已检查 \(result.scannedCount.formatted()) 项" + (result.skippedCount > 0 ? " · \(result.skippedCount.formatted()) 项无权限未计入" : ""))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        Group {
            if store.isScanning {
                scanningView
            } else if store.result != nil {
                resultTable
            } else {
                welcomeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) { banners }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasResult && store.filter == .caches && !store.eligibleItems.isEmpty { selectionBar }
        }
    }

    @ViewBuilder
    private var banners: some View {
        if store.cleanupReport != nil || store.message != nil {
            VStack(spacing: 8) {
                if let report = store.cleanupReport { cleanupReportBanner(report) }
                if let message = store.message {
                    Label(message, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 18) {
            brandIcon(96)
            VStack(spacing: 6) {
                Text("看看空间都去哪了")
                    .font(.title.weight(.semibold))
                Text("扫描只读取大小和位置；清理前会让你逐项确认。")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button("快速扫描") { store.scanKnownCaches() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                Button("完整扫描我的文件") { store.scanLocation(FileManager.default.homeDirectoryForCurrentUser) }
            }
            .controlSize(.large)
            Text("快速扫描只看常见缓存，几秒完成；完整扫描还能找出大文件和工程，需要几分钟。")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }

    private var scanningView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("正在扫描\(store.scopeTitle)")
                .font(.title2.weight(.semibold))
            Text("已检查 \(store.progress.scannedCount.formatted()) 项")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(store.progress.currentFolder)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 440)
            Button("停止扫描") { store.cancelScan() }
                .padding(.top, 6)
        }
        .padding(40)
    }

    private var resultTable: some View {
        let items = store.displayedItems
        let maxBytes = max(items.map(\.bytes).max() ?? 1, 1)
        return Table(items, selection: $store.selectedID) {
            TableColumn("") { item in
                if item.canTrash {
                    Toggle("选择 \(item.name)", isOn: Binding(
                        get: { store.selectedCleanupIDs.contains(item.id) },
                        set: { store.setCleanupSelected(item, selected: $0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(store.isCleaning)
                } else {
                    Image(systemName: "lock")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .help("仅提示，不在这里清理")
                }
            }
            .width(22)
            TableColumn("名称") { item in
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(item.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.url.deletingLastPathComponent().path.replacingOccurrences(of: store.policy.home.path, with: "~"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            TableColumn("大小") { item in
                HStack(spacing: 10) {
                    SizeBar(fraction: Double(item.bytes) / Double(maxBytes))
                    Text(ByteFormat.string(item.bytes))
                        .monospacedDigit()
                        .frame(minWidth: 64, alignment: .trailing)
                }
            }
            .width(min: 140, ideal: 160, max: 200)
        }
        .alternatingRowBackgrounds(.disabled)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(store.filter == .caches ? "没有发现可清理缓存" : "这里没有项目", systemImage: "checkmark.circle")
            }
        }
    }

    private var selectionBar: some View {
        let allSelected = store.selectedCleanupIDs.count == store.eligibleItems.count
        return VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                Button(allSelected ? "取消全选" : "全选") {
                    allSelected ? store.clearCleanupSelection() : store.selectAllEligible()
                }
                .disabled(store.isCleaning)
                if store.isCleaning {
                    ProgressView().controlSize(.small)
                    Text("正在移入废纸篓 \(store.cleanedCount)/\(store.selectedCleanupItems.count)")
                        .monospacedDigit()
                } else {
                    Text("已选 \(store.selectedCleanupItems.count) 项 · \(ByteFormat.string(store.selectedCleanupBytes))")
                        .font(.headline)
                        .monospacedDigit()
                }
                Spacer()
                Button("移入废纸篓…") { store.showTrashConfirmation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.selectedCleanupItems.isEmpty || store.isCleaning)
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    // MARK: Inspector

    @ViewBuilder
    private var inspector: some View {
        if let item = store.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title3.weight(.semibold))
                            .lineLimit(3)
                        Text(ByteFormat.string(item.bytes))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    Text(tagText(item))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(item.canTrash ? Color.accentColor : .secondary)
                        .background((item.canTrash ? Color.accentColor : Color.secondary).opacity(0.12), in: Capsule())
                    Text(item.note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("位置").font(.caption).foregroundStyle(.secondary)
                        Text(item.url.path)
                            .font(.caption)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 8) {
                        if item.canTrash {
                            let selected = store.selectedCleanupIDs.contains(item.id)
                            Button {
                                store.setCleanupSelected(item, selected: !selected)
                            } label: {
                                Text(selected ? "从清理中移除" : "加入清理").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(selected ? .secondary : .accentColor)
                            .disabled(store.isCleaning)
                        }
                        Button { store.revealSelected() } label: {
                            Text("在 Finder 中显示").frame(maxWidth: .infinity)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
        } else {
            ContentUnavailableView("未选择项目", systemImage: "sidebar.right", description: Text("在列表中点一项查看来源和路径。"))
        }
    }

    private func tagText(_ item: ScanItem) -> String {
        guard item.canTrash else { return "仅提示 · 由你处理" }
        return item.risk == .a ? "可再生缓存" : "应用缓存 · 先退出对应应用"
    }

    private func cleanupReportBanner(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: report.movedCount > 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(report.movedCount > 0 ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.movedCount > 0
                         ? "已移入废纸篓 \(report.movedCount.formatted()) 项 · \(ByteFormat.string(report.movedBytes))"
                         : "没有项目被移动")
                        .font(.headline)
                    if report.movedCount > 0 {
                        Text("清空废纸篓后才会真正释放空间。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { store.cleanupReport = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("关闭")
            }
            if !report.failures.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(report.failures) { failure in
                            HStack(spacing: 8) {
                                Text(failure.name)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 8)
                                Text(failure.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("\(report.failures.count) 项被系统拒绝，已跳过（不影响其他项）")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 26)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var cleanupReviewSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("确认处理所选缓存")
                .font(.title2.bold())
            Text("共 \(store.selectedCleanupItems.count) 项，约 \(ByteFormat.string(store.selectedCleanupBytes))。请核对路径；工程和大文件不会进入此清单。")
                .font(.callout)
                .foregroundStyle(.secondary)
            List(store.selectedCleanupItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name).fontWeight(.semibold)
                        Spacer()
                        Text(ByteFormat.string(item.bytes)).monospacedDigit()
                    }
                    Text(item.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
            Text("操作只会移入 macOS 废纸篓。你可以在那里恢复，应用不会自动清空。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("返回选择") { store.showTrashConfirmation = false }
                    .keyboardShortcut(.cancelAction)
                Button("确认移入废纸篓") { store.trashSelectedItems() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.selectedCleanupItems.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 640, height: 460)
    }

    // MARK: Helpers

    @ViewBuilder
    private func brandIcon(_ size: CGFloat) -> some View {
        if let icon = BrandAsset.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        } else {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }

    private func totalBytes(_ items: [ScanItem]) -> Int64 {
        items.reduce(0) { sum, item in
            let addition = sum.addingReportingOverflow(item.bytes)
            return addition.overflow ? Int64.max : addition.partialValue
        }
    }

    private func volumeName(_ url: URL) -> String {
        (try? url.resourceValues(forKeys: [.volumeLocalizedNameKey]).volumeLocalizedName) ?? "磁盘"
    }

    private func volumeCapacity(_ url: URL) -> (total: Int64, free: Int64)? {
        guard let data = try? FileManager.default.attributesOfFileSystem(forPath: url.path),
              let total = (data[.systemSize] as? NSNumber)?.int64Value,
              let free = (data[.systemFreeSize] as? NSNumber)?.int64Value else { return nil }
        return (total, free)
    }

    private var otherVolumes: [URL] {
        let volumes = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: [.volumeIsBrowsableKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return volumes.filter { volume in
            guard volume.lastPathComponent != "Recovery" else { return false }
            let values = try? volume.resourceValues(forKeys: [.isSymbolicLinkKey, .volumeIsBrowsableKey])
            return values?.isSymbolicLink != true && values?.volumeIsBrowsable != false
        }
    }
}

private struct SizeBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(.tint).frame(width: max(3, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(width: 56, height: 5)
    }
}
