# Smart Screen 项目知识库

> 基于分层认知架构的结构化知识管理体系  
> **项目定位**：Screen Studio 的开源平替，专为 Mac 用户打造的本地智能录屏工具

## 🛠 技术栈

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| **语言** | Swift 5.9+ | Apple 官方推荐，现代并发支持 |
| **UI** | SwiftUI + AppKit | 主要 UI 用 SwiftUI，复杂窗口用 AppKit |
| **屏幕捕获** | ScreenCaptureKit | macOS 12.3+ 现代 API，硬件加速 |
| **音视频** | AVFoundation + VideoToolbox | 编码/解码/导出 |
| **GPU 加速** | Metal | Auto Zoom 渲染、实时特效 |
| **音频** | CoreAudio + AVAudioEngine | 低延迟捕获、混音处理 |
| **数据存储** | GRDB (SQLite) | 录制历史、预设管理 |
| **测试** | XCTest + Quick/Nimble | TDD 开发，BDD 风格测试 |

**系统要求**：macOS 13.0+ / Apple Silicon (M1/M2/M3/M4)

📖 详细技术栈说明：[`technology-stack.md`](04-AI-assets/AI-coding/rules/technology-stack.md)

## 📁 目录结构

```
knowledge-base/
├── 01-strategy-and-vision/      # L1: 战略与愿景（Why）
├── 02-business-and-domain/       # L2: 业务与领域（What）
├── 03-specifications/            # L3: 规格定义（How）
├── 04-AI-assets/                 # L4: AI 资源（How to Work）
└── templates/                    # 文档模板
```

## 🎯 四层架构

| 层级 | 目录 | 角色 | 本质 | 核心文档 |
|------|------|------|------|----------|
| **L1** | `01-strategy-and-vision/` | 决策者/产品负责人 | 方向约束 | 产品愿景、用户画像 |
| **L2** | `02-business-and-domain/` | 业务专家/架构师 | 问题空间建模 | 术语表、领域模型、业务流程、业务规则 |
| **L3** | `03-specifications/` | 工程团队 | 可实现的解空间 | 功能规格、UI规格、技术设计 |
| **L4** | `04-AI-assets/` | 全团队 | 人机协作方法论 | 编码规则、AI技能、工作流、脚本 |

## 📚 文档清单

### L1 - 战略与愿景
- [`product-vision.md`](01-strategy-and-vision/product-vision.md) - 产品愿景
- [`user-personas.md`](01-strategy-and-vision/user-personas.md) - 用户画像

### L2 - 业务与领域
- [`business-glossary.md`](02-business-and-domain/business-glossary.md) - 业务术语表
- [`domain-models/domain-model.md`](02-business-and-domain/domain-models/domain-model.md) - 领域模型
- [`business-processes/workflow.md`](02-business-and-domain/business-processes/workflow.md) - 业务流程
- [`business-rules/rules.md`](02-business-and-domain/business-rules/rules.md) - 业务规则

### L3 - 规格定义
- [`README.md`](03-specifications/README.md) - 功能规格说明指南

### L4 - AI 资源
- [`README.md`](04-AI-assets/README.md) - AI 资源说明
- **编码规则** (`AI-coding/rules/`)
  - [`technology-stack.md`](04-AI-assets/AI-coding/rules/technology-stack.md) - 技术栈推荐
  - [`swift-architecture.md`](04-AI-assets/AI-coding/rules/swift-architecture.md) - Swift 分层架构
  - [`testing-strategy.md`](04-AI-assets/AI-coding/rules/testing-strategy.md) - 测试策略
  - [`git-commit-standards.md`](04-AI-assets/AI-coding/rules/git-commit-standards.md) - Git 提交规范
- **开发工作流** (`AI-coding/workflows/`)
  - [`01-technical-solution.md`](04-AI-assets/AI-coding/workflows/01-technical-solution.md) - 技术方案
  - [`02-technical-tasking.md`](04-AI-assets/AI-coding/workflows/02-technical-tasking.md) - 任务拆解
  - [`03-tdd-implementation.md`](04-AI-assets/AI-coding/workflows/03-tdd-implementation.md) - TDD 实现

### 模板
- [`functional-specification-template.md`](templates/functional-specification-template.md) - 功能规格模板
- [`ui-specification-template.md`](templates/ui-specification-template.md) - UI 规格模板
- [`technical-design-template.md`](templates/technical-design-template.md) - 技术设计模板

## 🚀 快速开始

### 1. 创建新功能规格
```bash
# 创建功能目录
mkdir -p 03-specifications/{feature-name}

# 复制模板文件
cp templates/*.md 03-specifications/{feature-name}/
```

### 2. 文档维护原则
- ✅ **可追溯**：L3 必须引用 L1/L2 文档
- ✅ **及时更新**：业务变化同步更新各层
- ✅ **版本控制**：使用 Git 管理变更历史

## 📖 使用流程

```
L1 战略层 → L2 业务层 → L3 规格层 → L4 AI 资源层
   ↓           ↓           ↓            ↓
定义愿景    梳理业务    创建规格    沉淀规则
```

## 🔗 相关资源

- [技术栈推荐](./04-AI-assets/AI-coding/rules/technology-stack.md)
- [开发工作流](./04-AI-assets/AI-coding/workflows/)
- [编码规则](./04-AI-assets/AI-coding/rules/)
