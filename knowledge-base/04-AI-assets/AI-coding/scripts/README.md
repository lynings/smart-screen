# AI Coding Scripts

本目录包含用于配置 AI 辅助编码环境的脚本。

## 脚本列表

### setup-cursor.sh

配置 Cursor IDE 以支持 AI Coding 资源（rules、workflows、skills）。

**功能：**
- 将 `rules/` 目录下的 `.md` 文件转换为 `.mdc` 并链接到 `.cursor/rules/`
- 将 `workflows/` 和 `skills/` 目录链接到 `.cursor/commands/`

**使用方法：**

```bash
# 在项目根目录运行
./knowledge-base/04-AI-assets/AI-coding/scripts/setup-cursor.sh
```

**生成的目录结构：**

```
.cursor/
├── rules/              # Cursor 自动应用的规则 (*.mdc)
│   ├── git-commit-standards.mdc
│   ├── swift-architecture.mdc
│   ├── technology-stack.mdc
│   └── testing-strategy.mdc
└── commands/           # Cursor 命令 (@workflows, @skills)
    ├── workflows/      # 分步指南
    └── skills/         # 可复用能力
```

## Cursor IDE 集成说明

### Rules（规则）

放置在 `.cursor/rules/` 下的 `.mdc` 文件会被 Cursor 自动加载为项目规则：
- 根据 frontmatter 中的 `alwaysApply: true` 自动应用
- 或通过 `description` 匹配上下文自动应用

### Commands（命令）

通过 `@` 引用 `.cursor/commands/` 下的内容：
- `@workflows/01-technical-solution` - 技术方案设计
- `@workflows/02-technical-tasking` - 技术任务拆分
- `@workflows/03-tdd-implementation` - TDD 实现

## 注意事项

1. 运行脚本会**覆盖**现有的 `.cursor/rules/` 和 `.cursor/commands/` 目录
2. 修改源文件后需要重新运行脚本以更新链接
3. `.cursor/` 目录应添加到 `.gitignore`（如果不想提交到版本控制）
