import AppKit
import SwiftUI

private enum BrandAsset {
    static let icon = Bundle.main.url(forResource: "AppIcon-source", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))
}

struct MainView: View {
    @ObservedObject var store: ScanStore

    var body: some View {
        NavigationSplitView {
            List {
                Section("扫描位置") {
                    locationButton("我的文件", icon: "house", url: FileManager.default.homeDirectoryForCurrentUser)
                    ForEach(otherVolumes, id: \.self) { volume in
                        locationButton(volume.lastPathComponent, icon: "externaldrive", url: volume)
                    }
                }
                Section {
                    Button { store.chooseFolder() } label: {
                        Label("选一个文件夹…", systemImage: "folder.badge.plus")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Mac 清理管家")
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                    Text("扫描只读 · 清理需确认")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    if let message = store.message {
                        Label(message, systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let report = store.cleanupReport {
                        cleanupReportBanner(report)
                    }
                    if store.isScanning {
                        scanningContent
                    } else if let result = store.result {
                        resultContent(result)
                    } else {
                        welcomeContent
                    }
                }
                .padding(28)
                .frame(maxWidth: 1120, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                if store.result != nil && !store.isScanning { selectionBar }
            }
            .sheet(isPresented: $store.showTrashConfirmation) { cleanupReviewSheet }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mac 清理管家")
                    .font(.title2.weight(.bold))
                Text("看清空间占用，再决定怎么处理")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            brandIcon(44)
        }
    }

    private func cleanupReportBanner(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: report.movedCount > 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(report.movedCount > 0 ? .green : .orange)
                VStack(alignment: .leading, spacing: 3) {
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
                Button { store.cleanupReport = nil } label: {
                    Image(systemName: "xmark")
                }
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("先扫描，看看空间去哪了")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text("先快速查看常见缓存；也可以完整扫描文件夹，找出大工程和大文件。")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Button { store.scanKnownCaches() } label: {
                            Label("快速扫描空间", systemImage: "magnifyingglass")
                                .font(.headline)
                                .foregroundStyle(.indigo)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        Button { store.chooseFolder() } label: {
                            Text("选择文件夹…")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.7)))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("快速扫描覆盖已识别缓存和旧录音提示；完整扫描可能需要几分钟。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 10)
                brandIcon(132)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 14) {
                Text("你的磁盘")
                    .font(.title3.bold())
                HStack(spacing: 14) {
                    volumeCard("Mac 内置盘", icon: "laptopcomputer", url: FileManager.default.homeDirectoryForCurrentUser, actionTitle: "完整扫描我的文件")
                    if let external = otherVolumes.first {
                        volumeCard(external.lastPathComponent, icon: "externaldrive", url: external, actionTitle: "扫描这块磁盘")
                    }
                }
            }

            HStack(spacing: 16) {
                explanation("1", "扫描", "只读统计文件与目录")
                explanation("2", "审阅", "项目只提示，缓存说明来源")
                explanation("3", "处理", "你确认后才移入废纸篓")
            }
        }
    }

    private func volumeCard(_ title: String, icon: String, url: URL, actionTitle: String) -> some View {
        let capacity = volumeCapacity(url)
        return Button { store.scanLocation(url) } label: {
            VStack(alignment: .leading, spacing: 15) {
                Label(title, systemImage: icon)
                    .font(.headline)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(capacity.map { ByteFormat.string($0.free) } ?? "—")
                        .font(.title2.bold())
                    Text("可用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let capacity, capacity.total > 0 {
                    ProgressView(value: Double(capacity.total - capacity.free), total: Double(capacity.total))
                        .tint(.blue)
                    Text("总容量 \(ByteFormat.string(capacity.total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(actionTitle)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.blue, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func explanation(_ number: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var scanningContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 20) {
                brandIcon(88)
                VStack(alignment: .leading, spacing: 8) {
                    Text("正在扫描")
                        .font(.largeTitle.bold())
                    Text(store.root.lastPathComponent)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView()
                .progressViewStyle(.linear)
                .tint(.blue)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.progress.scannedCount.formatted())
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("项已检查")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("当前目录")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(store.progress.currentFolder)
                    .font(.callout)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Label("只读取文件大小与位置，不移动文件", systemImage: "lock.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消扫描") { store.cancelScan() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
    }

    private func resultContent(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(result.isQuickScan ? "常见缓存扫描完成" : "扫描完成").font(.largeTitle.bold())
                    Text(result.isQuickScan ? "常见缓存位置 · \(result.root.path)" : result.root.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                    Text("已检查 \(result.scannedCount.formatted()) 项 · 扫描只读")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if result.isQuickScan {
                    Button("完整扫描我的文件") { store.scanLocation(result.root) }
                        .buttonStyle(.bordered)
                } else {
                    Button("快速扫描空间") { store.scanKnownCaches() }
                        .buttonStyle(.bordered)
                }
                Button { store.scan() } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isScanning)
            }

            HStack(spacing: 12) {
                if let free = result.volumeFreeBytes {
                    summaryCard("磁盘可用", ByteFormat.string(free), icon: "internaldrive")
                }
                summaryCard(result.isQuickScan ? "已识别缓存" : "可审阅缓存", ByteFormat.string(cacheBytes(result)), icon: "arrow.triangle.2.circlepath")
                summaryCard("工程与人工审阅", "\(result.items.filter { $0.kind == .project || $0.kind == .largeFile || $0.kind == .review || $0.kind == .folder }.count) 项", icon: "folder")
            }

            if let free = result.volumeFreeBytes, free < 6 * 1_073_741_824 {
                Label("磁盘可用空间低于 6 GB。请先审阅 A 类缓存；废纸篓未清空前不会真正释放空间。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 16) {
                Text("A 可再生 \(result.items.filter { $0.risk == .a }.count) 项")
                Text("B 应用缓存 \(result.items.filter { $0.risk == .b }.count) 项")
                Text("C 人工判断 \(result.items.filter { $0.risk == .c }.count) 项")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("扫描结果")
                        .font(.title3.bold())
                    Text(result.isQuickScan ? "这里是已识别缓存，不代表整盘可释放空间；逐项核对后再处理。" : "缓存可勾选；工程、大文件和原软件生成数据只供查看。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("显示", selection: $store.filter) {
                    ForEach(ItemFilter.allCases) { item in Text(item.rawValue).tag(item) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 380)
                .onChange(of: store.filter) { _, _ in store.selectFirstVisibleItem() }
            }

            if store.filter != .projects && !store.eligibleItems.isEmpty {
                HStack(spacing: 12) {
                    Text("可清理缓存 \(store.eligibleItems.count) 项")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("全选可清理缓存") { store.selectAllEligible() }
                        .disabled(store.isCleaning)
                    Button("清空选择") { store.clearCleanupSelection() }
                        .disabled(store.selectedCleanupIDs.isEmpty || store.isCleaning)
                }
            }

            HStack(spacing: 0) {
                itemList
                Divider()
                inspector.frame(width: 280)
            }
            .frame(minHeight: 390)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            if result.skippedCount > 0 {
                Label("\(result.skippedCount) 个受保护、无权限或链接项目未计入；这里的数字不是整盘精确占用。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                if store.isCleaning {
                    Text("正在移入废纸篓：\(store.cleanedCount)/\(store.selectedCleanupItems.count) 项")
                        .font(.headline)
                } else {
                    Text("已选择 \(store.selectedCleanupItems.count) 项 · \(ByteFormat.string(store.selectedCleanupBytes))")
                        .font(.headline)
                }
                Text("移入废纸篓后仍可恢复；清空废纸篓才会释放空间。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isCleaning { ProgressView().controlSize(.small) }
            Button("查看并移入废纸篓…") { store.showTrashConfirmation = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.selectedCleanupItems.isEmpty || store.isCleaning)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(.regularMaterial)
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

    private func summaryCard(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var itemList: some View {
        List(selection: $store.selectedID) {
            ForEach(store.displayedItems) { item in
                HStack(spacing: 10) {
                    if item.canTrash {
                        Toggle("选择 \(item.name)", isOn: Binding(
                            get: { store.selectedCleanupIDs.contains(item.id) },
                            set: { store.setCleanupSelected(item, selected: $0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .disabled(store.isCleaning)
                    } else {
                        Image(systemName: "lock.shield")
                            .frame(width: 20)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).fontWeight(.medium).lineLimit(1)
                        Text("\(item.risk.rawValue) · \(item.url.deletingLastPathComponent().path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(ByteFormat.string(item.bytes)).monospacedDigit().foregroundStyle(.secondary)
                }
                .tag(item.id)
            }
        }
        .overlay {
            if store.displayedItems.isEmpty {
                ContentUnavailableView(
                    store.filter == .caches ? "没有发现可清理缓存" : "没有匹配项目",
                    systemImage: "checkmark.circle"
                )
            }
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let item = store.selectedItem {
                Image(systemName: symbol(for: item.kind))
                    .font(.largeTitle)
                    .foregroundStyle(item.kind == .cache ? .blue : .secondary)
                Text(item.name).font(.title3.bold()).lineLimit(2)
                LabeledContent("类型", value: item.kind.rawValue)
                LabeledContent("分级", value: item.risk.rawValue)
                LabeledContent("大小", value: ByteFormat.string(item.bytes))
                Button("在 Finder 中显示") { store.revealSelected() }
                    .controlSize(.large)
                if item.canTrash {
                    Button(store.selectedCleanupIDs.contains(item.id) ? "从待清理中移除" : "加入待清理") {
                        store.setCleanupSelected(item, selected: !store.selectedCleanupIDs.contains(item.id))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(store.isCleaning)
                } else {
                    Label("仅提示，由你自行处理", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
                Text(item.note).font(.callout).foregroundStyle(.secondary)
                Text(item.url.path).font(.caption2).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer()
            } else {
                Text("选择一个项目查看详情。").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(18)
    }

    private func locationButton(_ title: String, icon: String, url: URL) -> some View {
        Button { store.scanLocation(url) } label: { Label(title, systemImage: icon) }
            .buttonStyle(.plain)
    }

    @ViewBuilder
    private func brandIcon(_ size: CGFloat) -> some View {
        if let icon = BrandAsset.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }

    private func symbol(for kind: ScanKind) -> String {
        switch kind {
        case .cache: "arrow.triangle.2.circlepath"
        case .project: "film.stack"
        case .largeFile: "doc"
        case .folder: "folder"
        case .review: "hand.raised"
        }
    }

    private func cacheBytes(_ result: ScanResult) -> Int64 {
        result.items.filter { $0.kind == .cache }.reduce(0) { $0 + $1.bytes }
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
