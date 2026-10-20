# Mac 清理管家（MacSpaceKeeper）

原生 SwiftUI 磁盘扫描/缓存清理 App。功能说明看 README.md。

## 版本与发布

- 版本号写在 `script/build_and_run.sh` 的 `APP_VERSION`，构建号取 git 提交数；改版本时同步在 `CHANGELOG.md` 顶部加一节（App「关于」页直接读这个文件，别另写一份）
- 作者 @沉默者之二、反馈邮箱在 `AboutView.swift` 的 `AppInfo`；「关于」三页（介绍 / 更新记录 / 反馈），竞品对比数据在 `Comparison`（2026-10-21 查官网与评测，查不到写「官网未提及」，别凭印象补）
- 磁盘可用空间一律**实时读** `volumeAvailableCapacityForImportantUsage`（与访达一致），不用扫描时存下的数
- GitHub 私有仓库：chenmozhe008/mac-cleanup-manager

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

## 分类与功能（2026-10-21）

- 分类（`ItemFilter`）：可放心清理（青）/ 剪辑与设计软件（粉）/ 微信与企业微信（绿）/ 需要你判断（琥珀）/ 大文件与工程（紫）
- 剪辑软件：AE / Final Cut / 达芬奇 / Blender 规则在 `CreativeApps.swift`；已安装的每个软件都单独一张卡，没缓存也显示「目前没有缓存」+ 缓存在哪 / 怎么清；快速扫描下 FCP、达芬奇标「完整扫描才查得到」
- 微信 / 企业微信：**只读量大小，永不提供删除**（`DiskScanner.chatAppUsage`）。专页每个软件一行：大小 + 状态 +「打开微信」在最上面；分步说明和「哪些能删」默认折叠，点「怎么清」展开（文案在 `ChatGuide`）
- 左栏位置**点击只切换、不扫描**：显示该位置上次结果（每个位置单独存 `results/<base64>.json`），旁边写「N 分钟前 / 昨天 / 未扫描」；没扫过显示「开始扫描」页；扫描只由右上「重新扫描」/「开始扫描」触发
- 记忆：选过的文件夹固定在左栏（UserDefaults `savedFolders`）；启动回到上次看的位置（`lastScope`）；上次看的分类 `lastFilter`；同范围上次检查项数用来估扫描进度
- 权限：用 `~/Library/Safari` 可读判断「完全磁盘访问」；未开启时左栏下方引导去开
- 结果页顶部：环形图 + 3×2 卡片，顺序与左栏一致（第 3 张＝微信与企业微信，超 2 GB 变琥珀；第 6 张＝这次能在这里清）；不再单独出微信提醒条
- 列表同名项（如几百个 __pycache__）合并成一行「N 处」，点行全选、⌄ 展开
- 磁盘剩余 < 5% 或 < 6 GB 环形图变琥珀并提示「空间紧张」
- 门槛：工程/应用数据 < 200 MB、「需要你判断」< 50 MB 不列；嵌套 node_modules 只列最外层；扫描页「边扫边发现」只显示 ≥ 5 MB

## 验证方法（不抢用户鼠标）

- 截图只截本 App 窗口：按 PID 取最大窗口 ID → `screencapture -l <id>`（不受其他窗口遮挡）
- 切分类：`defaults write com.forwardyan.MacSpaceKeeper lastFilter "<分类名>"` 后重开 App；**不要用模拟鼠标点击**，用户可能在用电脑（2026-10-20 点到过微信）

## 图标

- `Resources/AppIcon-source.png` 必须是**满版不透明正方形**（1024，无透明圆角）。macOS 26+ 会自动套圆角；带透明边的老式图标会被塞进灰色方框
- `Resources/AppIcon-artwork-transparent.png` 是原始带透明边的稿，只作素材留底
- 不要在代码里设置 `NSApplication.applicationIconImage`：会绕过系统圆角，Dock 显示成生硬方块
- 换图标后跑 `script/build_icon.sh`（打包脚本会在源图更新时自动跑）

## 清理结果提示

- 清理结果走 `CleanupReport`（结构化），不要把系统报错原文拼进 `message`
- 无法移动的目录（root 所有、系统保护）在扫描阶段就排除，不进可清理列表
