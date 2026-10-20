# Mac 清理管家（MacSpaceKeeper）

原生 SwiftUI 磁盘扫描/缓存清理 App。功能说明看 README.md。

## 构建与安装

- 打包：`./script/build_and_run.sh --package` → `dist/Mac 清理管家.app`
- 安装：覆盖到 `~/Applications/Mac 清理管家.app`（用户日常从这里打开）
- `dist/` 里只保留这一个 App；旧名字的包（如 `MacSpaceKeeper.app`）会被误开成旧版，发现就清掉
- `swift test` 在只有命令行工具（无 Xcode）的环境下会报 TestingMacros 插件缺失，属于环境问题

## 界面结构（2026-10-20 定稿：效果图 B「沉浸品牌感」）

定稿效果图在 `output/mockups/b-*.png`（HTML 源同目录）。改 UI 先对照效果图，大改先出新效果图给用户选，不在代码里一轮轮试。

- 深色蓝紫渐变底 + 磨砂玻璃卡片，配色和通用组件集中在 `Theme.swift`（`glass()`、`GlowBar`、`UsageRing`、按钮样式）
- 欢迎页：大图标 + 圆形发光「快速扫描」+ 底部磁盘容量卡；无侧栏
- 结果页：左侧栏（扫描位置 + 分类）；顶部环形图（磁盘可用）+ 2×2 统计卡（点卡片切分类）；下方列表，点行展开说明/路径/Finder；底部操作条
- 窗口用 `.hiddenTitleBar`，内容顶到标题栏，左上留红绿灯位置
- 列表交互：点行=选中（可清理项），行尾 ⓘ=展开详情；选中行青色底+左侧色条；底部「全选 ⌘A / 只选可再生」
- 条目显示名走 `ItemPresentation`（bundle id→App 名+图标，常见缓存目录→中文名），原始目录名留在副标题
- 分类色：可放心清理=青、需要你判断=琥珀、大文件与工程=紫
- 已删「目录占用」分类（用户看不懂、不可操作）；工程/应用数据 < 200 MB 不列入（`minProjectBytes`）

- 本机只有命令行工具，**`@State` 等 SwiftUI 宏编译不过**（缺 SwiftUIMacros 插件）。视图状态一律放进 `ScanStore` 的 `@Published`

## 图标

- `Resources/AppIcon-source.png` 必须是**满版不透明正方形**（1024，无透明圆角）。macOS 26+ 会自动套圆角；带透明边的老式图标会被塞进灰色方框
- `Resources/AppIcon-artwork-transparent.png` 是原始带透明边的稿，只作素材留底
- 不要在代码里设置 `NSApplication.applicationIconImage`：会绕过系统圆角，Dock 显示成生硬方块
- 换图标后跑 `script/build_icon.sh`（打包脚本会在源图更新时自动跑）

## 清理结果提示

- 清理结果走 `CleanupReport`（结构化），不要把系统报错原文拼进 `message`
- 无法移动的目录（root 所有、系统保护）在扫描阶段就排除，不进可清理列表
