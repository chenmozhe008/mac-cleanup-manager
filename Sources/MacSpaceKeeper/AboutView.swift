import AppKit
import SwiftUI

enum AppInfo {
    static let author = "@沉默者之二"
    static let feedbackEmail = "327529709@qq.com"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版"
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
        let subject = "Mac 清理管家反馈 v\(version)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(feedbackEmail)?subject=\(subject)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct AboutView: View {
    @ObservedObject var store: ScanStore

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                if let icon = Bundle.main.url(forResource: "AppIcon-source", withExtension: "png").flatMap(NSImage.init(contentsOf:)) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .shadow(color: Theme.blue.opacity(0.6), radius: 18, y: 8)
                }
                Text("Mac 清理管家").font(.system(size: 22, weight: .bold))
                Text("版本 \(AppInfo.version)").font(.system(size: 13)).foregroundStyle(Theme.ink2).textSelection(.enabled)
                Text("作者 \(AppInfo.author)").font(.system(size: 13)).foregroundStyle(Theme.ink2)
                HStack(spacing: 8) {
                    Button { AppInfo.sendFeedback() } label: {
                        Label("发反馈邮件", systemImage: "envelope.fill")
                    }
                    .buttonStyle(ToolbarButtonStyle(prominent: true))
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(AppInfo.feedbackEmail, forType: .string)
                    } label: {
                        Label(AppInfo.feedbackEmail, systemImage: "doc.on.doc")
                    }
                    .buttonStyle(ToolbarButtonStyle())
                    .help("复制邮箱")
                }
                .padding(.top, 6)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text("更新记录").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink2)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(AppInfo.releases) { release in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(release.id).font(.system(size: 14, weight: .semibold))
                                ForEach(release.notes, id: \.self) { note in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Circle().fill(Theme.cyan).frame(width: 5, height: 5).offset(y: -2)
                                        Text(note).font(.system(size: 12.5)).foregroundStyle(Theme.ink2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .glass(radius: 12)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 24)
            HStack {
                Spacer()
                Button("好") { store.showAbout = false }
                    .buttonStyle(GhostButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)
        }
        .frame(width: 520, height: 600)
        .foregroundStyle(Theme.ink)
        .background(Backdrop())
        .preferredColorScheme(.dark)
    }
}
