# Smart Screen

> 🎬 Screen Studio 的开源平替，专为 Mac 用户打造的本地智能录屏工具

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ 特性

- 🎯 **智能自动缩放** - 自动识别操作热点，平滑放大关键区域
- 🖱️ **光标平滑** - 消除鼠标抖动，生成丝滑轨迹
- 💫 **点击高亮** - 点击时显示脉冲动画
- 📹 **多模式录制** - 支持全屏/窗口/区域录制
- 🎨 **精美背景** - 渐变背景、自定义图像
- 📤 **多格式导出** - MP4/MOV/GIF，多预设支持

## 🚀 快速开始

### 系统要求

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4) 或 Intel Mac
- Xcode 15.0+

### 构建运行

```bash
# 克隆项目
git clone https://github.com/your-username/smart-screen.git
cd smart-screen

# 同意 Xcode 许可（首次）
sudo xcodebuild -license accept

# 用 Xcode 打开
open SmartScreen/Package.swift

# 或命令行构建
cd SmartScreen
swift build
swift test
```

## 📁 项目结构

```
smart-screen/
├── SmartScreen/                 # 应用源码
│   ├── Sources/
│   │   ├── App/                 # 应用入口
│   │   ├── Core/                # 核心模块
│   │   │   ├── Domain/          # 领域层
│   │   │   └── Infrastructure/  # 基础设施层
│   │   └── Features/            # 功能模块
│   └── Tests/                   # 测试
└── knowledge-base/              # 项目知识库
    ├── 01-strategy-and-vision/  # L1: 战略与愿景
    ├── 02-business-and-domain/  # L2: 业务与领域
    ├── 03-specifications/       # L3: 功能规格 ⭐
    └── 04-AI-assets/            # L4: AI 资源
```

## 🤖 开发方式：Spec-Driven Development

本项目采用 **Spec-Driven Development (SDD)** 开发方式，规格文档驱动开发。

### 核心流程

```
📋 Spec First → 🧪 TDD → 🚀 Ship
```

```
1. 需求分析     → 参考 L1/L2 文档
2. 编写规格     → 在 03-specifications/ 创建三个规格文档
3. 评审规格     → 团队/AI 评审
4. TDD 实现     → 按规格编写测试，再实现代码
5. 验收测试     → 按 AC 验收
```

### 规格文档位置

所有功能规格存放在 `knowledge-base/03-specifications/`：

```
03-specifications/
├── recording-engine/           # P1: 录屏引擎
│   ├── functional-spec.md      # 功能规格
│   ├── ui-spec.md              # UI 规格
│   └── technical-spec.md       # 技术设计
├── export-engine/              # P1: 导出引擎
├── cursor-enhancement/         # P2: 光标增强
├── auto-zoom/                  # P2: 自动缩放
└── README.md                   # 规格索引
```

### AI 协作方式

与 AI 协作开发时：

1. **先看规格**：AI 会先阅读 `03-specifications/` 中的规格文档
2. **遵循规则**：AI 会遵循 `04-AI-assets/AI-coding/rules/` 中的开发规范
3. **按工作流**：AI 会按照 `04-AI-assets/AI-coding/workflows/` 中的流程执行

```bash
# 典型的 AI 协作指令
"按照 recording-engine 的规格，实现屏幕捕获功能"
"参考 testing-strategy 规则，为 ExportEngine 编写测试"
```

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| **Swift 5.9+** | 编程语言 |
| **SwiftUI** | UI 框架 |
| **ScreenCaptureKit** | 屏幕捕获 |
| **AVFoundation** | 音视频处理 |
| **Metal** | GPU 加速渲染 |
| **CoreAudio** | 音频处理 |

## 📚 文档

### 知识库结构

| 层级 | 目录 | 内容 |
|------|------|------|
| L1 | `01-strategy-and-vision/` | 产品愿景、用户画像 |
| L2 | `02-business-and-domain/` | 术语表、领域模型、业务规则 |
| L3 | `03-specifications/` | **功能规格、UI规格、技术设计** |
| L4 | `04-AI-assets/` | 开发规则、工作流 |

### 核心文档

- [产品愿景](knowledge-base/01-strategy-and-vision/product-vision.md)
- [功能规格索引](knowledge-base/03-specifications/README.md) ⭐
- [技术栈规范](knowledge-base/04-AI-assets/AI-coding/rules/technology-stack.md)
- [架构规范](knowledge-base/04-AI-assets/AI-coding/rules/swift-architecture.md)
- [测试策略](knowledge-base/04-AI-assets/AI-coding/rules/testing-strategy.md)
- [TDD 实现工作流](knowledge-base/04-AI-assets/AI-coding/workflows/03-tdd-implementation.md)

## 🗺️ 路线图

### Phase 1: MVP ✅ 完成
- [x] 项目结构初始化
- [x] 知识库建立
- [x] 规格文档编写
- [x] 录屏引擎（全屏）
- [x] 麦克风音频录制
- [x] 基本导出（MP4）

### Phase 2: 体验增强 ✅ 完成
- [x] Cursor Smoothing
- [x] Click Highlight
- [x] Auto Zoom (v3.1 - 含跟随模式)
- [ ] Timeline 基础剪辑

### Phase 3: 进阶功能
- [ ] 区域/窗口录制
- [ ] Webcam Overlay
- [ ] System Audio Capture
- [ ] GIF 导出
- [ ] 社媒预设

## 🤝 贡献

欢迎贡献！开发前请先：

1. 阅读 [功能规格](knowledge-base/03-specifications/)
2. 遵循 [开发规则](knowledge-base/04-AI-assets/AI-coding/rules/)
3. 按照 [TDD 工作流](knowledge-base/04-AI-assets/AI-coding/workflows/03-tdd-implementation.md) 实现

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 🙏 致谢

- [Screen Studio](https://www.screen.studio/) - 灵感来源
- Apple Developer Documentation
