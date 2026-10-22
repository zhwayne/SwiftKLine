# 参与贡献

[English](CONTRIBUTING.md) | **简体中文**

欢迎提交可复现的问题报告、聚焦的修复、新示例、文档和翻译。对于较大的功能或公开 API 变更，请先通过 issue 说明使用场景，再投入大规模实现。

## 报告问题与建议功能

请使用 [GitHub Issues](https://github.com/zhwayne/SwiftKLine/issues)。缺陷报告请包含：

- 最小复现，以及预期行为与实际行为。
- 设备或模拟器、系统版本、Xcode 与 Swift 版本。
- 数据源、K 线周期、启用的指标和相关配置。
- 复现步骤、有用日志，必要时附截图或 trace。

附件请移除凭据和账户数据。功能建议请说明场景、当前替代方式及期望的 API 行为。欢迎使用中文或英文提交。

## 准备开发环境

```sh
git clone https://github.com/zhwayne/SwiftKLine.git
cd SwiftKLine
open SwiftKLineExample.xcodeproj
```

使用 Swift 6 和 Xcode 16 或更新版本，仓库当前使用 Xcode 26.2 验证。UI 测试需要通过 Xcode 安装 iPhone 模拟器运行时。库支持 iOS 13+，示例要求 iOS 18+。Core 测试和基准可在 macOS 上运行。

## 构建与测试

| 命令 | 用途 |
|---|---|
| `swift test` | Foundation 代码的宿主机测试 |
| `./script/test-ios.sh` | 在 iPhone 模拟器运行包测试，包含 UIKit 和示例生命周期路径 |
| `./script/build-example.sh` | 构建通用 iOS Simulator 示例应用 |
| `./script/validate-docs.py` | 检查本地链接、标题锚点、双语页面覆盖和可执行片段一致性 |

`test-ios.sh` 自动选择可用 iPhone；可通过 `SWIFTKLINE_DESTINATION` 覆盖，例如 `platform=iOS Simulator,name=iPhone 17`。两个 shell 脚本均支持用 `SWIFTKLINE_DERIVED_DATA` 指定构建输出。

根据改动选择测试：公式和合并改动运行 Core 测试；UI、插件、会话和生命周期行为运行模拟器测试。在 PR 中记录命令与结果。

## 代码与 API 约定

- Core 仅依赖 Foundation。UIKit 协调和绘制放在 `SwiftKLineUI`，SwiftUI 适配层保持轻量。
- 分离计算、网络传输和绘制。交易所认证、账户模型和成交语义属于应用。
- 遵守 `MainActor`、`Sendable` 和结构化取消约束，不用 unchecked 标注掩盖所有权问题。
- 更新时保留语义身份。数据源 ID 描述数据和日历含义，插件 ID 描述稳定功能。
- 遵循现有 Swift 格式和英文 API 注释。移动源码时保留原始创建日期。
- 身份、分页、取消和发布行为变化需要回归覆盖。

状态归属见[架构](docs/zh-CN/architecture.md)，测量要求见[性能](docs/zh-CN/performance.md)。

## 文档与翻译

行为或公开 API 变化时同步更新两种语言：

| English | 简体中文 |
|---|---|
| `README.md` | `README.zh-CN.md` |
| `CONTRIBUTING.md` | `CONTRIBUTING.zh-CN.md` |
| `CHANGELOG.md` | `CHANGELOG.zh-CN.md` |
| `docs/*.md` | `docs/zh-CN/*.md` |

页首语言切换应指向同一主题的对应页面，指南内部导航保留当前语言。两种语言中的 Swift 示例保持一致，确保介绍相同 API。使用成交标记类型的片段属于示例应用，而非公开库。

修改链接或示例后运行 `./script/validate-docs.py`。在引用当前库的 iOS 应用 target 中，以 Swift 6 并发检查编译使用示例。文档示例不代替运行时测试。

## 提交 Pull Request

1. 创建主题分支，保持改动聚焦。
2. 说明问题、变更后的行为及 API 影响。
3. 更新受影响指南，在两份变更记录的 `Unreleased` 下添加条目。
4. 运行相关检查并说明结果与限制。
5. 检查差异，移除生成文件、DerivedData、凭据和无关改动。

提交信息遵循仓库已有风格，例如 `feat(indicator): ...`、`fix(loader): ...` 或 `docs: ...`。性能改动应说明硬件、构建模式、数据量和方法，并区分算法基准与设备交互测量。

讨论请相互尊重、围绕具体工作展开。审查可能要求调整模块边界、生命周期清理、API 范围或文档准确性。

## 许可证

贡献内容按项目的 [MIT 许可证](LICENSE) 分发。
