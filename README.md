# dbox

通过 Docker 容器实现安全隔离的工具运行框架。

## 目录结构

```
dbox/
├── dbox.sh               # 统一入口脚本
├── Dockerfile            # 基础镜像
├── exec.sh               # 容器入口
├── completion            # 自动补全
├── install.sh            # 安装脚本
│
├── <tool>/               # 工具目录
│   ├── tool.sh           # 工具执行脚本（必需）
│   ├── service.sh        # 服务启动脚本（服务型工具必需）
│   ├── config            # 工具配置（可选）
│   ├── profiles/         # 环境配置
│   └── ...
│
├── mappings              # 全局目录映射配置（可选）
├── env                   # 全局环境变量（可选）
└── ...
```

## 快速开始

```bash
# 1. 安装（创建符号链接 ~/.local/bin/d）
./install.sh

# 2. 确保在 PATH 中
# 在 ~/.bashrc 或 ~/.zshrc 中添加
export PATH="$HOME/.local/bin:$PATH"

# 3. 启用自动补全（可选）
# 在 ~/.bashrc 或 ~/.zshrc 中添加
source /path/to/dbox/completion

# 4. 使用
d claude                 # 运行 claude (默认配置)
d claude-zai             # 运行 claude (zai 配置)
d claude --version       # 带参数运行
d -s claude              # 启动 claude 容器 shell
d -u openclaw            # 启动 openclaw 服务（待实现）
```

## 命令格式

```bash
d [flags] [tool[-profile]] [args...]
```

### 标志

| 标志            | 说明                       |
| --------------- | -------------------------- |
| `-u, --up`      | 启动服务（服务型工具）     |
| `-d, --down`    | 停止服务（服务型工具）     |
| `-r, --restart` | 重启服务（服务型工具）     |
| `-l, --list`    | 列出运行中的服务型工具容器 |
| `-s, --shell`   | 启动容器 shell             |
| `-h, --help`    | 显示帮助                   |
| `-v, --version` | 显示版本                   |

### 参数

- `tool` - 工具名称
- `profile` - 配置名称（可选，默认 `default`），用 `-` 与工具名连接
- `args` - 传递给工具的参数

### 示例

```bash
d claude                    # 运行 claude (默认配置)
d claude-zai                # 运行 claude (zai 配置)
d claude --version          # 带参数运行
d -s claude                 # 启动 claude 容器 shell
d -u openclaw               # 启动 openclaw 服务（待实现）
```

## 工具类型

### 命令型工具

每次运行创建临时容器，执行完毕后自动删除。

**必需文件：**

- `<tool>/tool.sh` - 工具执行脚本

### 服务型工具

通过 `d -u <tool>` 启动持久化服务容器。容器运行后，可通过 `d <tool> [args...]` 在该容器中执行其他命令。

**必需文件：**

- `<tool>/service.sh` - 服务启动脚本
- `<tool>/tool.sh` - 工具执行脚本（可选，用于在服务容器中执行命令）

**容器特性：**

- 容器名称：`dbox-<tool>-<profile>`
- 自动重启：`--restart unless-stopped`
- 优雅退出：30 秒

## 自动补全

dbox 提供了 bash 和 zsh 的自动补全支持。

**启用方法：**

在 `~/.bashrc` 或 `~/.zshrc` 中添加：

```bash
source /path/to/dbox/completion
```

**使用效果：**

```bash
d <Tab>                # 列出所有标志和工具
d -u <Tab>             # 列出所有工具
d claude-<Tab>         # 列出 claude 工具的所有 profile
```

## Profile 自动创建

当指定的 profile 不存在时：

- **default 配置**：自动从 `template` 创建，无需确认
- **其他配置**：询问是否从 `template` 创建

## 容器内结构

容器运行时通过 volume mounts 动态构建 `/sandbox/` 目录：

```
/sandbox/
├── entrypoint         # 入口脚本（从 exec.sh 挂载）
├── tool.sh            # 工具执行脚本（从工具目录挂载）
├── service.sh         # 服务启动脚本（服务型工具，从工具目录挂载）
├── hooks/             # Hook 文件挂载点
│   ├── global-pre-exec
│   ├── tool-pre-exec
│   ├── profile-pre-exec
│   └── ...
└── env/               # 环境变量文件挂载点
    ├── global
    ├── tool
    └── profile
```

## 架构说明

### 工具目录结构

```
<tool>/
├── tool.sh            # 工具执行脚本（必需）
├── service.sh         # 服务启动脚本（服务型工具必需）
├── config             # 工具配置（可选）
├── pre-exec           # 工具级 pre-exec hook（可选）
├── pre-exec.local     # 工具级 pre-exec hook（本地，可选）
├── post-exec          # 工具级 post-exec hook（可选）
├── post-exec.local    # 工具级 post-exec hook（本地，可选）
├── mappings           # 工具级目录映射配置
├── mappings.local     # 工具级目录映射配置（本地，可选）
├── env                # 工具级环境变量（可选）
├── env.local          # 工具级环境变量（本地，可选）
├── data/              # 持久化数据（不提交到 git）
└── profiles/
    └── template/      # 模板目录（提交到 git）
```

### 工具配置 (config)

`<tool>/config` 文件用于设置工具特定的行为：

```bash
# 在 iTerm2 中使用 tmux -CC
TMUX_IN_ITERM=true
```

### Profile 目录结构

每个 profile 从 template 创建：

```
profiles/<profile>/
├── mappings           # 目录映射配置
├── mappings.local     # 目录映射配置（本地，可选）
├── pre-exec           # profile 级 pre-exec hook（可选）
├── pre-exec.local     # profile 级 pre-exec hook（本地，可选）
├── post-exec          # profile 级 post-exec hook（可选）
├── post-exec.local    # profile 级 post-exec hook（本地，可选）
├── env                # profile 级环境变量（可选）
├── env.local          # profile 级环境变量（本地，可选）
└── ...                # 其他配置文件
```

### Hook 执行顺序

**pre-exec（从低到高优先级）：**

1. 全局 pre-exec
2. 全局 pre-exec.local
3. 工具级 pre-exec
4. 工具级 pre-exec.local
5. Profile 级 pre-exec
6. Profile 级 pre-exec.local
7. 执行命令

**post-exec（倒序）：**

1. Profile 级 post-exec.local
2. Profile 级 post-exec
3. 工具级 post-exec.local
4. 工具级 post-exec
5. 全局 post-exec.local
6. 全局 post-exec

## 映射配置格式

`mappings` 文件格式（每行一个映射）：

```
# 注释以 # 开头
# 格式：
#   f:主机路径:容器路径  (文件映射，不存在时创建空文件)
#   d:主机路径:容器路径  (目录映射，不存在时自动创建目录)
#   p:主机端口:容器端口  (端口映射，仅服务型工具的 profile 级别)

# 目录映射示例
d:data/.config:/home/devuser/.config
d:data/.local:/home/devuser/.local

# 单个配置文件映射
f:.claude.json:/home/devuser/.claude.json

# 相对路径相对于所属目录（全局/工具/profile）
d:.claude:/home/devuser/.claude

# 特殊变量 {cwd} 表示当前工作目录
d:{cwd}:{cwd}

# 端口映射（仅服务型工具，仅 profile 级别生效）
# p:8080:8080
# p:3001:3000
```

**注意：** 端口映射 (`p:...`) 仅在服务型工具的 profile 级别 mappings 中生效，在其他级别定义会导致错误。
## 添加新工具

### 命令型工具

```bash
# 1. 创建工具目录
mkdir -p mytool/profiles/template

# 2. 添加 tool.sh
cat > mytool/tool.sh << 'EOF'
#!/bin/bash
exec my-tool "$@"
EOF
chmod +x mytool/tool.sh

# 3. 添加 mappings（可选）
cat > mytool/mappings << 'EOF'
d:data/.config:/home/devuser/.config
EOF

# 4. 使用
d mytool
```

### 服务型工具

```bash
# 1. 创建工具目录
mkdir -p myserver/profiles/template

# 2. 添加 tool.sh（执行命令时使用）
cat > myserver/tool.sh << 'EOF'
#!/bin/bash
exec my-server-cli "$@"
EOF
chmod +x myserver/tool.sh

# 3. 添加 service.sh（启动服务时使用）
cat > myserver/service.sh << 'EOF'
#!/bin/bash
exec my-server --port 8080
EOF
chmod +x myserver/service.sh

# 4. 添加 mappings
cat > myserver/mappings << 'EOF'
d:data:/var/lib/myserver
EOF

# 5. 使用
d -u myserver        # 启动服务
d myserver status    # 执行命令
d -d myserver        # 停止服务
```

## 全局配置

项目根目录支持全局级别的配置，对所有工具生效：

- `mappings` / `mappings.local` - 全局目录映射
- `env` / `env.local` - 全局环境变量
- `pre-exec` / `pre-exec.local` - 全局 pre-exec hook
- `post-exec` / `post-exec.local` - 全局 post-exec hook

## 安装常用工具

项目提供了 `snippets.txt` 文件，包含常见开发工具的安装脚本片段。

**使用方法：**

1. 浏览 `snippets.txt` 查找需要的工具
2. 将对应的代码片段复制到适当的 `pre-exec.local` 文件中

## 环境变量配置

支持三级 `env` 文件，在容器启动时自动加载：

```bash
source /sandbox/env/global          # 项目根目录的 env
source /sandbox/env/global.local    # 项目根目录的 env.local
source /sandbox/env/tool            # tool/env
source /sandbox/env/tool.local      # tool/env.local
source /sandbox/env/profile         # profile/env
source /sandbox/env/profile.local   # profile/env.local
```
