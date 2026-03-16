# Codex CLI - dbox 配置

Codex CLI 的 Docker 隔离运行封装，支持多环境配置。

## 使用方法

```bash
# 使用 `d` 命令（需先运行 ../install.sh）
d codex                 # 默认配置（自动创建）
d codex --version       # 带参数
d codex-work            # work 配置（自动创建）
d codex-work --version  # 带参数
```

## 权限跳过模式

> 注意：本配置默认开启 `--dangerously-bypass-approvals-and-sandbox`

Codex 运行在 dbox 的 Docker 沙箱内，宿主机访问范围由 `mappings` 精确限制，因此工具内部可以关闭二次审批。

如需关闭，可在工具或 profile 级别的 `env.local` 中设置：

```bash
NO_SKIP_PERMISSIONS=1
```

此时 `tool.sh` 会直接执行 `codex`，不附加危险模式参数。

## Profile 自动创建

任何不存在的 profile 都会自动从 `profiles/template` 创建。

## 持久化数据

每个 profile 会把自己的 `.codex/` 目录映射到容器内的 `/home/devuser/.codex`，因此以下状态都会按 profile 隔离保存：

- `config.toml`
- `auth.json`
- `sessions/`
- `memories/`
- 其他 Codex 本地状态文件

## 首次运行

首次运行时，`pre-exec` 会先安装 Node.js，再执行 `npm install -g @openai/codex`。

如果当前 profile 还没有初始化，启动时会询问是否配置三方 OpenAI 兼容接口。

选择三方时，会继续提示输入：

- `OPENAI_BASE_URL`
- `OPENAI_API_KEY`

如果不配置三方，则不写任何额外配置，直接交给 Codex 自己走官方登录或授权流程。

安装完成后，你可以直接在容器里执行：

```bash
codex
codex login
codex --help
```
