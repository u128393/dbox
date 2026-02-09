# dbox

通过 Docker 容器实现安全隔离的工具运行框架。

## 目录结构

```
dbox/
├── exec.sh             # 容器内执行脚本
├── Dockerfile          # 统一的 base 镜像
├── dbox.sh             # 统一运行脚本
├── install.sh          # 安装脚本（创建 d、ds、dt 命令）
├── mappings            # 全局目录映射配置（可选）
├── mappings.local      # 全局目录映射本地覆盖（可选，不提交到 git）
├── env                 # 全局环境变量（可选）
├── env.local           # 全局环境变量本地覆盖（可选，不提交到 git）
├── pre-exec            # 全局 pre-exec hook（可选）
├── pre-exec.local      # 全局 pre-exec hook 本地覆盖（可选，不提交到 git）
├── post-exec           # 全局 post-exec hook（可选）
├── post-exec.local     # 全局 post-exec hook 本地覆盖（可选，不提交到 git）
├── completion          # 自动补全脚本
├── snippets.txt        # 常用工具安装片段
├── README.md           # 本文件
├── .gitignore          # Git 忽略规则
└── <tool>/            # 工具目录（如 claude）
    ├── tool.sh         # 工具调用脚本（必需）
    ├── pre-exec        # 工具级 pre-exec hook（可选）
    ├── pre-exec.local  # 工具级 pre-exec hook 本地覆盖（可选，不提交到 git）
    ├── post-exec       # 工具级 post-exec hook（可选）
    ├── post-exec.local # 工具级 post-exec hook 本地覆盖（可选，不提交到 git）
    ├── mappings        # 工具级目录映射配置
    ├── mappings.local  # 工具级目录映射本地覆盖（可选，不提交到 git）
    ├── env             # 工具级环境变量（可选）
    ├── env.local       # 工具级环境变量本地覆盖（可选，不提交到 git）
    ├── data/           # 持久化数据（可选，不提交到 git）
    └── profiles/       # 环境配置
        └── template/   # 模板目录（提交到 git）
            ├── .claude/ # Claude 配置（Claude 特有）
            ├── mappings # 目录映射配置
            ├── mappings.local # 目录映射本地覆盖（可选，不提交到 git）
            ├── pre-exec # profile 级 pre-exec hook（可选）
            └── post-exec # profile 级 post-exec hook（可选）
```

## 快速开始

```bash
# 1. 安装（创建符号链接 ~/.local/bin/{d,ds,dt}）
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
d claude --version       # 传递工具参数
ds claude                # 启动 claude 容器的 bash shell
dt claude                # 以 tmux 模式运行 claude
```

## 命令格式

### d - 运行工具脚本

```bash
d <tool>[-<profile>] [args...]
```

运行工具的 `tool.sh` 脚本。

- `tool` - 工具名称（必需）
- `profile` - 配置名称（可选，默认 `default`），用 `-` 与工具名连接
- `args` - 传递给工具的参数

### ds - 启动 Shell

```bash
ds <tool>[-<profile>]
```

直接启动容器的交互式 `/bin/bash`，进入容器 shell 进行调试或手动操作。

- `tool` - 工具名称（必需）
- `profile` - 配置名称（可选，默认 `default`）

### dt - 以 tmux 模式运行工具脚本

```bash
dt <tool>[-<profile>]
```

在容器内以 tmux -CC 模式运行工具脚本。

- `tool` - 工具名称（必需）
- `profile` - 配置名称（可选，默认 `default`）

### 直接调用 dbox.sh

```bash
dbox.sh <run|shell|tmux> <tool>[-<profile>] [args...]
```

直接调用 `dbox.sh` 时，第一个参数指定模式。

## 自动补全

dbox 提供了 bash 和 zsh 的自动补全支持，可以方便地补全工具名和 profile。

**启用方法：**

在 `~/.bashrc` 或 `~/.zshrc` 中添加：

```bash
source /path/to/dbox/completion
```

**使用效果：**

```bash
d <Tab>            # 列出所有工具（如 claude）
ds <Tab>           # 列出所有工具
dt <Tab>           # 列出所有工具
d claude-<Tab>     # 列出 claude 工具的所有 profile
ds claude-<Tab>    # 列出 claude 工具的所有 profile
dt claude-<Tab>    # 列出 claude 工具的所有 profile
```

## Profile 自动创建

当指定的 profile 不存在时：

- **default 配置**：自动从 `template` 创建，无需确认
- **其他配置**：询问是否从 `template` 创建

## 容器内结构

容器运行时通过 volume mounts 动态构建 `/sandbox/` 目录：

```
/sandbox/
├── exec.sh           # 执行脚本（入口点，从项目根目录挂载）
├── tool.sh           # 工具调用脚本（从工具目录挂载）
├── hooks/            # Hook 文件挂载点
│   ├── global-pre-exec
│   ├── global-pre-exec.local
│   ├── tool-pre-exec
│   ├── tool-pre-exec.local
│   ├── profile-pre-exec
│   ├── profile-pre-exec.local
│   ├── global-post-exec
│   ├── global-post-exec.local
│   ├── tool-post-exec
│   ├── tool-post-exec.local
│   ├── profile-post-exec
│   └── profile-post-exec.local
└── env/              # 环境变量文件挂载点
    ├── global
    ├── global.local
    ├── tool
    ├── tool.local
    ├── profile
    └── profile.local
```

工作目录根据 `mappings` 配置中的 `{cwd}` 动态设置。

## 架构说明

### 工具目录结构

每个工具目录包含：

- `tool.sh` - 工具调用脚本（必需），通过 `exec` 调用实际工具
- `pre-exec` - 工具级 pre-exec hook（可选）
- `pre-exec.local` - 工具级 pre-exec hook 本地覆盖（可选，不提交到 git）
- `post-exec` - 工具级 post-exec hook（可选）
- `post-exec.local` - 工具级 post-exec hook 本地覆盖（可选，不提交到 git）
- `mappings` - 工具级目录映射配置
- `mappings.local` - 工具级目录映射本地覆盖（可选，不提交到 git）
- `env` - 工具级环境变量（可选）
- `env.local` - 工具级环境变量本地覆盖（可选，不提交到 git）
- `data` - 工具级持久化数据（可选，不提交到 git），结构由工具自行决定
- `profiles/template/` - 模板目录（提交到 git）
  - 根据工具需要放置配置文件、脚本等
  - `mappings` - profile 级目录映射配置
  - `mappings.local` - profile 级目录映射本地覆盖（可选，不提交到 git）
  - `env` - profile 级环境变量（可选）
  - `env.local` - profile 级环境变量本地覆盖（可选，不提交到 git）
  - `pre-exec` - profile 级 pre-exec hook（可选）
  - `pre-exec.local` - profile 级 pre-exec hook 本地覆盖（可选，不提交到 git）
  - `post-exec` - profile 级 post-exec hook（可选）
  - `post-exec.local` - profile 级 post-exec hook 本地覆盖（可选，不提交到 git）

### Profile 目录结构

每个 profile 从 template 创建，内容由 template 决定，通常包含：

- 配置文件/目录（如 `.claude/`）
- `mappings` - 目录映射配置
- `mappings.local` - 目录映射本地覆盖（可选，不提交到 git）
- `pre-exec` - profile 级 pre-exec hook（可选）
- `pre-exec.local` - profile 级 pre-exec hook 本地覆盖（可选，不提交到 git）
- `post-exec` - profile 级 post-exec hook（可选）
- `post-exec.local` - profile 级 post-exec hook 本地覆盖（可选，不提交到 git）

### Hook 执行顺序

**pre-exec（从低到高优先级）：**

1. 全局 pre-exec
2. 全局 pre-exec.local
3. 工具级 pre-exec
4. 工具级 pre-exec.local
5. Profile 级 pre-exec
6. Profile 级 pre-exec.local
7. 执行命令

**post-exec（倒序，从高到低优先级）：**

1. Profile 级 post-exec.local
2. Profile 级 post-exec
3. 工具级 post-exec.local
4. 工具级 post-exec
5. 全局 post-exec.local
6. 全局 post-exec

#### data 目录

`data` 目录用于存放工具的**持久化数据**，位于**工具目录下**（`<tool>/data`）。

**用途：**

- 在同一工具的不同 profile 之间共享配置和数据
- 容器重启后持久化重要数据
- 存放工具运行时需要持久化的内容（如配置、缓存、状态等）

**结构：**

- `data` 目录的具体结构由各工具根据自身需求决定
- 常见子目录示例：`.config/`、`.local/`、`cache/` 等
- 通过 `<tool>/mappings` 文件配置如何映射到容器内

**映射示例：**

```
# 在 <tool>/mappings 中配置（根据工具需求调整）
d:data/.config:/home/devuser/.config
d:data/.local:/home/devuser/.local
```

**Git 管理：**

- `data` 目录已被 `.gitignore` 忽略（`*/data/`）
- 适合存放敏感配置、缓存数据等不应提交到 git 的内容

## 映射配置格式

`mappings` 文件格式（每行一个映射）：

```
# 注释以 # 开头
# 格式：f:src:dst  (文件映射，不存在时创建空文件)
#       d:src:dst  (目录映射，不存在时自动创建目录)

# 工具级 data 目录映射（根据工具需求配置）
d:data/.config:/home/devuser/.config
d:data/.local:/home/devuser/.local

# 单个配置文件映射
f:.claude.json:/home/devuser/.claude.json

# 相对路径相对于所属目录（全局/工具/profile）
d:.claude:/home/devuser/.claude

# 特殊变量 {cwd} 表示当前工作目录
d:{cwd}:{cwd}
```

- **文件映射 (f:)**：源文件不存在时创建空文件
- **目录映射 (d:)**：源目录不存在时自动创建目录

支持三级 `mappings` 文件（按优先级从低到高），每一级支持 `.local` 本地覆盖：

- `mappings` - 全局目录映射配置（项目根目录，可选）
- `mappings.local` - 全局目录映射本地覆盖（可选，不提交到 git）
- `tool/mappings` - 工具级目录映射配置
- `tool/mappings.local` - 工具级目录映射本地覆盖（可选，不提交到 git）
- `tool/profiles/<profile>/mappings` - profile 级目录映射配置
- `tool/profiles/<profile>/mappings.local` - profile 级目录映射本地覆盖（可选，不提交到 git）

每一级的 `.local` 文件会在该级基础文件之后加载，可以添加新的映射或覆盖已有映射。

## 全局配置

项目根目录支持全局级别的配置，对所有工具生效：

**目录映射：**

- `mappings` - 全局目录映射配置（可选）
- `mappings.local` - 全局目录映射本地覆盖（可选，不提交到 git）

**环境变量：**

- `env` - 全局环境变量（可选）
- `env.local` - 全局环境变量本地覆盖（可选，不提交到 git）

**Hooks：**

- `pre-exec` - 全局 pre-exec hook（可选）
- `pre-exec.local` - 全局 pre-exec hook 本地覆盖（可选，不提交到 git）
- `post-exec` - 全局 post-exec hook（可选）
- `post-exec.local` - 全局 post-exec hook 本地覆盖（可选，不提交到 git）

全局配置在工具级和 profile 级配置之前加载。

## 安装常用工具

项目提供了 `snippets.txt` 文件，包含常见开发工具的安装脚本片段（snippets）。

**使用方法：**

1. 浏览 `snippets.txt` 查找需要的工具
2. 将对应的代码片段复制到适当的 `pre-exec` 文件中：
   - **全局安装**（所有工具可用）：复制到根目录的 `pre-exec.local`
   - **工具级安装**（仅特定工具可用）：复制到 `<tool>/pre-exec.local`
   - **profile 级安装**（仅特定配置可用）：复制到 `<tool>/profiles/<profile>/pre-exec.local`

**示例：**

1. 在 `snippets.txt` 中找到 Node.js 安装代码：

```bash
if ! command -v node &>/dev/null; then
  echo -e "\n🔧 安装 Node.js...\n"
  curl -L 'https://nodejs.org/dist/v24.13.0/node-v24.13.0-linux-arm64.tar.xz' | \
    tar -xJ -C ~/.local --strip-components=1 --exclude='*.md' --exclude='LICENSE'
fi
```

2. 复制到相应工具目录的 `pre-exec.local`

3. 下次运行该工具时会自动安装 Node.js

每个 snippet 都遵循统一的模式：先检查命令是否存在，如不存在则安装。

## 添加新工具

1. 创建工具目录 `mkdir toolname`
2. 添加 `tool.sh` 工具调用脚本（必需）
   ```bash
   #!/bin/bash
   exec your-tool "$@"
   ```
3. 添加 `mappings` 配置文件（可选）- 配置目录映射，包括 `data` 目录的映射
4. 添加 `env` 文件（可选）- 工具级环境变量
5. 添加 `pre-exec` hook（可选）- 容器启动前执行
6. 添加 `post-exec` hook（可选）- 容器结束后执行
7. 创建 `data` 目录（可选）- 存放持久化数据，结构由工具需求决定
8. 创建 `profiles/template/` 模板目录
   - 放置工具需要的配置文件
   - 创建 `mappings` 配置文件
   - 添加 `env` 文件（可选）- profile 级环境变量
   - 添加 `pre-exec` 文件（可选）- profile 级 pre-exec hook
   - 添加 `post-exec` 文件（可选）- profile 级 post-exec hook

**本地自定义（不提交到 git）：**

- `data` - 工具级持久化数据目录
- `mappings.local` - 目录映射本地覆盖
- `pre-exec.local` / `post-exec.local` - 工具级 hook 本地覆盖
- `env.local` - 工具级环境变量本地覆盖
- `profiles/<profile>/mappings.local` - profile 级目录映射本地覆盖
- `profiles/<profile>/pre-exec.local` / `post-exec.local` - profile 级 hook 本地覆盖
- `profiles/<profile>/env.local` - profile 级环境变量本地覆盖

## 环境变量配置

支持三级 `env` 文件（按优先级从低到高），每一级支持 `.local` 本地覆盖：

- `env` - 全局环境变量（项目根目录）
- `env.local` - 全局环境变量本地覆盖（可选，不提交到 git）
- `tool/env` - 工具级环境变量
- `tool/env.local` - 工具级环境变量本地覆盖（可选，不提交到 git）
- `tool/profiles/<profile>/env` - profile 级环境变量
- `tool/profiles/<profile>/env.local` - profile 级环境变量本地覆盖（可选，不提交到 git）

这些文件会被挂载到容器的 `/sandbox/env/` 目录，并在容器启动时通过 bashrc 自动加载：

```bash
# 容器内的 bashrc 会按顺序加载：
source /sandbox/env/global          # 对应项目根目录的 env
source /sandbox/env/global.local    # 对应项目根目录的 env.local
source /sandbox/env/tool            # 对应 tool/env
source /sandbox/env/tool.local      # 对应 tool/env.local
source /sandbox/env/profile         # 对应 profile/env
source /sandbox/env/profile.local   # 对应 profile/env.local
```

每一级的 `.local` 文件会在该级基础文件之后加载，覆盖该级的设置。所有 `*.local` 文件已被 `.gitignore` 忽略。

示例 `env` 文件：

```bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```
