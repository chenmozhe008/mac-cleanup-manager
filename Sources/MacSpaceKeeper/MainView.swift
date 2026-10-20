import AppKit
import SwiftUI

private enum BrandAsset {
    static let icon = Bundle.main.url(forResource: "AppIcon-source", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))
}

struct MainView: View {
    @ObservedObject var store: ScanStore

    private var hasResult: Bool { store.result != nil && !store.isScanning }
    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    var body: some View {
        HStack(spacing: 0) {
            if hasResult {
                sidebar.frame(width: 220)
                Rectangle().fill(Theme.line).frame(width: 1)
            }
            Group {
                if store.isScanning {
                    scanningView
                } else if let result = store.result {
                    resultView(result)
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
                Text("·").foregroundStyle(Theme.ink3)
                Button("选择文件夹…") { store.chooseFolder() }
            }
            .buttonStyle(LinkButtonStyle())
            .font(.system(size: 13))
            .padding(.top, 34)
            if let message = store.message {
                Text(message).font(.system(size: 12)).foregroundStyle(Theme.ink3).padding(.top, 14)
            }
            Spacer(minLength: 30)
            HStack(spacing: 16) {
                diskCard(home, name: "Mac 内置盘", icon: "laptopcomputer")
                ForEach(otherVolumes, id: \.self) { volume in
                    diskCard(volume, name: "\(volume.lastPathComponent) · 外接", icon: "externaldrive")
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
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(ByteFormat.string(capacity.free)).font(.system(size: 22, weight: .bold)).monospacedDigit()
                        Text("可用 / \(ByteFormat.string(capacity.total))").font(.system(size: 12)).foregroundStyle(Theme.ink3)
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

    // MARK: Scanning

    private var scanningView: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 10)
                TimelineView(.animation) { context in
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .shadow(color: Theme.cyan.opacity(0.8), radius: 8)
                        .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 240))
                }
                VStack(spacing: 4) {
                    Text(store.progress.scannedCount.formatted())
                        .font(.system(size: 30, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("项已检查").font(.system(size: 12)).foregroundStyle(Theme.ink2)
                }
            }
            .frame(width: 180, height: 180)
            Text("正在扫描\(store.scopeTitle)")
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 30)
            Text(store.progress.currentFolder.replacingOccurrences(of: home.path, with: "~"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 480)
                .padding(.top, 8)
            Button("停止扫描") { store.cancelScan() }
                .buttonStyle(GhostButtonStyle())
                .padding(.top, 24)
            Spacer()
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("扫描位置")
            locationRow("常见缓存", icon: "bolt", active: store.result?.isQuickScan == true) { store.scanKnownCaches() }
            locationRow("我的文件", icon: "house", active: store.result?.isQuickScan == false && store.root.path == store.policy.home.path) {
                store.scanLocation(home)
            }
            ForEach(otherVolumes, id: \.self) { volume in
                locationRow(volume.lastPathComponent, icon: "externaldrive", active: store.result?.isQuickScan == false && store.root.path == volume.path) {
                    store.scanLocation(volume)
                }
            }
            locationRow("选择文件夹…", icon: "plus", active: false) { store.chooseFolder() }

            sectionHeader("分类").padding(.top, 14)
            ForEach(ItemFilter.allCases) { category in
                let items = store.items(in: category)
                if category == .caches || !items.isEmpty {
                    categoryRow(category, bytes: totalBytes(items))
                }
            }
            Spacer()
            Label("扫描只读 · 清理需确认", systemImage: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink3)
                .padding(.horizontal, 8)
        }
        .padding(.top, 52)
        .padding(.horizontal, 10)
        .padding(.bottom, 16)
        .background(Color.white.opacity(0.03))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private func locationRow(_ title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 16)
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.system(size: 13))
            .foregroundStyle(active ? Theme.ink : Theme.ink2)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(active ? Color.white.opacity(0.06) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isCleaning)
    }

    private func categoryRow(_ category: ItemFilter, bytes: Int64) -> some View {
        let selected = store.filter == category
        return Button { withAnimation(.easeOut(duration: 0.15)) { store.selectCategory(category) } } label: {
            HStack(spacing: 10) {
                GlowDot(color: Theme.color(category))
                Text(category.rawValue)
                Spacer(minLength: 4)
                Text(ByteFormat.string(bytes))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(selected ? Color(red: 0.81, green: 0.88, blue: 1.0) : Theme.ink3)
            }
            .font(.system(size: 13))
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
    }

    // MARK: Result

    private func resultView(_ result: ScanResult) -> some View {
        VStack(spacing: 0) {
            topBar(result)
            VStack(spacing: 16) {
                HStack(spacing: 28) {
                    ring(result).frame(width: 200, height: 200)
                    statsGrid(result)
                }
                .padding(.top, 22)
                banners
                listPanel
            }
            .padding(.horizontal, 28)
            .padding(.bottom, showFooter ? 0 : 24)
            if showFooter { footer }
        }
    }

    private var showFooter: Bool { store.filter == .caches && !store.eligibleItems.isEmpty }

    private func topBar(_ result: ScanResult) -> some View {
        HStack(spacing: 10) {
            Text(result.isQuickScan ? "常见缓存扫描" : "扫描 · \(store.scopeTitle)")
                .font(.system(size: 14, weight: .semibold))
            Text("\(result.scannedAt.formatted(date: .omitted, time: .shortened)) · 已检查 \(result.scannedCount.formatted()) 项"
                 + (result.skippedCount > 0 ? " · \(result.skippedCount.formatted()) 项无权限未计入" : ""))
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
                .lineLimit(1)
            Spacer()
            Button(result.isQuickScan ? "完整扫描我的文件" : "快速扫描") {
                result.isQuickScan ? store.scanLocation(home) : store.scanKnownCaches()
            }
            .buttonStyle(GhostButtonStyle())
            Button { store.scan() } label: { Label("重新扫描", systemImage: "arrow.clockwise") }
                .buttonStyle(GhostButtonStyle())
        }
        .disabled(store.isCleaning)
        .padding(.horizontal, 22)
        .frame(height: 52)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func ring(_ result: ScanResult) -> some View {
        let total = Double(max(result.volumeTotalBytes ?? 0, 1))
        let free = result.volumeFreeBytes ?? 0
        let used = Double(max((result.volumeTotalBytes ?? 0) - free, 0))
        let caches = Double(totalBytes(store.items(in: .caches)))
        let review = Double(totalBytes(store.items(in: .review)))
        let large = Double(totalBytes(store.items(in: .large)))
        let other = max(used - caches - review - large, 0)
        let low = free < 6 * 1_073_741_824
        return ZStack {
            UsageRing(segments: [
                .init(fraction: other / total, style: AnyShapeStyle(LinearGradient(colors: [Color(red: 0.36, green: 0.43, blue: 0.62), Color(red: 0.27, green: 0.33, blue: 0.5)], startPoint: .top, endPoint: .bottom))),
                .init(fraction: large / total, style: AnyShapeStyle(Theme.violet)),
                .init(fraction: review / total, style: AnyShapeStyle(Theme.amber)),
                .init(fraction: caches / total, style: AnyShapeStyle(Theme.accent), glow: Theme.cyan)
            ])
            VStack(spacing: 4) {
                Text(ByteFormat.string(free))
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(low ? Theme.amber : Theme.ink)
                Text("\(volumeName(result.root)) 可用")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }

    private func statsGrid(_ result: ScanResult) -> some View {
        let total = result.volumeTotalBytes ?? 0
        let usedPercent = total > 0 ? Double(total - (result.volumeFreeBytes ?? 0)) / Double(total) * 100 : 0
        return Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                statCard(.caches)
                statCard(.review)
            }
            GridRow {
                statCard(.large, unavailable: result.isQuickScan)
                VStack(alignment: .leading, spacing: 6) {
                    Label("共 \(ByteFormat.string(total))", systemImage: "internaldrive")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(usedPercent.formatted(.number.precision(.fractionLength(1)))).font(.system(size: 24, weight: .bold)).monospacedDigit()
                        Text("% 已用").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .glass()
            }
        }
    }

    private func statCard(_ category: ItemFilter, unavailable: Bool = false) -> some View {
        let items = store.items(in: category)
        let (number, unit) = splitBytes(totalBytes(items))
        let selected = store.filter == category
        return Button { withAnimation(.easeOut(duration: 0.15)) { store.selectCategory(category) } } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GlowDot(color: Theme.color(category))
                    Text(category.rawValue)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(unavailable ? "—" : number).font(.system(size: 24, weight: .bold)).monospacedDigit()
                    Text(unavailable ? "完整扫描后可见" : "\(unit) · \(items.count) 项").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glass(highlighted: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var banners: some View {
        if let report = store.cleanupReport {
            cleanupReportBanner(report)
        } else if let message = store.message {
            Label(message, systemImage: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var listPanel: some View {
        let items = store.displayedItems
        let maxBytes = max(items.map(\.bytes).max() ?? 1, 1)
        return Group {
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle").font(.system(size: 30)).foregroundStyle(Theme.cyan)
                    Text(store.filter == .caches ? "没有发现可清理缓存" : "这里没有项目").foregroundStyle(Theme.ink2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in row(item, maxBytes: maxBytes) }
                    }
                }
                .scrollIndicators(.automatic)
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
                itemIcon(item, image: info.icon)
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 12)
                GlowBar(fraction: Double(item.bytes) / Double(maxBytes))
                    .frame(width: 90, height: 4)
                Text(ByteFormat.string(item.bytes))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .frame(width: 76, alignment: .trailing)
                Button { toggleDetail(item) } label: {
                    Image(systemName: expanded ? "chevron.up.circle.fill" : "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(expanded ? Theme.cyan : (hovered ? Theme.ink2 : Theme.ink3))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(expanded ? "收起详情" : "查看详情")
            }
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.note)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Text(item.url.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.ink3)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Button("在 Finder 中显示") { reveal(item) }.buttonStyle(GhostButtonStyle())
                    }
                }
                .padding(.leading, 68)
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

    private func rowBackground(picked: Bool, expanded: Bool, hovered: Bool) -> Color {
        if expanded { return Theme.blue.opacity(0.14) }
        if picked { return Theme.cyan.opacity(hovered ? 0.12 : 0.08) }
        return hovered ? Color.white.opacity(0.07) : .clear
    }

    private func toggleDetail(_ item: ScanItem) {
        withAnimation(.easeOut(duration: 0.18)) { store.selectedID = store.selectedID == item.id ? nil : item.id }
    }

    @ViewBuilder
    private func itemIcon(_ item: ScanItem, image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
        } else {
            let tint = Theme.color(ItemFilter.allCases.first { $0.contains(item.kind) } ?? .caches)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint.opacity(0.3)))
                .overlay(Image(systemName: symbol(for: item.kind)).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint))
                .frame(width: 28, height: 28)
                .padding(1)
        }
    }

    private func symbol(for kind: ScanKind) -> String {
        switch kind {
        case .cache: "arrow.triangle.2.circlepath"
        case .project: "film.stack"
        case .largeFile: "doc.fill"
        case .review: "hand.raised.fill"
        case .folder: "folder.fill"
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
                .font(.system(size: 10))
                .foregroundStyle(Theme.ink3)
                .frame(width: 18, height: 18)
                .help("仅提示，不在这里清理")
        }
    }

    private var footer: some View {
        let allSelected = store.selectedCleanupIDs.count == store.eligibleItems.count
        let empty = store.selectedCleanupItems.isEmpty
        let needsQuit = store.selectedCleanupItems.filter { $0.risk == .b }
        return HStack(spacing: 10) {
            Button(allSelected ? "取消全选" : "全选") {
                withAnimation(.easeOut(duration: 0.15)) { allSelected ? store.clearCleanupSelection() : store.selectAllEligible() }
            }
            .keyboardShortcut("a", modifiers: .command)
            Button("只选可再生") {
                withAnimation(.easeOut(duration: 0.15)) { store.selectReusable() }
            }
            .help("uv、npm、Codex 运行时这类缓存：不用退出任何应用，下次用时自动重新下载")
            Rectangle().fill(Theme.line).frame(width: 1, height: 22).padding(.horizontal, 4)
            if store.isCleaning {
                ProgressView().controlSize(.small)
                Text("正在移入废纸篓 \(store.cleanedCount)/\(store.selectedCleanupItems.count)")
                    .monospacedDigit()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(empty ? "点任意一行即可选中" : "已选 \(store.selectedCleanupItems.count) 项 · \(ByteFormat.string(store.selectedCleanupBytes))")
                        .font(.system(size: empty ? 13 : 15, weight: .semibold))
                        .foregroundStyle(empty ? Theme.ink2 : Theme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if !needsQuit.isEmpty {
                        Text("含 \(needsQuit.count) 个应用缓存，先退出对应应用再清理")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.amber)
                    } else if !empty {
                        Text("都是可再生缓存，可直接清理")
                            .font(.system(size: 11))
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
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
    }

    private func cleanupReportBanner(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: report.movedCount > 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(report.movedCount > 0 ? Color.green : Theme.amber)
                Text(report.movedCount > 0
                     ? "已移入废纸篓 \(report.movedCount.formatted()) 项 · \(ByteFormat.string(report.movedBytes))"
                     : "没有项目被移动")
                    .font(.system(size: 13, weight: .semibold))
                if report.movedCount > 0 {
                    Text("清空废纸篓后才会真正释放空间").font(.system(size: 12)).foregroundStyle(Theme.ink3)
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
                                Text(failure.name).font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 8)
                                Text(failure.reason).font(.system(size: 11)).foregroundStyle(Theme.ink3)
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("\(report.failures.count) 项被系统拒绝，已跳过（不影响其他项）")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.leading, 24)
            }
        }
        .padding(12)
        .glass(radius: 12)
    }

    // MARK: Helpers

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

    private var cleanupReviewSheet: some View {
        let items = store.selectedCleanupItems
        let needsQuit = items.filter { $0.risk == .b }
        let appNames = Array(Set(needsQuit.map { ItemPresentation.info(for: $0).title })).sorted().prefix(4)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.accent)
                    .shadow(color: Theme.cyan.opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text("移入废纸篓").font(.system(size: 20, weight: .bold))
                    Text("共 \(items.count) 项 · \(ByteFormat.string(store.selectedCleanupBytes))，随时可以从废纸篓恢复")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                }
            }
            if !needsQuit.isEmpty {
                Label("其中 \(needsQuit.count) 项是应用缓存，请先退出：\(appNames.joined(separator: "、"))\(needsQuit.count > appNames.count ? " 等" : "")",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.amber)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        let info = ItemPresentation.info(for: item)
                        HStack(spacing: 10) {
                            itemIcon(item, image: info.icon).scaleEffect(0.8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(info.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                Text(shortPath(item.url))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Theme.ink3)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }
                            Spacer(minLength: 8)
                            Text(ByteFormat.string(item.bytes)).font(.system(size: 13, weight: .medium)).monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                    }
                }
            }
            .frame(height: min(CGFloat(items.count) * 54, 300))
            .glass(radius: 12)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack {
                Text("应用不会清空废纸篓，真正释放空间由你决定。")
                    .font(.system(size: 11))
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
