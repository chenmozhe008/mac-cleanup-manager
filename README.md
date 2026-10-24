<div align="center">

<img src="docs/images/icon.png" width="128" alt="小清图标">

# 小清：Mac 清理工具

**Qingo**，AI 时代的 Mac 清理工具

认得 Cursor、Claude Code、Codex、剪映、达芬奇……缓存帮你清掉，工程、对话和模型原样留着。

![License: MIT](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-555)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-orange?logo=swift)

<img src="docs/images/overview-light.png" alt="总览（浅色）" width="900">

</div>

AI 工具和创作软件每天都在 Mac 上留下运行时、缓存和模型，动不动就是几个 GB。传统清理工具分不清哪些能重新生成、哪些是你的对话和作品。小清看得懂它们：能重新生成的帮你清掉，工程、对话和模型原样留着。

原生 SwiftUI 应用，浅色 / 深色自动切换，macOS 26 上使用系统液态玻璃。

## 它的优势

- **懂 AI Coding**：认得 Cursor、Claude Code、Codex、WorkBuddy、CodeBuddy、Trae、Qoder 等主流 AI Coding 和智能体工具，以及 Ollama、LM Studio 等本地模型。运行时、下载包、界面缓存可以清；Hugging Face、LM Studio 的模型可以挑着删；对话记录、工作区和扩展只统计、不删除。
- **也懂影视创作**：认得剪映、达芬奇、After Effects、Premiere、Final Cut、Blender 等剪辑和设计软件。剪映缓存、AE 磁盘缓存、Adobe 媒体缓存可以直接清；达芬奇、Final Cut 的渲染缓存告诉你在软件里怎么清；工程、草稿和素材不碰。
- **先确认，再清理**：每一项写明是什么、能不能删、为什么。勾选确认后才放进废纸篓，删错了随时拖回来；正在使用的文件自动跳过；不会替你清空废纸篓。
- **代码开源，跟得上新工具**：哪些会清、哪些不碰，规则都在代码里。不联网、不上传，扫描结果只留在你的 Mac 上。

## 截图

| 创作与 AI 工具：按工具区分缓存和作品 | 微信与企业微信：看占用，教你在微信里清 |
| --- | --- |
| <img src="docs/images/tools.png" alt="创作与 AI 工具"> | <img src="docs/images/wechat.png" alt="微信与企业微信"> |
| **扫描中：边扫边显示发现的内容** | **深色模式** |
| <img src="docs/images/scan.png" alt="扫描中"> | <img src="docs/images/overview-dark.png" alt="深色模式"> |

<p align="center"><img src="docs/images/about.png" alt="关于" width="720"></p>

## 能看到什么

| 分类 | 内容 | 能不能在这里清 |
| --- | --- | --- |
| 可清理缓存 | 应用缓存、npm / pip / uv 等包缓存、更新安装包 | 可以，逐项确认 |
| 创作与 AI 工具 | 按「剪辑与调色 / 设计与三维 / AI 生图与视频 / AI 助手 / AI Coding 与智能体 / 本地模型」分组 | 缓存可以，其余只统计 |
| 微信与企业微信 | 占用大小和在微信里清理的步骤 | 不删，只告诉你怎么清 |
| 需要判断 | `node_modules`、Python 虚拟环境、离线缓存等删了有影响的东西 | `node_modules` 和虚拟环境确认后可删，其余只显示 |
| 大文件与工程 | 1 GB 以上的大文件、工程文件、安装包（完整扫描） | 大文件和安装包确认后可删，工程文件不删 |

快速扫描只看常见缓存和已识别工具的目录，几秒到几十秒；完整扫描会检查整个用户目录。

## 安装与构建

要求：macOS 14 Sonoma 及以上，Apple 芯片（M1 及更新）。

目前没有预编译安装包，需要自己构建（需要 Xcode 或 Swift 命令行工具）：

```sh
git clone https://github.com/chenmozhe008/qingo.git
cd qingo
./script/build_and_run.sh --package   # 生成 dist/小清.app
./script/test.sh                      # 运行测试
```

本机有 Apple Development 证书时用它签名，没有时自动使用临时签名（ad-hoc），只能在自己的 Mac 上运行。要读取微信占用等受保护目录，需要在「系统设置 → 隐私与安全性 → 完全磁盘访问」里授权本应用。

## 加一个新工具

工具清单在 [`Sources/Qingo/CreativeApps.swift`](Sources/Qingo/CreativeApps.swift)。每个工具一行：

- `folders`：它在 `~/Library/Application Support` 和 `~/Library/Caches` 下的文件夹名
- `roots`：它在用户目录下的数据目录（只统计，不删除）
- `caches`：确定可以重新生成的缓存目录（可清理）

拿不准的路径只放进 `folders` 或 `roots`，不要放进 `caches`。欢迎提交 PR，记得附上路径来源。

## 安全边界

- 扫描只读，不跟随符号链接，不跨卷。
- 能清理的分两种：可以重新生成的缓存，可以一键全选；删了有影响的（`node_modules`、虚拟环境、大文件、安装包、单个模型），要一项项勾选，确认时写明删了会怎样。
- 清理前再次核对文件身份，检查相关应用是否在运行、文件是否被打开，任何一项不确定就跳过。
- 清理后可以撤销，把刚移走的放回原处。
- 清理只是「移入废纸篓」，不做永久删除。
- 聊天软件数据、凭据目录（`.ssh`、`.aws` 等）、工程文件始终受保护；Xcode 只清 DerivedData 构建缓存。

## 反馈

- [GitHub Issues](https://github.com/chenmozhe008/qingo/issues)
- 邮件：327529709@qq.com

更新记录见 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

[MIT](LICENSE) © 沉默者之二

> 小清原名「Mac 清理管家」，1.1.0 起改名。
