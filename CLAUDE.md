# Mac 清理管家（MacSpaceKeeper）

原生 SwiftUI 磁盘扫描/缓存清理 App。功能说明看 README.md。

## 构建与安装

- 打包：`./script/build_and_run.sh --package` → `dist/Mac 清理管家.app`
- 安装：覆盖到 `~/Applications/Mac 清理管家.app`（用户日常从这里打开）
- `dist/` 里只保留这一个 App；旧名字的包（如 `MacSpaceKeeper.app`）会被误开成旧版，发现就清掉
- `swift test` 在只有命令行工具（无 Xcode）的环境下会报 TestingMacros 插件缺失，属于环境问题

## 界面结构（2026-10-20 定）

原生三栏：左栏分类（`ItemFilter`）+ 磁盘余量，中间 `Table`，右侧 `.inspector` 详情，底部操作条。扫描范围菜单和重新扫描放在工具栏右侧；扫描统计放窗口副标题和左栏底部。不要再回到整页滚动、堆卡片和常驻说明文字的写法。

- 本机只有命令行工具，**`@State` 等 SwiftUI 宏编译不过**（缺 SwiftUIMacros 插件）。视图状态一律放进 `ScanStore` 的 `@Published`

## 图标

- `Resources/AppIcon-source.png` 必须是**满版不透明正方形**（1024，无透明圆角）。macOS 26+ 会自动套圆角；带透明边的老式图标会被塞进灰色方框
- `Resources/AppIcon-artwork-transparent.png` 是原始带透明边的稿，只作素材留底
- 不要在代码里设置 `NSApplication.applicationIconImage`：会绕过系统圆角，Dock 显示成生硬方块
- 换图标后跑 `script/build_icon.sh`（打包脚本会在源图更新时自动跑）

## 清理结果提示

- 清理结果走 `CleanupReport`（结构化），不要把系统报错原文拼进 `message`
- 无法移动的目录（root 所有、系统保护）在扫描阶段就排除，不进可清理列表
