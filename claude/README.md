# Claude Code CLI - dbox 配置

Claude Code CLI 的 Docker 隔离运行封装，支持多环境配置。

## 使用方法

```bash
# 使用 `d` 命令（需先运行 ../install.sh）
d claude                 # 默认配置（自动创建）
d claude --version       # 带参数
d claude-zai             # zai 配置（自动创建）
d claude-zai --version   # 带参数
```

## 权限跳过模式

> ⚠️ **安全提示**：本配置默认开启 `--dangerously-skip-permissions` 标志

此标志会跳过 Claude Code 执行工具调用（如 Bash、文件读写等）时的权限确认提示。

### 设计理由

- **Docker 隔离**：所有操作都在容器内进行，主机环境已通过 volume mapping 精确控制
- **无破坏性路径**：容器内无法访问未映射的主机目录，风险可控
- **流畅体验**：避免频繁的权限确认，提升 AI 协作的连续性

### 安全边界

- 容器内只能访问 `mappings` 文件中声明的路径
- 默认工作目录 `{cwd}` 为你执行 `d` 命令的当前目录
- 持久化数据（如 `.local/`）存储在工具目录内，不会意外污染宿主环境

### 关闭权限跳过

如需关闭权限跳过模式，可在工具或 profile 级别的 `env.local` 中设置环境变量 `NO_SKIP_PERMISSIONS=1`。

**注意**：不能在 `.claude/settings.json` 中配置此变量，因为该文件只有 claude 应用会读取，`tool.sh` 脚本不会读取。

## Profile 自动创建

任何指定的 profile 名称如果不存在，会自动从 `template` 目录创建，无需手动操作。

## 配置

### 配置文件位置

首次使用时自动创建：

- `profiles/default/.claude/` - 默认配置
- `profiles/zai/.claude/` - zai API 配置
- `profiles/<any-name>/.claude/` - 任意名称配置

### 配置示例

`profiles/zai/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.zai.ai/v1",
    "ANTHROPIC_AUTH_TOKEN": "xxx"
  }
}
```

### 默认配置

Template 目录 `profiles/template/.claude/settings.json` 已预设以下配置：

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": 1
  },
  "skipDangerousModePermissionPrompt": true
}
```

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`: 启用 Claude Code 的实验性 Agent Teams 功能
- `skipDangerousModePermissionPrompt`: 跳过 --dangerously-skip-permissions 弹窗提示

## 目录结构

```
claude/
├── tool.sh         # 工具调用脚本
├── pre-exec        # 容器启动前执行的 hook
│                   # - 检查并安装 Claude CLI
│                   # - 交互式配置 API 端点和认证
├── mappings        # 目录映射配置
├── .local/         # 持久化安装数据
└── profiles/       # 环境配置
    ├── default/    # 默认 profile
    └── template/   # 模板目录（提交到 git）
        ├── .claude/
        └── mappings
```

## 调用流程

```
run.sh
  ↓ docker run
/sandbox/exec.sh
  ├─→ pre-exec hooks (tool → profile)
  ├─→ /sandbox/tool.sh → exec claude
  └─→ post-exec hooks (profile → tool) [claude 结束后]
```

## 工具调用脚本

`tool.sh` 是工具的实际入口，根据 `NO_SKIP_PERMISSIONS` 环境变量决定是否启用权限跳过：

- 默认：执行 `claude --dangerously-skip-permissions`
- 在 `env.local` 中设置 `NO_SKIP_PERMISSIONS=1`：执行 `claude`

## Pre-exec Hook

`pre-exec` hook 在容器启动后、Claude CLI 执行前运行，主要完成以下任务：

1. **检查并安装 Claude CLI**
   - 如果容器内未安装 `claude` 命令，使用官方脚本自动安装

2. **初始化配置**
   - 检查 `$HOME/.claude.json` 是否已完成 onboarding
   - 若未完成，提供交互式配置选项

3. **配置第三方 API（可选）**
   - 提示用户输入 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_MODEL`
   - 自动写入 `$HOME/.claude/settings.json`
   - 设置 `hasCompletedOnboarding` 和 `bypassPermissionsModeAccepted` 标记

这样设计的好处：

- 首次使用时自动安装和配置
- 支持任意兼容的 API 提供商（如 zai.ai）
- 配置持久化存储在 profile 目录中
