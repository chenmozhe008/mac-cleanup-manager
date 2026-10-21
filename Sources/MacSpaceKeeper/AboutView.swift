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

    /// Matches LSMinimumSystemVersion and the arm64-only build.
    static let requirements = "macOS 14 Sonoma 及以上，Apple 芯片（M1 及更新）的 Mac。扫描范围取决于已授予的文件访问权限"

    static func sendFeedback() {
        let subject = "Mac 清理管家反馈 v\(version)"
        let body = "\n\n（请在这里描述遇到的问题，最好附一张截图）\n\(diagnostics)"
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
    enum Mark { case good, partial, bad, none }
    struct Cell { let mark: Mark; let text: String }
    static func c(_ mark: Mark, _ text: String) -> Cell { Cell(mark: mark, text: text) }

    /// Ours first, so the eye lands on it.
    static let products = ["Mac 清理管家", "CleanMyMac", "柠檬清理", "BuhoCleaner", "DaisyDisk"]
    static let rows: [(title: String, cells: [Cell])] = [
        ("价格", [c(.good, "免费"), c(.partial, "订阅，约 $39.95/年起"), c(.good, "免费，开源"), c(.partial, "买断约 $20–30"), c(.partial, "$9.99 买断")]),
        ("删错了能找回", [c(.good, "放进废纸篓，随时找回"), c(.none, "一键清理"), c(.none, "一键清理"), c(.none, "一键清理"), c(.bad, "直接永久删除")]),
        ("AI Coding 与影视工具", [c(.good, "认得主流工具，缓存可清、作品只读"), c(.none, "—"), c(.none, "—"), c(.none, "—"), c(.bad, "不区分")]),
        ("微信 / 企业微信", [c(.good, "看占用，教你在微信里清"), c(.none, "—"), c(.good, "扫描并清理聊天文件"), c(.none, "—"), c(.partial, "只显示文件夹大小")]),
        ("每一项说得清", [c(.good, "中文名、能不能删、为什么"), c(.partial, "按类别汇总"), c(.partial, "按类别汇总"), c(.partial, "按类别汇总"), c(.bad, "只有文件夹名")])
    ]
}

struct AboutView: View {
    @ObservedObject var store: ScanStore

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { store.showAbout = false }
                VStack(alignment: .leading, spacing: 0) {
                    header.padding(24)
                    tabs.padding(.horizontal, 24).padding(.bottom, 18)
                    Divider()
                    ScrollView {
                        Group {
                            switch store.aboutTab {
                            case .intro: intro
                            case .changelog: changelog
                            case .feedback: feedback
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                    }
                    .id(store.aboutTab)
                }
                .frame(width: min(860, max(320, geometry.size.width - 48)),
                       height: min(760, max(320, geometry.size.height - 48)))
                .background(Theme.base)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line))
                .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(Theme.ink)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            SidebarBrandMark(size: 60)
            VStack(alignment: .leading, spacing: 5) {
                Text("Mac 清理管家").font(.system(size: 24, weight: .bold))
                Text("AI 时代的 Mac 清理工具")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Theme.blue, Theme.indigo], startPoint: .leading, endPoint: .trailing))
                Text("v\(AppInfo.version) · 作者 \(AppInfo.author)")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 8)
            Button { store.showAbout = false } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.fill(0.06)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("关闭关于与反馈")
            .help("关闭（Esc）")
        }
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(AboutTab.allCases) { tab in
                let on = store.aboutTab == tab
                Button { store.aboutTab = tab } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(on ? Color.white : Theme.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 8).fill(on ? Theme.blue : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.fill(0.05)))
    }

    // MARK: Intro

    /// Order the user asked for: what it is → strengths (AI first, film as the bonus) → comparison.
    private var intro: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("它的优势").font(.system(size: 18, weight: .bold))
                advantage("懂 AI Coding", nil, "chevron.left.forwardslash.chevron.right", Theme.blue,
                          "认得 Cursor、Claude Code、Codex、WorkBuddy、CodeBuddy、Trae、Qoder 等主流 AI Coding 和智能体工具，也认得 Ollama、LM Studio 等本地模型。",
                          clean: "运行时、下载包、界面缓存，删了会自动重新生成",
                          keep: "对话记录、工作区、扩展和模型，只统计、不删除")
                advantage("也懂影视创作", nil, "film.stack.fill", Theme.pink,
                          "认得剪映、达芬奇、After Effects、Premiere、Final Cut、Blender 等主流剪辑和设计软件。",
                          clean: "剪映缓存、AE 磁盘缓存、Adobe 媒体缓存可以直接清；达芬奇、Final Cut 的渲染缓存，告诉你在软件里怎么清",
                          keep: "工程、草稿和素材，一个不碰")
                advantage("先确认，再清理", nil, "checkmark.shield.fill", Theme.green,
                          "每一项都写明是什么、能不能删、为什么。",
                          clean: "你勾选确认后才放进废纸篓，删错了随时拖回来",
                          keep: "正在使用的文件自动跳过，也不会替你清空废纸篓")
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("对比与说明").font(.system(size: 18, weight: .bold))
                comparisonTable
                Text("资料整理于 2026 年 10 月，价格和功能以各产品官方说明为准。")
                    .font(.system(size: 13)).foregroundStyle(Theme.ink2)
            }

            Label(AppInfo.requirements, systemImage: "laptopcomputer")
                .font(.system(size: 13)).foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One strength: what it knows, then the two-line rule (what gets cleaned / what is kept).
    private func advantage(_ title: String, _ badge: String?, _ symbol: String, _ tint: Color, _ description: String,
                           clean: String, keep: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            IconTile(symbol: symbol, tint: tint, size: 40)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 17, weight: .bold))
                    if let badge {
                        Text(badge)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(tint.opacity(0.12)))
                    }
                }
                Text(description)
                    .font(.system(size: 14)).foregroundStyle(Theme.ink2)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 6) {
                    ruleLine("checkmark.circle.fill", Theme.green, clean)
                    ruleLine("lock.fill", Theme.amber, keep)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glass(radius: 14)
    }

    private func ruleLine(_ symbol: String, _ tint: Color, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(tint).frame(width: 16)
            Text(text).font(.system(size: 13.5)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var comparisonTable: some View {
        let ours = 0
        return Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear.frame(width: 1, height: 1).gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(Array(Comparison.products.enumerated()), id: \.offset) { index, name in
                    Text(name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(index == ours ? Color.white : Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(index == ours ? AnyShapeStyle(Theme.blue) : AnyShapeStyle(Color.clear))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10))
                }
            }
            ForEach(Array(Comparison.rows.enumerated()), id: \.offset) { rowIndex, row in
                if rowIndex > 0 { Rectangle().fill(Theme.line).frame(height: 1).gridCellUnsizedAxes(.horizontal) }
                GridRow {
                    Text(row.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 110, alignment: .leading)
                        .padding(.vertical, 12)
                        .frame(maxHeight: .infinity, alignment: .center)
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { index, cell in
                        comparisonCell(cell, ours: index == ours)
                            .background(index == ours ? Theme.blue.opacity(0.09) : .clear)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .glass(radius: 12)
    }

    private func comparisonCell(_ cell: Comparison.Cell, ours: Bool) -> some View {
        let symbol: String? = switch cell.mark {
        case .good: "checkmark.circle.fill"
        case .partial: "minus.circle.fill"
        case .bad: "xmark.circle.fill"
        case .none: nil
        }
        let tint: Color = switch cell.mark {
        case .good: Theme.green
        case .partial: Theme.amber
        default: Theme.ink3
        }
        return VStack(spacing: 5) {
            // Keep text on the same line across a row whether or not the cell has a mark.
            Image(systemName: symbol ?? "circle").font(.system(size: 15)).foregroundStyle(tint).opacity(symbol == nil ? 0 : 1)
            Text(cell.text)
                .font(.system(size: 13, weight: ours ? .semibold : .regular))
                .foregroundStyle(ours ? Theme.ink : (cell.mark == .none ? Theme.ink3 : Theme.ink2))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                            .foregroundStyle(current ? Color.white : Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(current ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.fill(0.08))))

                        if parts.count > 1 {
                            Text(parts[1]).font(.system(size: 11.5)).foregroundStyle(Theme.ink3)
                        }
                    }
                    .frame(width: 100, alignment: .trailing)
                    ZStack(alignment: .top) {
                        if index < AppInfo.releases.count - 1 {
                            Rectangle().fill(Theme.fill(0.1)).frame(width: 2).padding(.top, 10)
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
                Text("用着不顺手，或者扫得不对，都可以告诉我").font(.system(size: 20, weight: .bold))
                Text("每一封我都会看。说清楚遇到了什么，再附一张截图，我能更快找到问题。")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink2)
            }
            HStack(spacing: 10) {
                Button { AppInfo.sendFeedback() } label: { Label("发反馈邮件", systemImage: "envelope.fill") }
                    .buttonStyle(ToolbarButtonStyle(prominent: true))
                let emailCopied = store.copiedText == AppInfo.feedbackEmail
                Button { store.copy(AppInfo.feedbackEmail) } label: {
                    Label(emailCopied ? "已复制邮箱" : AppInfo.feedbackEmail, systemImage: emailCopied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(emailCopied ? Theme.green : Theme.ink)
                }
                    .buttonStyle(ToolbarButtonStyle())
                    .help("复制邮箱")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("写反馈时最好包括").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink2)
                tip("1", "当时在做什么，比如扫的是哪个位置、点了哪个按钮")
                tip("2", "看到了什么，最好附一张截图（按 ⇧⌘4 可以截取一块区域）")
                tip("3", "版本信息。点「发反馈邮件」会自动附上，也可以在下面复制")
                VStack(alignment: .leading, spacing: 10) {
                    Text(AppInfo.diagnostics)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    let infoCopied = store.copiedText == AppInfo.diagnostics
                    Button { store.copy(AppInfo.diagnostics) } label: {
                        Label(infoCopied ? "已复制" : "复制版本信息", systemImage: infoCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(infoCopied ? Theme.green : Theme.ink)
                    }
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
            Text(text).font(.system(size: 13.5)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
