import AppKit
import SwiftUI

private enum BrandAsset {
    static let icon = Bundle.main.url(forResource: "AppIcon-source", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))
}

struct MainView: View {
    @ObservedObject var store: ScanStore

    var hasResult: Bool { store.result != nil && !store.isScanning }
    var showSidebar: Bool { !store.isScanning && (store.result != nil || store.hasHistory) }
    var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                sidebar.frame(width: 232)
                Rectangle().fill(Theme.line).frame(width: 1)
            }
            Group {
                if store.isScanning {
                    scanningView
                } else if let result = store.result {
                    resultView(result)
                } else if store.hasHistory {
                    readyView
                } else {
                    welcomeView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(Theme.ink)
        .background(Backdrop())
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.dark)
        .background(WindowDragEnabler())
        .sheet(isPresented: $store.showTrashConfirmation) { cleanupReviewSheet }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshFullDiskAccess()
        }
    }

    // MARK: Welcome

    private var welcomeView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)
            brandIcon(150)
                .shadow(color: Theme.blue.opacity(0.7), radius: 34, y: 18)
            Text("看看空间都去哪了")
                .font(.system(size: 34, weight: .bold))
                .padding(.top, 26)
            Text("只读扫描 · 能放心清的直接勾 · 拿不准的只提示")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 10)
            Button { store.scanKnownCaches() } label: {
                Text("快速扫描")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 132, height: 132)
                    .background(
                        Circle().fill(RadialGradient(colors: [Color(red: 0.5, green: 0.69, blue: 1.0), Color(red: 0.23, green: 0.43, blue: 1.0), Color(red: 0.36, green: 0.24, blue: 0.96)],
                                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 100))
                    )
                    .background(Circle().fill(Theme.blue.opacity(0.12)).padding(-10))
                    .background(Circle().fill(Theme.blue.opacity(0.06)).padding(-22))
                    .shadow(color: Theme.blue.opacity(0.8), radius: 26, y: 14)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 40)
            HStack(spacing: 8) {
                Text("或").foregroundStyle(Theme.ink2)
                Button("完整扫描我的文件") { store.scanLocation(home) }
                ForEach(store.savedFolders, id: \.self) { folder in
                    Text("·").foregroundStyle(Theme.ink3)
                    Button(folder.lastPathComponent) { store.scanLocation(folder) }
                }
                Text("·").foregroundStyle(Theme.ink3)
                Button("添加文件夹…") { store.chooseFolder() }
            }
            .buttonStyle(LinkButtonStyle())
            .font(.system(size: 13.5))
            .padding(.top, 34)
            if let message = store.message {
                Text(message).font(.system(size: 12.5)).foregroundStyle(Theme.ink3).padding(.top, 14)
            }
            if !store.hasFullDiskAccess {
                Button { store.openFullDiskAccessSettings() } label: {
                    Label("开启「完全磁盘访问」后，不会再反复弹授权窗口", systemImage: "exclamationmark.shield.fill")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.amber)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            Spacer(minLength: 30)
            HStack(spacing: 16) {
                diskCard(home, name: "Mac 内置盘", icon: "laptopcomputer")
                ForEach(otherVolumes, id: \.self) { volume in
                    diskCard(volume, name: "\(volume.lastPathComponent) · 外接", icon: "externaldrive.fill")
                }
            }
            .frame(maxWidth: 900)
            .padding(.horizontal, 40)
            .padding(.bottom, 36)
        }
    }

    @ViewBuilder
    private func diskCard(_ url: URL, name: String, icon: String) -> some View {
        if let capacity = volumeCapacity(url), capacity.total > 0 {
            let low = capacity.free < 6 * 1_073_741_824
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(name, systemImage: icon)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(ByteFormat.string(capacity.free)).font(.system(size: 22, weight: .bold)).monospacedDigit()
                        Text("可用 / \(ByteFormat.string(capacity.total))").font(.system(size: 12.5)).foregroundStyle(Theme.ink3)
                    }
                    .lineLimit(1)
                    .fixedSize()
                    GlowBar(fraction: Double(capacity.total - capacity.free) / Double(capacity.total),
                            fill: low ? Theme.warning : Theme.accent, glow: low ? Theme.orange : Theme.cyan)
                        .frame(width: 260, height: 6)
                        .padding(.top, 4)
                }
                Spacer(minLength: 8)
                Button("扫描 →") { store.scanLocation(url) }.buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: 440)
            .glass(radius: 16)
        }
    }

    // MARK: Ready (location selected, not scanned yet)

    private var readyView: some View {
        let quick = store.isQuickScope
        return VStack(spacing: 0) {
            HStack {
                Text(store.scopeTitle).font(.system(size: 15, weight: .semibold))
                Text("未扫描").font(.system(size: 12.5)).foregroundStyle(Theme.ink3)
                Spacer()
            }
            .padding(.horizontal, 22)
            .frame(height: 52)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            Spacer()
            Image(systemName: quick ? "bolt.fill" : "folder.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 104, height: 104)
                .background(Circle().fill(Theme.panel))
                .overlay(Circle().strokeBorder(Theme.line))
                .shadow(color: Theme.blue.opacity(0.4), radius: 24)
            Text("还没扫描过「\(store.scopeTitle)」")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 24)
            Text(quick ? "只看常见缓存位置，几秒就好。" : shortPath(store.root) + " · 完整扫描可能要几分钟，只读不改。")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 8)
            Button { store.scan() } label: { Label("开始扫描", systemImage: "play.fill") }
                .buttonStyle(CTAButtonStyle())
                .keyboardShortcut(.defaultAction)
                .padding(.top, 26)
            Spacer()
            Spacer()
        }
    }

    // MARK: Scanning (live discoveries)

    private var scanningView: some View {
        HStack(spacing: 48) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.06), lineWidth: 3)
                    TimelineView(.animation) { context in
                        Circle()
                            .trim(from: 0, to: 0.22)
                            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .shadow(color: Theme.cyan.opacity(0.9), radius: 8)
                            .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 200))
                    }
                    Circle()
                        .fill(RadialGradient(colors: [Color(red: 0.5, green: 0.69, blue: 1.0), Color(red: 0.23, green: 0.43, blue: 1.0), Color(red: 0.36, green: 0.24, blue: 0.96)],
                                             center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 130))
                        .background(Circle().fill(Theme.blue.opacity(0.10)).padding(-14))
                        .background(Circle().fill(Theme.blue.opacity(0.05)).padding(-30))
                        .shadow(color: Theme.blue.opacity(0.8), radius: 36, y: 18)
                        .padding(60)
                    VStack(spacing: 4) {
                        Text(store.progress.scannedCount.formatted())
                            .font(.system(size: 32, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("项已检查").font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: 290, height: 290)
                Text("正在扫描\(store.scopeTitle)")
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.top, 24)
                Text(store.progress.currentFolder.replacingOccurrences(of: home.path, with: "~"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink3)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 360)
                    .padding(.top, 8)
                scanProgressBar
                    .frame(width: 300, height: 6)
                    .padding(.top, 18)
                Button("停止扫描") { store.cancelScan() }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.top, 22)
            }
            .frame(width: 380)
            liveFeed
        }
        .padding(.horizontal, 56)
        .padding(.top, 70)
        .padding(.bottom, 44)
    }

    @ViewBuilder
    private var scanProgressBar: some View {
        if let estimate = store.estimatedProgress {
            GlowBar(fraction: estimate)
        } else {
            TimelineView(.animation) { context in
                GeometryReader { proxy in
                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(Theme.accent)
                            .frame(width: proxy.size.width * 0.3)
                            .offset(x: proxy.size.width * (phase * 1.3 - 0.3))
                            .shadow(color: Theme.cyan.opacity(0.6), radius: 4)
                    }
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var liveFeed: some View {
        let notable = store.liveFound.filter { $0.bytes >= 5_000_000 }
        let recent = Array(notable.suffix(7).reversed())
        let caches = store.liveFound.filter { ItemFilter.caches.contains($0) }
        let creative = store.liveFound.filter { ItemFilter.creative.contains($0) }
        let large = store.liveFound.filter { ItemFilter.large.contains($0) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("边扫边发现")
                Spacer()
                Text("已发现 \(notable.count) 项")
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 4)
            VStack(spacing: 0) {
                if recent.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkle.magnifyingglass").font(.system(size: 28)).foregroundStyle(Theme.ink3)
                        Text("扫到的东西会出现在这里").font(.system(size: 13)).foregroundStyle(Theme.ink3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(recent) { item in
                        feedRow(item)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeOut(duration: 0.35), value: notable.count)
            .glass()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, Theme.base.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 70)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            HStack(spacing: 10) {
                liveTotal("可放心清理", ByteFormat.string(ScanStore.sum(caches)), Theme.cyan)
                liveTotal("剪辑软件", ByteFormat.string(ScanStore.sum(creative)), Theme.pink)
                liveTotal("大文件与工程", "\(large.count) 项", Theme.violet)
            }
        }
    }

    private func feedRow(_ item: ScanItem) -> some View {
        let info = ItemPresentation.info(for: item)
        let category = ItemFilter.allCases.first { $0.contains(item) }
        return HStack(spacing: 12) {
            itemIcon(item, info: info)
            VStack(alignment: .leading, spacing: 3) {
                Text(info.title).font(.system(size: 14, weight: .medium)).lineLimit(1).truncationMode(.middle)
                Text("\(category?.rawValue ?? item.kind.rawValue) · \(actionHint(item)) · \(item.url.deletingLastPathComponent().lastPathComponent)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            Text(ByteFormat.string(item.bytes)).font(.system(size: 14, weight: .medium)).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func liveTotal(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.ink2)
            Text(value).font(.system(size: 19, weight: .bold)).monospacedDigit().foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glass(radius: 12)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                brandIcon(32).shadow(color: Theme.blue.opacity(0.5), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac 清理管家").font(.system(size: 14.5, weight: .semibold))
                    Text("只读扫描 · 确认后才清理").font(.system(size: 11.5)).foregroundStyle(Theme.ink3)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            sectionHeader("扫描位置")
            locationRow("常见缓存", icon: "bolt.fill", url: home, quick: true)
            locationRow("我的文件", icon: "house.fill", url: home, quick: false)
            ForEach(otherVolumes, id: \.self) { volume in
                locationRow(volume.lastPathComponent, icon: "externaldrive.fill", url: volume, quick: false)
            }
            ForEach(store.savedFolders, id: \.self) { folder in
                locationRow(folder.lastPathComponent, icon: "folder.fill", url: folder, quick: false)
                    .contextMenu {
                        Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                        Button("从列表移除") { store.removeSavedFolder(folder) }
                    }
            }
            addFolderRow

            if store.result != nil {
                sectionHeader("分类").padding(.top, 12)
            }
            ForEach(store.result == nil ? [] : ItemFilter.allCases) { category in
                let items = store.items(in: category)
                switch category {
                case .chat:
                    if let chats = store.result?.chatApps, !chats.isEmpty {
                        categoryRow(category, bytes: chats.reduce(0) { $0 + ($1.bytes ?? 0) })
                    }
                case .creative:
                    if !items.isEmpty || !installedCreativeApps.isEmpty {
                        categoryRow(category, bytes: ScanStore.sum(items))
                    }
                default:
                    if category == .caches || !items.isEmpty {
                        categoryRow(category, bytes: ScanStore.sum(items))
                    }
                }
            }
            Spacer(minLength: 12)
            permissionCard
        }
        .padding(.top, 44)
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
        .background(Color.white.opacity(0.03))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    /// Clicking only switches to the location and shows its last result; scanning starts from the scan button.
    private func locationRow(_ title: String, icon: String, url: URL, quick: Bool) -> some View {
        let active = store.isCurrentScope(url, quick: quick)
        return Button { withAnimation(.easeOut(duration: 0.15)) { store.selectLocation(url, quick: quick) } } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(active ? Theme.cyan : Theme.ink2)
                Text(title).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 4)
                TimelineView(.everyMinute) { _ in
                    Text(store.lastScanDate(url, quick: quick).map(Self.ago) ?? "未扫描")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                }
            }
            .font(.system(size: 13.5))
            .foregroundStyle(active ? Theme.ink : Theme.ink2)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(active ? Color.white.opacity(0.08) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isCleaning)
    }

    private var addFolderRow: some View {
        Button { store.chooseFolder() } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 13, weight: .medium)).frame(width: 18)
                Text("添加文件夹")
                Spacer(minLength: 4)
            }
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isCleaning)
    }

    /// "刚刚 / 3 分钟前 / 2 小时前 / 昨天 / 10月18日"
    static func ago(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60)) 分钟前" }
        if Calendar.current.isDateInToday(date) { return "\(Int(seconds / 3600)) 小时前" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month().day())
    }

    private func categoryRow(_ category: ItemFilter, bytes: Int64) -> some View {
        let selected = store.filter == category
        let tint = Theme.color(category)
        return Button { withAnimation(.easeOut(duration: 0.15)) { store.selectCategory(category) } } label: {
            HStack(spacing: 10) {
                GlowDot(color: tint)
                Text(category.rawValue).lineLimit(1)
                Spacer(minLength: 4)
                Text(ByteFormat.string(bytes))
                    .font(.system(size: 12.5))
                    .monospacedDigit()
                    .foregroundStyle(selected ? Color(red: 0.81, green: 0.88, blue: 1.0) : Theme.ink3)
            }
            .font(.system(size: 13.5))
            .foregroundStyle(selected ? .white : Theme.ink2)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? AnyShapeStyle(LinearGradient(colors: [Theme.blue.opacity(0.28), Theme.blue.opacity(0.08)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.clear))
            )
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(selected ? Theme.blue.opacity(0.35) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("分类：\(category.rawValue)")
    }

    @ViewBuilder
    private var permissionCard: some View {
        if store.hasFullDiskAccess {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 15)).foregroundStyle(Theme.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("已开启完全磁盘访问").font(.system(size: 12, weight: .medium))
                    Text("不会再反复弹授权").font(.system(size: 11)).foregroundStyle(Theme.ink3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.green.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.green.opacity(0.25)))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("未开启完全磁盘访问", systemImage: "exclamationmark.shield.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text("开启后不再反复弹授权，也能看到微信占用多少。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("去开启 →") { store.openFullDiskAccessSettings() }.buttonStyle(GhostButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.amber.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.amber.opacity(0.3)))
        }
    }

    // MARK: Result

    private func resultView(_ result: ScanResult) -> some View {
        VStack(spacing: 0) {
            topBar(result)
            if store.filter == .creative {
                creativeView(result)
            } else if store.filter == .chat {
                chatView(result)
            } else {
                VStack(spacing: 14) {
                    HStack(spacing: 24) {
                        ring(result).frame(width: 184, height: 184)
                        statsGrid(result)
                    }
                    .padding(.top, 18)
                    banners
                    listPanel
                }
                .padding(.horizontal, 26)
                .padding(.bottom, showFooter ? 0 : 22)
            }
            if showFooter { footer }
        }
    }

    private var showFooter: Bool { !store.eligibleInFilter.isEmpty }

    private func topBar(_ result: ScanResult) -> some View {
        HStack(spacing: 10) {
            Text(store.filter == .creative || store.filter == .chat ? store.filter.rawValue : (result.isQuickScan ? "常见缓存" : store.scopeTitle))
                .font(.system(size: 15, weight: .semibold))
            Text(scanMeta(result))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink3)
                .lineLimit(1)
            Spacer()
            Button { store.scan() } label: { Label("重新扫描", systemImage: "arrow.clockwise") }
                .buttonStyle(ToolbarButtonStyle(prominent: true))
                .help("重新扫描「\(store.scopeTitle)」")
                .help("按当前范围重新扫描（⌘R）")
        }
        .disabled(store.isCleaning)
        .padding(.horizontal, 22)
        .frame(height: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func scanMeta(_ result: ScanResult) -> String {
        let count = result.scannedCount >= 10_000 ? "\(result.scannedCount / 10_000) 万项" : "\(result.scannedCount) 项"
        return "上次扫描 \(Self.ago(result.scannedAt)) · 已检查 \(count)"
    }

    private func ring(_ result: ScanResult) -> some View {
        let totalBytes = result.volumeTotalBytes ?? 0
        let total = Double(max(totalBytes, 1))
        let free = result.volumeFreeBytes ?? 0
        let used = Double(max(totalBytes - free, 0))
        let caches = Double(ScanStore.sum(store.items(in: .caches)))
        let creative = Double(ScanStore.sum(store.items(in: .creative)))
        let review = Double(ScanStore.sum(store.items(in: .review)))
        let large = Double(ScanStore.sum(store.items(in: .large)))
        let other = max(used - caches - creative - review - large, 0)
        let freeRatio = totalBytes > 0 ? Double(free) / Double(totalBytes) : 1
        let low = free < 6 * 1_073_741_824 || freeRatio < 0.05
        return ZStack {
            UsageRing(segments: [
                .init(fraction: other / total, style: AnyShapeStyle(LinearGradient(colors: [Color(red: 0.36, green: 0.43, blue: 0.62), Color(red: 0.27, green: 0.33, blue: 0.5)], startPoint: .top, endPoint: .bottom))),
                .init(fraction: large / total, style: AnyShapeStyle(Theme.violet)),
                .init(fraction: creative / total, style: AnyShapeStyle(Theme.pink)),
                .init(fraction: review / total, style: AnyShapeStyle(Theme.amber)),
                .init(fraction: caches / total, style: AnyShapeStyle(Theme.accent), glow: Theme.cyan)
            ], lineWidth: 15)
            VStack(spacing: 3) {
                Text(ByteFormat.string(free))
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(low ? Theme.amber : Theme.ink)
                Text("\(volumeName(result.root)) 可用")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink2)
                if low {
                    Text("只剩 \(max(Int((freeRatio * 100).rounded()), 1))%，空间紧张")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.amber)
                } else if totalBytes > 0 {
                    Text("共 \(ByteFormat.string(totalBytes)) · \(Int(used / total * 100))% 已用")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }

    private func statsGrid(_ result: ScanResult) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                statCard(.caches)
                statCard(.creative)
                chatStatCard(result)
            }
            GridRow {
                statCard(.review)
                statCard(.large, unavailable: result.isQuickScan)
                cleanableSummaryCard
            }
        }
    }

    private func statCard(_ category: ItemFilter, unavailable: Bool = false) -> some View {
        let items = store.items(in: category)
        let (number, unit) = splitBytes(ScanStore.sum(items))
        let selected = store.filter == category
        let detail: String
        if unavailable {
            detail = "完整扫描后可见"
        } else if items.isEmpty {
            detail = "未发现"
        } else if category == .creative {
            let here = ScanStore.sum(items.filter(\.canTrash))
            detail = here > 0 ? "\(unit) · 其中 \(ByteFormat.string(here)) 可在这里清" : "\(unit) · 都要回软件里清"
        } else {
            detail = "\(unit) · \(items.count) 项"
        }
        return Button { withAnimation(.easeOut(duration: 0.15)) { store.selectCategory(category) } } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GlowDot(color: Theme.color(category))
                    Text(category.rawValue)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink2)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(unavailable || items.isEmpty ? "—" : number).font(.system(size: 22, weight: .bold)).monospacedDigit()
                    Text(detail).font(.system(size: 12.5)).foregroundStyle(Theme.ink3).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .glass(highlighted: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Third card, same position as in the sidebar. Turns amber over 2 GB; opens the how-to page.
    private func chatStatCard(_ result: ScanResult) -> some View {
        let chats = result.chatApps
        let unreadable = chats.contains { $0.bytes == nil }
        let total = chats.reduce(Int64(0)) { $0 + ($1.bytes ?? 0) }
        let over = chats.contains { ($0.bytes ?? 0) >= 2_000_000_000 }
        let (number, unit) = splitBytes(total)
        let selected = store.filter == .chat
        let detail: String = {
            if chats.isEmpty { return "未发现" }
            if unreadable && total == 0 { return "开启权限后可见 ›" }
            return over ? "\(unit) · 超过 2 GB ›" : "\(unit) · 不到 2 GB"
        }()
        return Button { withAnimation(.easeOut(duration: 0.15)) { store.selectCategory(.chat) } } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GlowDot(color: Theme.green)
                    Text(ItemFilter.chat.rawValue)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink2)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(chats.isEmpty || (unreadable && total == 0) ? "—" : number)
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(over ? Theme.amber : Theme.ink)
                    Text(detail).font(.system(size: 12.5)).foregroundStyle(over ? Theme.amber.opacity(0.85) : Theme.ink3).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(over ? AnyShapeStyle(LinearGradient(colors: [Theme.amber.opacity(selected ? 0.24 : 0.16), Theme.amber.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Theme.panel))
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(over ? Theme.amber.opacity(selected ? 0.6 : 0.35) : (selected ? Theme.blue.opacity(0.5) : Theme.line)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// What this app itself can free: every cleanable item, across categories.
    private var cleanableSummaryCard: some View {
        let (number, unit) = splitBytes(ScanStore.sum(store.eligibleItems))
        return VStack(alignment: .leading, spacing: 6) {
            Label("这次能在这里清", systemImage: "sparkles")
                .font(.system(size: 12.5))
                .foregroundStyle(Color(red: 0.81, green: 0.88, blue: 1.0))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(number).font(.system(size: 22, weight: .bold)).monospacedDigit()
                Text("\(unit) · 清空废纸篓后释放").font(.system(size: 12.5)).foregroundStyle(Color(red: 0.72, green: 0.78, blue: 0.94)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(LinearGradient(colors: [Theme.blue.opacity(0.22), Theme.indigo.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(red: 0.55, green: 0.59, blue: 1.0).opacity(0.35)))
    }

    @ViewBuilder
    private var banners: some View {
        if let report = store.cleanupReport {
            cleanupReportBanner(report)
        }
        if store.cleanupReport == nil, let message = store.message {
            Label(message, systemImage: "info.circle")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Rows sharing a display name (hundreds of __pycache__) collapse into one group row.
    private struct RowGroup: Identifiable {
        let id: String
        let items: [ScanItem]
        let bytes: Int64
    }

    private func grouped(_ items: [ScanItem]) -> [RowGroup] {
        var order: [String] = []
        var buckets: [String: [ScanItem]] = [:]
        for item in items {
            let key = ItemPresentation.info(for: item).title
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        return order.map { RowGroup(id: $0, items: buckets[$0]!, bytes: ScanStore.sum(buckets[$0]!)) }
            .sorted { $0.bytes > $1.bytes }
    }

    private var listPanel: some View {
        let items = store.displayedItems
        let groups = grouped(items)
        let maxBytes = max(groups.map(\.bytes).max() ?? 1, 1)
        return Group {
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle").font(.system(size: 30)).foregroundStyle(Theme.cyan)
                    Text(store.filter == .caches ? "没有发现可清理缓存" : "这里没有项目").font(.system(size: 13.5)).foregroundStyle(Theme.ink2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groups) { group in
                            if group.items.count == 1 {
                                row(group.items[0], maxBytes: maxBytes)
                            } else {
                                groupRow(group, maxBytes: maxBytes)
                                if store.expandedGroups.contains(group.id) {
                                    ForEach(group.items) { item in
                                        row(item, maxBytes: group.items.map(\.bytes).max() ?? 1)
                                            .padding(.leading, 30)
                                            .background(Color.black.opacity(0.12))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glass()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ item: ScanItem, maxBytes: Int64) -> some View {
        let expanded = store.selectedID == item.id
        let picked = store.selectedCleanupIDs.contains(item.id)
        let hovered = store.hoveredID == item.id
        let info = ItemPresentation.info(for: item)
        let location = shortPath(item.url.deletingLastPathComponent())
        let subtitle = info.title == item.name
            ? "\(location) · \(tagText(item))"
            : "\(item.name) · \(location) · \(tagText(item))"
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                checkbox(item)
                itemIcon(item, info: info)
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 12)
                GlowBar(fraction: Double(item.bytes) / Double(maxBytes))
                    .frame(width: 90, height: 4)
                Text(ByteFormat.string(item.bytes))
                    .font(.system(size: 13.5, weight: .medium))
                    .monospacedDigit()
                    .frame(width: 80, alignment: .trailing)
                Button { toggleDetail(item) } label: {
                    Image(systemName: expanded ? "chevron.up.circle.fill" : "info.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(expanded ? Theme.cyan : (hovered ? Theme.ink2 : Theme.ink3))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(expanded ? "收起详情" : "查看详情")
            }
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.note)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Text(item.url.path)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(Theme.ink3)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Button("在 Finder 中显示") { reveal(item) }.buttonStyle(GhostButtonStyle())
                    }
                }
                .padding(.leading, 74)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(rowBackground(picked: picked, expanded: expanded, hovered: hovered))
        .overlay(alignment: .leading) {
            if picked { Rectangle().fill(Theme.cyan).frame(width: 3).shadow(color: Theme.cyan, radius: 4) }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture {
            // Clicking anywhere on a cleanable row picks it; other rows open their details.
            if item.canTrash {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { store.setCleanupSelected(item, selected: !picked) }
            } else {
                toggleDetail(item)
            }
        }
        .onHover { inside in
            if inside { store.hoveredID = item.id } else if store.hoveredID == item.id { store.hoveredID = nil }
        }
        .contextMenu {
            if item.canTrash {
                Button(picked ? "取消选择" : "选择") { store.setCleanupSelected(item, selected: !picked) }
            }
            Button(expanded ? "收起详情" : "查看详情") { toggleDetail(item) }
            Button("在 Finder 中显示") { reveal(item) }
        }
    }

    private func groupRow(_ group: RowGroup, maxBytes: Int64) -> some View {
        let first = group.items[0]
        let info = ItemPresentation.info(for: first)
        let cleanable = group.items.filter(\.canTrash)
        let pickedCount = cleanable.filter { store.selectedCleanupIDs.contains($0.id) }.count
        let allPicked = !cleanable.isEmpty && pickedCount == cleanable.count
        let expanded = store.expandedGroups.contains(group.id)
        let hovered = store.hoveredID == first.id
        let parents = group.items.map { $0.url.deletingLastPathComponent().path }
        let common = parents.dropFirst().reduce(parents[0]) { prefix, path in
            var result = prefix
            while !(path == result || path.hasPrefix(result + "/")) { result = (result as NSString).deletingLastPathComponent }
            return result
        }
        let toggleExpanded = {
            withAnimation(.easeOut(duration: 0.18)) {
                if expanded { store.expandedGroups.remove(group.id) } else { store.expandedGroups.insert(group.id) }
            }
        }
        return HStack(spacing: 12) {
            if cleanable.isEmpty {
                Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Theme.ink3).frame(width: 18, height: 18)
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(pickedCount > 0 ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(pickedCount > 0 ? .clear : Color(red: 0.3, green: 0.36, blue: 0.52), lineWidth: 1.5))
                    .overlay {
                        if pickedCount > 0 {
                            Image(systemName: allPicked ? "checkmark" : "minus").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .shadow(color: pickedCount > 0 ? Theme.cyan.opacity(0.6) : .clear, radius: 5)
            }
            itemIcon(first, info: info)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(info.title).font(.system(size: 14, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                    Text("\(group.items.count) 处")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    if pickedCount > 0 && !allPicked {
                        Text("已选 \(pickedCount)").font(.system(size: 11.5)).foregroundStyle(Theme.cyan)
                    }
                }
                Text("\(first.name) · \(groupLocation(parents: parents, common: common)) · \(tagText(first))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            GlowBar(fraction: Double(group.bytes) / Double(maxBytes))
                .frame(width: 90, height: 4)
            Text(ByteFormat.string(group.bytes))
                .font(.system(size: 13.5, weight: .medium))
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
            Button(action: toggleExpanded) {
                Image(systemName: expanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(expanded ? Theme.cyan : (hovered ? Theme.ink2 : Theme.ink3))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(expanded ? "收起" : "展开看每一处")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(allPicked ? Theme.cyan.opacity(0.08) : (hovered ? Color.white.opacity(0.07) : .clear))
        .overlay(alignment: .leading) {
            if pickedCount > 0 { Rectangle().fill(Theme.cyan).frame(width: 3).shadow(color: Theme.cyan, radius: 4) }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture {
            if cleanable.isEmpty {
                toggleExpanded()
            } else {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { store.setGroupSelected(group.items, selected: !allPicked) }
            }
        }
        .onHover { inside in
            if inside { store.hoveredID = first.id } else if store.hoveredID == first.id { store.hoveredID = nil }
        }
        .contextMenu {
            if !cleanable.isEmpty {
                Button(allPicked ? "取消选择这 \(cleanable.count) 处" : "选择这 \(cleanable.count) 处") { store.setGroupSelected(group.items, selected: !allPicked) }
            }
            Button(expanded ? "收起" : "展开看每一处", action: toggleExpanded)
        }
    }

    /// "都在 ~/Coding 里" when one folder holds them all, otherwise the top folders holding the most.
    private func groupLocation(parents: [String], common: String) -> String {
        guard common == store.policy.home.path || common == "/" else {
            return "都在 \(shortPath(URL(fileURLWithPath: common))) 里"
        }
        var counts: [String: Int] = [:]
        for path in parents {
            let rest = path.dropFirst(common.count).split(separator: "/")
            if let top = rest.first { counts[String(top), default: 0] += 1 }
        }
        let tops = counts.sorted { $0.value > $1.value }.prefix(2).map { shortPath(URL(fileURLWithPath: common).appending(path: $0.key)) }
        return "主要在 \(tops.joined(separator: "、"))\(counts.count > 2 ? " 等处" : " 里")"
    }

    private func rowBackground(picked: Bool, expanded: Bool, hovered: Bool) -> Color {
        if expanded { return Theme.blue.opacity(0.14) }
        if picked { return Theme.cyan.opacity(hovered ? 0.12 : 0.08) }
        return hovered ? Color.white.opacity(0.07) : .clear
    }

    private func toggleDetail(_ item: ScanItem) {
        withAnimation(.easeOut(duration: 0.18)) { store.selectedID = store.selectedID == item.id ? nil : item.id }
    }

    // MARK: Creative apps

    private func creativeView(_ result: ScanResult) -> some View {
        let items = store.items(in: .creative)
        let here = ScanStore.sum(items.filter(\.canTrash))
        let inApp = ScanStore.sum(items.filter { !$0.canTrash })
        let headline: String = {
            if items.isEmpty { return "没发现剪辑软件缓存" }
            if inApp == 0 { return "\(ByteFormat.string(here)) 能在这里清" }
            if here == 0 { return "\(ByteFormat.string(inApp)) 要回软件里清" }
            return "\(ByteFormat.string(here)) 能在这里清，\(ByteFormat.string(inApp)) 要回软件里清"
        }()
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline).font(.system(size: 24, weight: .bold))
                    Text(result.isQuickScan
                         ? "快速扫描只看 AE / Adobe / Blender 缓存；Final Cut 渲染文件和达芬奇 CacheClip 要完整扫描才找得到。"
                         : "缓存清了会在下次打开时重新生成；工程文件、素材一律不碰。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.bottom, 6)
                if let report = store.cleanupReport { cleanupReportBanner(report) }
                ForEach(CreativeApp.allCases, id: \.self) { app in
                    let appItems = items.filter { CreativeApp.of($0) == app }
                    if !appItems.isEmpty {
                        creativeGroup(app, items: appItems)
                    } else if installedCreativeApps.contains(app) {
                        creativeEmptyCard(app, unchecked: result.isQuickScan && (app == .finalCut || app == .davinci))
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
        }
    }

    private var installedCreativeApps: [CreativeApp] {
        CreativeApp.allCases.filter { ItemPresentation.appIcon(bundleID: $0.bundleID) != nil }
    }

    /// Installed app with nothing found: still its own card, so it's clear it was checked and where to look.
    private func creativeEmptyCard(_ app: CreativeApp, unchecked: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = ItemPresentation.appIcon(bundleID: app.bundleID) {
                Image(nsImage: icon).resizable().frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(app.title).font(.system(size: 15.5, weight: .semibold))
                    Label(unchecked ? "完整扫描才查得到" : "目前没有缓存", systemImage: unchecked ? "clock" : "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(unchecked ? Theme.ink2 : Theme.green)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill((unchecked ? Color.white : Theme.green).opacity(0.1)))
                }
                Text("缓存在哪：\(app.cacheWhere)").font(.system(size: 12.5)).foregroundStyle(Theme.ink2)
                Text("怎么清：\(app.cleanHow)").font(.system(size: 12.5)).foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glass()
    }

    // MARK: Chat apps

    private func chatView(_ result: ScanResult) -> some View {
        let total = result.chatApps.reduce(0) { $0 + ($1.bytes ?? 0) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("微信和企业微信一共占 \(ByteFormat.string(total))").font(.system(size: 24, weight: .bold))
                    Text("聊天数据只能在原软件里清。这里只看大小、告诉你怎么清，不会删任何东西。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.bottom, 4)
                ForEach(result.chatApps) { chat in chatGuideCard(chat) }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
        }
    }

    private func chatGuideCard(_ chat: ChatAppUsage) -> some View {
        let bytes = chat.bytes ?? 0
        let over = bytes >= 2_000_000_000
        let version = NSWorkspace.shared.urlForApplication(withBundleIdentifier: chat.id)
            .flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                if let icon = ItemPresentation.appIcon(bundleID: chat.id) {
                    Image(nsImage: icon).resizable().frame(width: 46, height: 46)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(chat.name).font(.system(size: 17, weight: .semibold))
                    if chat.bytes == nil {
                        Label("没权限读取，开启完全磁盘访问后才看得到", systemImage: "lock.fill")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.amber)
                    } else {
                        Label(over ? "超过 2 GB，建议清一清" : "不到 2 GB，暂时不用管", systemImage: over ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(over ? Theme.amber : Theme.green)
                    }
                }
                Spacer(minLength: 8)
                Text(chat.bytes == nil ? "—" : ByteFormat.string(bytes))
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(over ? Theme.amber : Theme.ink)
            }
            .padding(18)

            VStack(alignment: .leading, spacing: 10) {
                Text("怎么清" + (version.map { "（\(chat.name) \($0)）" } ?? ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                ForEach(Array(ChatGuide.steps(for: chat.id).enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Theme.green)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.green.opacity(0.14)))
                        Text(step).font(.system(size: 13.5))
                    }
                }
                Text("菜单名以你当前版本为准，个别版本位置略有不同。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }

            VStack(alignment: .leading, spacing: 8) {
                Text("哪些能删").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink2)
                ForEach(ChatGuide.tips, id: \.text) { tip in
                    HStack(spacing: 8) {
                        Image(systemName: tip.symbol)
                            .foregroundStyle(tip.tint == "green" ? Theme.green : (tip.tint == "amber" ? Theme.amber : Theme.pink))
                        Text(tip.text).foregroundStyle(Theme.ink)
                    }
                    .font(.system(size: 13))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }

            HStack {
                Text("这个 App 不会动\(chat.name)的任何数据。").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                Spacer()
                if chat.bytes == nil {
                    Button("去开启权限") { store.openFullDiskAccessSettings() }.buttonStyle(GhostButtonStyle())
                }
                Button("打开\(chat.name)") { store.openApp(bundleID: chat.id) }.buttonStyle(CTAButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .glass()
    }

    private func creativeGroup(_ app: CreativeApp, items: [ScanItem]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let icon = ItemPresentation.appIcon(bundleID: app.bundleID) {
                    Image(nsImage: icon).resizable().frame(width: 40, height: 40)
                } else {
                    Image(systemName: "film.stack.fill").font(.system(size: 20)).foregroundStyle(Theme.pink).frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.title).font(.system(size: 15.5, weight: .semibold))
                    Text(app.hint).font(.system(size: 12)).foregroundStyle(Theme.ink3).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(ByteFormat.string(ScanStore.sum(items))).font(.system(size: 19, weight: .bold)).monospacedDigit()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            ForEach(items) { item in creativeRow(item, app: app) }
            if items.contains(where: { !$0.canTrash }), !app.inAppSteps.isEmpty {
                HStack(spacing: 6) {
                    Text("在\(app.shortName)里：").foregroundStyle(Theme.ink2)
                    ForEach(Array(app.inAppSteps.enumerated()), id: \.offset) { index, step in
                        if index > 0 { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.ink3) }
                        Text(step)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12))
                .padding(.leading, 70)
                .padding(.trailing, 18)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            }
        }
        .glass()
    }

    private func creativeRow(_ item: ScanItem, app: CreativeApp) -> some View {
        let picked = store.selectedCleanupIDs.contains(item.id)
        let hovered = store.hoveredID == item.id
        return HStack(spacing: 12) {
            checkbox(item)
            VStack(alignment: .leading, spacing: 3) {
                Text(ItemPresentation.partTitle(for: item)).font(.system(size: 14, weight: .medium)).lineLimit(1).truncationMode(.middle)
                Text(shortPath(item.url)).font(.system(size: 12)).foregroundStyle(Theme.ink3).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 10)
            if item.canTrash {
                Text("这里可清")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.cyan.opacity(0.1)))
                    .overlay(Capsule().strokeBorder(Theme.cyan.opacity(0.3)))
            } else {
                Button { store.openApp(bundleID: app.bundleID) } label: {
                    Text("在\(app.shortName)里清 ›")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.amber.opacity(0.1)))
                        .overlay(Capsule().strokeBorder(Theme.amber.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .help("打开 \(app.title)")
            }
            Text(ByteFormat.string(item.bytes))
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .frame(width: 84, alignment: .trailing)
        }
        .padding(.leading, 70)
        .padding(.trailing, 18)
        .padding(.vertical, 11)
        .background(picked ? Theme.cyan.opacity(0.08) : (hovered ? Color.white.opacity(0.05) : .clear))
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture {
            if item.canTrash {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { store.setCleanupSelected(item, selected: !picked) }
            }
        }
        .onHover { inside in
            if inside { store.hoveredID = item.id } else if store.hoveredID == item.id { store.hoveredID = nil }
        }
        .contextMenu { Button("在 Finder 中显示") { reveal(item) } }
    }

    // MARK: Shared row parts

    @ViewBuilder
    private func itemIcon(_ item: ScanItem, info: ItemPresentation.Info) -> some View {
        if let image = info.icon {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
        } else {
            let tint = Theme.color(ItemFilter.allCases.first { $0.contains(item) } ?? .caches)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.32), tint.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint.opacity(0.3)))
                .overlay(Image(systemName: info.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint))
                .frame(width: 30, height: 30)
                .padding(1)
        }
    }

    @ViewBuilder
    private func checkbox(_ item: ScanItem) -> some View {
        if item.canTrash {
            let on = store.selectedCleanupIDs.contains(item.id)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(on ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(on ? .clear : Color(red: 0.3, green: 0.36, blue: 0.52), lineWidth: 1.5))
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .scaleEffect(on ? 1 : 0.3)
                        .opacity(on ? 1 : 0)
                }
                .frame(width: 18, height: 18)
                .shadow(color: on ? Theme.cyan.opacity(0.6) : .clear, radius: 5)
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink3)
                .frame(width: 18, height: 18)
                .help("仅提示，不在这里清理")
        }
    }

    private var footer: some View {
        let inFilter = store.eligibleInFilter
        let allSelected = inFilter.allSatisfy { store.selectedCleanupIDs.contains($0.id) }
        let empty = store.selectedCleanupItems.isEmpty
        let quit = store.appsToQuit
        return HStack(spacing: 10) {
            Button(allSelected ? "取消全选" : "全选") {
                withAnimation(.easeOut(duration: 0.15)) { allSelected ? store.clearCleanupSelection() : store.selectAllEligible() }
            }
            .keyboardShortcut("a", modifiers: .command)
            if store.filter == .caches {
                Button("只选可再生") {
                    withAnimation(.easeOut(duration: 0.15)) { store.selectReusable() }
                }
                .help("uv、npm、Codex 运行时这类缓存：不用退出任何应用，下次用时自动重新下载")
            }
            Rectangle().fill(Theme.line).frame(width: 1, height: 24).padding(.horizontal, 4)
            if store.isCleaning {
                ProgressView().controlSize(.small)
                Text("正在移入废纸篓 \(store.cleanedCount)/\(store.selectedCleanupItems.count)")
                    .monospacedDigit()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(empty ? "点任意一行即可选中" : "已选 \(store.selectedCleanupItems.count) 项 · \(ByteFormat.string(store.selectedCleanupBytes))")
                        .font(.system(size: empty ? 13.5 : 15.5, weight: .semibold))
                        .foregroundStyle(empty ? Theme.ink2 : Theme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if !quit.isEmpty {
                        Text("先退出 \(quit.prefix(3).joined(separator: "、"))\(quit.count > 3 ? " 等" : "") 再清理")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.amber)
                    } else if !empty {
                        Text("都是可再生缓存，可直接清理")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.ink3)
                    }
                }
            }
            Spacer()
            Button("移入废纸篓…") {
                store.hoveredID = nil
                store.showTrashConfirmation = true
            }
            .buttonStyle(CTAButtonStyle())
            .disabled(empty || store.isCleaning)
            .opacity(empty || store.isCleaning ? 0.4 : 1)
        }
        .buttonStyle(GhostButtonStyle())
        .disabled(store.isCleaning)
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
    }

    private func cleanupReportBanner(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: report.movedCount > 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(report.movedCount > 0 ? Theme.green : Theme.amber)
                Text(report.movedCount > 0
                     ? "已移入废纸篓 \(report.movedCount.formatted()) 项 · \(ByteFormat.string(report.movedBytes))"
                     : "没有项目被移动")
                    .font(.system(size: 13.5, weight: .semibold))
                if report.movedCount > 0 {
                    Text("清空废纸篓后才会真正释放空间").font(.system(size: 12.5)).foregroundStyle(Theme.ink3)
                }
                Spacer()
                Button { store.cleanupReport = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.ink3)
                    .help("关闭")
            }
            if !report.failures.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(report.failures) { failure in
                            HStack(spacing: 8) {
                                Text(failure.name).font(.system(size: 12, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 8)
                                Text(failure.reason).font(.system(size: 12)).foregroundStyle(Theme.ink3)
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("\(report.failures.count) 项被系统拒绝，已跳过（不影响其他项）")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.leading, 24)
            }
        }
        .padding(12)
        .glass(radius: 12)
    }

    // MARK: Helpers

    private func actionHint(_ item: ScanItem) -> String {
        if let app = CreativeApp.of(item) { return item.canTrash ? "这里可清" : "在\(app.shortName)里清" }
        return tagText(item)
    }

    private func tagText(_ item: ScanItem) -> String {
        guard item.canTrash else { return item.kind.rawValue }
        return item.risk == .a ? "可再生" : "应用缓存，先退出对应应用"
    }

    private func shortPath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: store.policy.home.path, with: "~")
    }

    private func reveal(_ item: ScanItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private func splitBytes(_ bytes: Int64) -> (String, String) {
        let text = ByteFormat.string(bytes)
        guard let space = text.range(of: " ", options: .backwards) else { return (text, "") }
        return (String(text[..<space.lowerBound]), String(text[space.upperBound...]))
    }

    @ViewBuilder
    private func brandIcon(_ size: CGFloat) -> some View {
        if let icon = BrandAsset.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous).strokeBorder(Color.white.opacity(0.15)))
        } else {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
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

    // MARK: Confirmation sheet

    private var cleanupReviewSheet: some View {
        let items = store.selectedCleanupItems
        let quit = store.appsToQuit
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent)
                    .shadow(color: Theme.cyan.opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text("移入废纸篓").font(.system(size: 20, weight: .bold))
                    Text("共 \(items.count) 项 · \(ByteFormat.string(store.selectedCleanupBytes))，随时可以从废纸篓恢复")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.ink2)
                }
            }
            if !quit.isEmpty {
                Label("请先退出：\(quit.prefix(4).joined(separator: "、"))\(quit.count > 4 ? " 等" : "")", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.amber)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        let info = ItemPresentation.info(for: item)
                        HStack(spacing: 10) {
                            itemIcon(item, info: info).scaleEffect(0.85)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(info.title).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
                                Text(shortPath(item.url))
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(Theme.ink3)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }
                            Spacer(minLength: 8)
                            Text(ByteFormat.string(item.bytes)).font(.system(size: 13.5, weight: .medium)).monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                    }
                }
            }
            .frame(height: min(CGFloat(items.count) * 52, 300))
            .glass(radius: 12)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack {
                Text("应用不会清空废纸篓，真正释放空间由你决定。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                Spacer()
                Button("返回") { store.showTrashConfirmation = false }
                    .buttonStyle(GhostButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("确认移入废纸篓") { store.trashSelectedItems() }
                    .buttonStyle(CTAButtonStyle())
                    .disabled(items.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(Theme.ink)
        .background(Backdrop())
        .preferredColorScheme(.dark)
    }
}

/// Lets the borderless-looking window be dragged from any empty background area.
struct WindowDragEnabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.isMovableByWindowBackground = true }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
