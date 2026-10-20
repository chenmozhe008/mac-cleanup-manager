import Foundation

/// Editing / design apps whose caches get their own "剪辑与设计软件" category.
enum CreativeApp: String, CaseIterable, Sendable {
    case afterEffects
    case finalCut
    case davinci
    case blender

    var title: String {
        switch self {
        case .afterEffects: "After Effects"
        case .finalCut: "Final Cut Pro"
        case .davinci: "DaVinci Resolve"
        case .blender: "Blender"
        }
    }

    var bundleID: String {
        switch self {
        case .afterEffects: "com.adobe.AfterEffects.application"
        case .finalCut: "com.apple.FinalCut"
        case .davinci: "com.blackmagic-design.DaVinciResolve"
        case .blender: "org.blenderfoundation.blender"
        }
    }

    /// One-line hint under the app name.
    var hint: String {
        switch self {
        case .afterEffects: "先退出 AE 再清理；也可在 AE 里：编辑 → 清理 → 所有内存与磁盘缓存"
        case .finalCut: "渲染文件在资源库里，只能在 Final Cut 里删"
        case .davinci: "CacheClip 要在达芬奇里删"
        case .blender: "先退出 Blender 再清理"
        }
    }

    /// Steps for items that must be cleaned inside the app.
    var inAppSteps: [String] {
        switch self {
        case .finalCut: ["在侧栏选中资源库", "文件", "删除已生成的资源库文件…", "勾「删除渲染文件 · 仅未使用的」"]
        case .davinci: ["打开对应项目", "播放", "删除渲染缓存", "未使用的 / 全部"]
        default: []
        }
    }

    /// Where this app keeps its caches (shown when nothing was found).
    var cacheWhere: String {
        switch self {
        case .afterEffects: "磁盘缓存在 AE「设置 → 媒体和磁盘缓存」指定的文件夹；媒体缓存在 Adobe/Common 里"
        case .finalCut: "渲染文件在每个资源库（.fcpbundle）里，外接盘上的资源库要扫那块盘"
        case .davinci: "CacheClip 默认在 ~/Movies/CacheClip，也可能在项目设置里指定的位置"
        case .blender: "~/Library/Caches/Blender"
        }
    }

    /// How to clean from inside the app.
    var cleanHow: String {
        switch self {
        case .afterEffects: "AE 里：编辑 → 清理 → 所有内存与磁盘缓存"
        case .finalCut: "Final Cut 里：选中资源库 → 文件 → 删除已生成的资源库文件"
        case .davinci: "达芬奇里：播放 → 删除渲染缓存"
        case .blender: "退出 Blender 后，这里扫到就能直接清"
        }
    }

    var shortName: String {
        switch self {
        case .afterEffects: "AE"
        case .finalCut: "Final Cut"
        case .davinci: "达芬奇"
        case .blender: "Blender"
        }
    }

    /// Render caches stay listed at any size so the creative page shows they were checked.
    static func isReviewCache(_ url: URL) -> Bool {
        url.lastPathComponent == "CacheClip" || (url.lastPathComponent == "Render Files" && url.path.contains(".fcpbundle/"))
    }

    static func of(_ item: ScanItem) -> CreativeApp? {
        let path = item.url.path
        if path.contains("/Library/Caches/Adobe/After Effects/") || path.contains("/Library/Application Support/Adobe/Common/") {
            return .afterEffects
        }
        if item.name == "Render Files", path.contains(".fcpbundle/") { return .finalCut }
        if item.name == "CacheClip" { return .davinci }
        if path.hasSuffix("/Library/Caches/Blender") { return .blender }
        return nil
    }
}

/// Chat apps are never cleaned here; this is the guide shown on their page.
enum ChatGuide {
    static func steps(for bundleID: String) -> [String] {
        switch bundleID {
        case "com.tencent.xinWeChat":
            ["点微信左下角「≡」", "设置", "存储空间", "先点「清理缓存」：图片缩略图等临时文件，不影响聊天记录",
             "再点「管理」：按聊天看谁占得多，勾选不要的视频、文件删除"]
        default:
            ["点企业微信左上角头像", "设置", "通用 → 存储空间", "先清理缓存：不影响聊天记录",
             "再按聊天查看大文件，勾选不要的删除"]
        }
    }

    static let tips: [(symbol: String, tint: String, text: String)] = [
        ("checkmark.circle.fill", "green", "缓存：清了会自动重新下载，不影响聊天记录，放心清"),
        ("exclamationmark.circle.fill", "amber", "聊天里的视频、文件：删前确认已经另存，删了就没了"),
        ("xmark.circle.fill", "pink", "聊天记录：想留的先在「设置 → 聊天记录备份」备份到手机或电脑")
    ]
}
