import AppKit
import SwiftUI

enum AppInfo {
    static let author = "@沉默者之二"
    static let feedbackEmail = "327529709@qq.com"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    /// Pasted into feedback mails so problems can be reproduced.
    static var diagnostics: String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        return "Mac 清理管家 \(version)（\(build)）· macOS \(os)"
    }

    struct Release: Identifiable {
        let id: String
        let notes: [String]
    }

    /// Parsed from the bundled CHANGELOG.md ("## 版本 · 日期" headings, "- " bullets), the single source of the history.
    static var releases: [Release] {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var releases: [Release] = []
        var title: String?
        var notes: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") {
                if let title { releases.append(Release(id: title, notes: notes)) }
                title = String(line.dropFirst(3))
                notes = []
            } else if line.hasPrefix("- ") {
                notes.append(String(line.dropFirst(2)))
            }
        }
        if let title { releases.append(Release(id: title, notes: notes)) }
        return releases
    }

    static func sendFeedback() {
        let subject = "Mac 清理管家反馈 v\(version)"
        let body = "\n\n—— 请描述遇到的问题，最好附截图 ——\n\(diagnostics)"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

enum AboutTab: String, CaseIterable, Identifiable {
    case intro = "介绍"
    case changelog = "更新记录"
    case feedback = "反馈"
    var id: String { rawValue }
}

/// Competitor facts from official sites and 2025–2026 reviews (checked 2026-10-21).
/// Cells we could not verify show "—" instead of a guess.
private enum Comparison {
    static let products = ["CleanMyMac", "柠檬清理", "BuhoCleaner", "DaisyDisk", "Mac 清理管家"]
    static let rows: [(title: String, cells: [String])] = [
        ("价格", ["订阅制，约 $39.95/年起", "免费，开源", "买断约 $20–30；免费版只能自动清 3 GB", "$9.99 买断", "免费"]),
        ("怎么删", ["一键智能清理", "一键清理", "一键清理", "自己挑，直接永久删除", "逐项确认，只移入废纸篓，可找回"]),
        ("微信 / 企业微信", ["—", "深度扫描并清理聊天软件文件", "—", "只按文件夹看大小", "只看大小、不碰数据，教你在微信里清"]),
        ("剪辑软件缓存", ["—", "—", "—", "不区分", "AE / Final Cut / 达芬奇 / Blender 分开讲，该回软件清的给步骤"]),
        ("每一项看得懂吗", ["按类别汇总", "按类别汇总", "按类别汇总", "只有文件夹和大小", "App 图标 + 中文名 + 能不能删的理由"])
    ]
}

struct AboutView: View {
    @ObservedObject var store: ScanStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { store.showAbout = false }
            VStack(alignment: .leading, spacing: 0) {
                header
                tabs.padding(.top, 18)
                ScrollView {
                    Group {
                        switch store.aboutTab {
                        case .intro: intro
                        case .changelog: changelog
                        case .feedback: feedback
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .frame(width: 880, height: 724)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.11, green: 0.17, blue: 0.39), Color(red: 0.08, green: 0.11, blue: 0.24), Color(red: 0.14, green: 0.1, blue: 0.32)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
            .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
            .overlay(alignment: .topTrailing) {
                Button { store.showAbout = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .padding(16)
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private var header: some View {
        HStack(spacing: 16) {
            if let icon = Bundle.main.url(forResource: "AppIcon-source", withExtension: "png").flatMap(NSImage.init(contentsOf:)) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Theme.blue.opacity(0.6), radius: 14, y: 6)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text("Mac 清理管家").font(.system(size: 21, weight: .bold))
                    Text("v\(AppInfo.version)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.81, green: 0.88, blue: 1.0))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.blue.opacity(0.22)))
                        .overlay(Capsule().strokeBorder(Theme.blue.opacity(0.45)))
                }
                Text("作者 \(AppInfo.author) · 给做视频、做内容的人用的 Mac 清理工具")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(AboutTab.allCases) { tab in
                let on = store.aboutTab == tab
                Button { withAnimation(.easeOut(duration: 0.15)) { store.aboutTab = tab } } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13.5, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? .white : Theme.ink2)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? Theme.blue.opacity(0.32) : .clear))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(on ? Theme.blue.opacity(0.5) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("安全第一：先看清，再由你决定").font(.system(size: 20, weight: .bold))
                Text("只读扫描，逐项确认，只移入废纸篓。微信和剪辑工程这类删错就麻烦的东西，只告诉你在哪、怎么在原软件里处理。")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 12) {
                pillar(Theme.cyan, "删了能找回", "所有清理只移入废纸篓，从不自动清空；点整行选中，同名缓存合并成一行，一次看清。")
                pillar(Theme.pink, "懂剪辑软件", "AE、Final Cut、达芬奇、Blender 放在一起看：哪些这里能清，哪些要回软件里清、点哪几步。")
                pillar(Theme.green, "微信只看不删", "微信、企业微信占了多少一眼看到，超过 2 GB 提醒；聊天文件一个不碰，教你在微信里清。")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("和常见工具比").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink2)
                comparisonTable
                Text("以上信息整理自各产品官网和公开评测（2026 年 10 月），以各产品最新版本为准。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func pillar(_ tint: Color, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                GlowDot(color: tint)
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .glass(radius: 12)
    }

    private var comparisonTable: some View {
        let last = Comparison.products.count - 1
        return Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text("")
                ForEach(Array(Comparison.products.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(index == last ? Theme.cyan : Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(index == last ? Theme.cyan.opacity(0.08) : .clear)
                }
            }
            ForEach(Comparison.rows, id: \.title) { row in
                GridRow {
                    Text(row.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .fixedSize()
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { index, cell in
                        Text(cell)
                            .font(.system(size: 12.5, weight: index == last ? .medium : .regular))
                            .foregroundStyle(index == last ? Color.white : (cell == "—" ? Theme.ink3 : Theme.ink2))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(index == last ? Theme.cyan.opacity(0.08) : .clear)
                    }
                }
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            }
        }
        .glass(radius: 12)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Changelog

    private var changelog: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(AppInfo.releases.enumerated()), id: \.element.id) { index, release in
                let parts = release.id.components(separatedBy: " · ")
                let current = index == 0
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("v\(parts.first ?? release.id)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(current ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.08))))
                            .shadow(color: current ? Theme.cyan.opacity(0.5) : .clear, radius: 8)
                        if parts.count > 1 {
                            Text(parts[1]).font(.system(size: 11.5)).foregroundStyle(Theme.ink3)
                        }
                    }
                    .frame(width: 100, alignment: .trailing)
                    ZStack(alignment: .top) {
                        if index < AppInfo.releases.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 2).padding(.top, 10)
                        }
                        Circle()
                            .fill(current ? Theme.cyan : Theme.slate)
                            .frame(width: 10, height: 10)
                            .shadow(color: current ? Theme.cyan : .clear, radius: 6)
                            .padding(.top, 6)
                    }
                    .frame(width: 12)
                    VStack(alignment: .leading, spacing: 6) {
                        if current {
                            Text("当前版本")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Theme.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.green.opacity(0.12)))
                        }
                        ForEach(release.notes, id: \.self) { note in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").foregroundStyle(Theme.ink3)
                                Text(note)
                                    .font(.system(size: 13))
                                    .foregroundStyle(current ? Theme.ink : Theme.ink2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.bottom, 22)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Feedback

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("用得不顺手、扫得不对，直接告诉我").font(.system(size: 20, weight: .bold))
                Text("每封都会看。写清楚遇到什么、附一张截图，修起来最快。")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink2)
            }
            HStack(spacing: 10) {
                Button { AppInfo.sendFeedback() } label: { Label("发反馈邮件", systemImage: "envelope.fill") }
                    .buttonStyle(ToolbarButtonStyle(prominent: true))
                Button { AppInfo.copy(AppInfo.feedbackEmail) } label: { Label(AppInfo.feedbackEmail, systemImage: "doc.on.doc") }
                    .buttonStyle(ToolbarButtonStyle())
                    .help("复制邮箱")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("写反馈时最好带上").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink2)
                tip("1", "你在做什么：扫哪个位置、点了哪一步")
                tip("2", "看到了什么：最好截个图（⇧⌘4 截一块）")
                tip("3", "版本信息：点「发反馈邮件」会自动带上，也可以手动复制")
                HStack(spacing: 10) {
                    Text(AppInfo.diagnostics)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.ink3)
                        .textSelection(.enabled)
                    Button { AppInfo.copy(AppInfo.diagnostics) } label: { Label("复制版本信息", systemImage: "doc.on.doc") }
                        .buttonStyle(GhostButtonStyle())
                }
                .padding(.leading, 30)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(radius: 12)
        }
    }

    private func tip(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Theme.cyan)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.cyan.opacity(0.14)))
            Text(text).font(.system(size: 13.5))
        }
    }
}
