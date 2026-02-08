#!/bin/bash

# dbox 运行脚本
# 用法: d <tool>[-<profile>] [args...]
#   tool-profile: 工具名和配置名，用 - 连接（如 claude-zai）
#                 配置可选，默认为 default
#   args: 传递给工具的参数

set -e

# 配置变量
IMAGE_NAME="dbox"
# 解析符号链接，获取真实脚本目录
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
WORKSPACE_DIR="$(pwd)"

# 默认值
TOOL=""
PROFILE="default"

# 解析参数：第一个参数必须是 tool[-profile]
if [ $# -gt 0 ]; then
  FIRST_ARG="$1"
  shift

  # 解析 tool-profile 格式
  if [[ "$FIRST_ARG" == *-* ]]; then
    TOOL="${FIRST_ARG%%-*}"
    PROFILE="${FIRST_ARG#*-}"
  else
    TOOL="$FIRST_ARG"
  fi
fi

# 检查工具目录是否存在
if [ -z "$TOOL" ]; then
  echo "错误: 必须指定工具" >&2
  echo "用法: d <tool>[-<profile>] [args...]" >&2
  echo "示例: d claude" >&2
  echo "      d claude-zai" >&2
  echo "      d claude --version" >&2
  exit 1
fi

TOOL_DIR="$SCRIPT_DIR/$TOOL"
if [ ! -d "$TOOL_DIR" ]; then
  echo "错误: 工具目录不存在: $TOOL_DIR" >&2
  exit 1
fi

# 构建 Docker 镜像（如果不存在）
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo -e "📦 构建 Docker 镜像: $IMAGE_NAME\n"
  docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
  echo ""
fi

PROFILE_DIR="$TOOL_DIR/profiles/$PROFILE"
TEMPLATE_DIR="$TOOL_DIR/profiles/template"

# 如果配置不存在，尝试创建
if [ ! -d "$PROFILE_DIR" ]; then
  if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "错误: 配置目录不存在: $PROFILE_DIR" >&2
    echo "错误: 模板目录也不存在: $TEMPLATE_DIR" >&2
    exit 1
  fi

  # 询问是否创建（default 自动创建）
  if [ "$PROFILE" = "default" ]; then
    CREATE_PROFILE="y"
  else
    echo -n "配置 '$PROFILE' 不存在，是否从模板创建？[Y/n] "
    read -r CREATE_PROFILE
    # 默认为 Yes
    CREATE_PROFILE="${CREATE_PROFILE:-y}"
  fi

  if [[ "$CREATE_PROFILE" =~ ^[Yy]$ ]]; then
    echo -e "\n📁 创建配置目录: $PROFILE_DIR"
    cp -R "$TEMPLATE_DIR" "$PROFILE_DIR"
  else
    echo "错误: 配置目录不存在: $PROFILE_DIR" >&2
    exit 1
  fi

  echo ""
fi

# 环境变量列表
ENV_VARS=()

# 传递终端类型
ENV_VARS+=("-e" "TERM=$TERM")

# 传递时区
if [ -n "$TZ" ]; then
  # 如果 TZ 环境变量已设置，直接使用
  ENV_VARS+=("-e" "TZ=$TZ")
elif [ -L /etc/localtime ]; then
  # 否则检查 /etc/localtime 符号链接
  timezone_path=$(readlink /etc/localtime)
  if [[ "$timezone_path" == */zoneinfo/* ]]; then
    TZ_VALUE="${timezone_path#*/zoneinfo/}"
    ENV_VARS+=("-e" "TZ=$TZ_VALUE")
  fi
fi

# 映射列表
VOLUME_MOUNTS=()

# 映射 exec.sh
VOLUME_MOUNTS+=("-v" "$SCRIPT_DIR/exec.sh:/sandbox/exec.sh:ro")

# 检查工具调用脚本是否存在
if [ ! -f "$TOOL_DIR/tool.sh" ]; then
  echo "错误: 工具调用脚本不存在: $TOOL_DIR/tool.sh" >&2
  exit 1
fi

# 映射工具调用脚本
VOLUME_MOUNTS+=("-v" "$TOOL_DIR/tool.sh:/sandbox/tool.sh:ro")

# 工作目录参数
WORKDIR_ARG=()

# 加载全局、工具级和 Profile 级 mappings（按优先级：global → tool → profile，每级 .local 后加载）
for dir in "$SCRIPT_DIR" "$TOOL_DIR" "$PROFILE_DIR"; do
  for mappings_file in "$dir/mappings" "$dir/mappings.local"; do
    if [ -f "$mappings_file" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        # 跳过空行和注释
        [[ -z "$line" || "$line" == \#* ]] && continue

        # 解析 f:src:dst 或 d:src:dst
        if [[ ! "$line" =~ ^([fd]):([^:]+):(.+)$ ]]; then
          echo "错误: 映射格式错误，必须使用 f:src:dst 或 d:src:dst 格式: $line" >&2
          exit 1
        fi

        map_type="${BASH_REMATCH[1]}"
        host_path="${BASH_REMATCH[2]}"
        container_path="${BASH_REMATCH[3]}"

        # 支持特殊变量 {cwd}
        host_is_cwd=false
        if [[ "$host_path" == "{cwd}" ]]; then
          host_path="$WORKSPACE_DIR"
          host_is_cwd=true
        fi
        if [[ "$container_path" == "{cwd}" ]]; then
          container_path="$WORKSPACE_DIR"
        fi

        # 支持相对路径
        if [[ "$host_path" != /* ]]; then
          host_path="$dir/$host_path"
        fi

        # 处理文件或目录
        if [ "$map_type" = "d" ]; then
          # 目录映射：不存在则自动创建
          if [ ! -e "$host_path" ]; then
            mkdir -p "$host_path"
          elif [ ! -d "$host_path" ]; then
            echo "错误: 映射源路径不是目录: $host_path" >&2
            exit 1
          fi
        else
          # 文件映射（f:）：不存在则创建空文件
          if [ ! -e "$host_path" ]; then
            touch "$host_path"
          elif [ ! -f "$host_path" ]; then
            echo "错误: 映射源路径不是文件: $host_path" >&2
            exit 1
          fi
        fi

        VOLUME_MOUNTS+=("-v" "$host_path:$container_path")

        # 如果 host 部分包含 {cwd}，设置工作目录
        if [ "$host_is_cwd" = true ]; then
          WORKDIR_ARG+=("-w" "$container_path")
        fi
      done < "$mappings_file"
    fi
  done
done

# 映射 env 文件
if [ -f "$SCRIPT_DIR/env" ]; then
  VOLUME_MOUNTS+=("-v" "$SCRIPT_DIR/env:/sandbox/env/global:ro")
fi
if [ -f "$SCRIPT_DIR/env.local" ]; then
  VOLUME_MOUNTS+=("-v" "$SCRIPT_DIR/env.local:/sandbox/env/global.local:ro")
fi
if [ -f "$TOOL_DIR/env" ]; then
  VOLUME_MOUNTS+=("-v" "$TOOL_DIR/env:/sandbox/env/tool:ro")
fi
if [ -f "$TOOL_DIR/env.local" ]; then
  VOLUME_MOUNTS+=("-v" "$TOOL_DIR/env.local:/sandbox/env/tool.local:ro")
fi
if [ -f "$PROFILE_DIR/env" ]; then
  VOLUME_MOUNTS+=("-v" "$PROFILE_DIR/env:/sandbox/env/profile:ro")
fi
if [ -f "$PROFILE_DIR/env.local" ]; then
  VOLUME_MOUNTS+=("-v" "$PROFILE_DIR/env.local:/sandbox/env/profile.local:ro")
fi

# 映射 hook 文件
for hook_type in pre-exec post-exec; do
  # 全局 hooks
  hook_file="$SCRIPT_DIR/$hook_type"
  if [ -f "$hook_file" ]; then
    VOLUME_MOUNTS+=("-v" "$hook_file:/sandbox/hooks/global-$hook_type:ro")
  fi
  # 全局 hooks.local
  hook_file="$SCRIPT_DIR/$hook_type.local"
  if [ -f "$hook_file" ]; then
    VOLUME_MOUNTS+=("-v" "$hook_file:/sandbox/hooks/global-$hook_type.local:ro")
  fi
  # 工具级 hooks
  hook_file="$TOOL_DIR/$hook_type"
  if [ -f "$hook_file" ]; then
    VOLUME_MOUNTS+=("-v" "$hook_file:/sandbox/hooks/tool-$hook_type:ro")
  fi
  # 工具级 hooks.local
  hook_file="$TOOL_DIR/$hook_type.local"
  if [ -f "$hook_file" ]; then
    VOLUME_MOUNTS+=("-v" "$hook_file:/sandbox/hooks/tool-$hook_type.local:ro")
  fi
  # Profile 级 hooks
  hook_file="$PROFILE_DIR/$hook_type"
  if [ -f "$hook_file" ]; then
    VOLUME_MOUNTS+=("-v" "$hook_file:/sandbox/hooks/profile-$hook_type:ro")
  fi
  # Profile 级 hooks.local
  hook_file="$PROFILE_DIR/$hook_type.local"
  if [ -f "$hook_file" ]; then
    VOLUME_MOUNTS+=("-v" "$hook_file:/sandbox/hooks/profile-$hook_type.local:ro")
  fi
done

# 映射 gitconfig
if [ -f "$HOME/.gitconfig" ]; then
  VOLUME_MOUNTS+=("-v" "$HOME/.gitconfig:/home/devuser/.gitconfig:ro")
fi

echo "🚀 启动沙箱容器..."
echo "   工具: $TOOL"
echo "   配置: $PROFILE"
if [ ${#WORKDIR_ARG[@]} -gt 0 ]; then
  echo "   工作目录: $WORKSPACE_DIR"
fi

# 检测是否在 TTY 中
TTY_FLAG=""
if [ -t 0 ]; then
  TTY_FLAG="-it"
fi

# 启动容器
docker run $TTY_FLAG --rm --init \
  --entrypoint /sandbox/exec.sh \
  "${WORKDIR_ARG[@]}" \
  "${ENV_VARS[@]}" \
  "${VOLUME_MOUNTS[@]}" \
  "$IMAGE_NAME" \
  /sandbox/tool.sh "$@"
