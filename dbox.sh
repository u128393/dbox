#!/bin/bash

# dbox - Docker 沙箱工具管理器
# 用法: d [flags] [tool[-profile]] [args...]

set -e

# ===== 基础配置 =====
DBOX_IMAGE_NAME="dbox"
DBOX_VERSION="0.2.0"

# ===== 自动初始化 =====
# 获取脚本的真实路径（跟随符号链接）
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  LINK_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  # 如果是相对路径，基于链接所在目录转换为绝对路径
  if [[ "$SCRIPT_PATH" != /* ]]; then
    SCRIPT_PATH="$LINK_DIR/$SCRIPT_PATH"
  fi
done
DBOX_ROOT="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# ===== 工具函数 =====
# 输出错误信息
dbox_error() {
  echo "错误: $*" >&2
}

# 输出信息
dbox_info() {
  echo "$*"
}

# 显示版本
dbox_show_version() {
  echo "v$DBOX_VERSION"
}

# 显示帮助
dbox_show_help() {
  cat <<'EOF'
用法: d [flags] [tool[-profile]] [args...]

标志:
  -u, --up       启动服务（服务型工具）
  -d, --down     停止服务（服务型工具）
  -r, --restart  重启服务（服务型工具）
  -l, --list     列出运行中的服务型工具容器
  -s, --shell    启动容器 shell
  -h, --help     显示帮助
  -v, --version  显示版本

示例:
  d claude                    # 运行 claude (默认配置)
  d claude-zai                # 运行 claude (zai 配置)
  d claude --version          # 带参数运行
  d -s claude                 # 启动 claude 容器 shell
  d -u openclaw               # 启动 openclaw 服务（待实现）
EOF
}

# ===== 参数解析函数 =====
# 解析 tool[-profile] 格式
dbox_parse_tool_profile() {
  local input="$1"
  local tool_var="$2"
  local profile_var="$3"

  if [[ "$input" == *-* ]]; then
    eval "$tool_var='${input%%-*}'"
    eval "$profile_var='${input#*-}'"
  else
    eval "$tool_var='$input'"
    eval "$profile_var='default'"
  fi
}

# 解析命令行参数
# 返回: ACTION, TOOL, PROFILE, ARGS
# 规则: 标志必须在 <tool> 之前，<tool> 之后的所有参数都传给容器
dbox_parse_args() {
  ACTION=""
  TOOL=""
  PROFILE="default"
  ARGS=()

  while [[ $# -gt 0 ]]; do
    # 一旦 tool 已设置，后续所有参数都作为 ARGS，不再解析标志
    if [[ -n "$TOOL" ]]; then
      ARGS+=("$1")
      shift
      continue
    fi

    case "$1" in
      -u|--up)
        ACTION="up"
        shift
        ;;
      -d|--down)
        ACTION="down"
        shift
        ;;
      -r|--restart)
        ACTION="restart"
        shift
        ;;
      -l|--list)
        ACTION="list"
        shift
        ;;
      -s|--shell)
        ACTION="shell"
        shift
        ;;
      -h|--help)
        ACTION="help"
        shift
        ;;
      -v|--version)
        ACTION="version"
        shift
        ;;
      -*)
        dbox_error "未知标志: $1"
        dbox_show_help
        exit 1
        ;;
      *)
        # 第一个非标志参数是 tool[-profile]
        dbox_parse_tool_profile "$1" TOOL PROFILE
        shift
        ;;
    esac
  done
}

# ===== 工具检测函数 =====
# 检查工具目录和 tool.sh 是否存在
dbox_check_tool() {
  local tool="$1"
  local tool_dir="$DBOX_ROOT/$tool"

  if [ -z "$tool" ]; then
    dbox_error "必须指定工具"
    return 1
  fi

  # 验证工具名（只允许字母、数字、下划线）
  if [[ ! "$tool" =~ ^[a-zA-Z0-9_]+$ ]]; then
    dbox_error "工具名称包含非法字符: $tool（只允许字母、数字、下划线）"
    return 1
  fi

  if [ ! -d "$tool_dir" ]; then
    dbox_error "工具目录不存在: $tool_dir"
    return 1
  fi

  if [ ! -f "$tool_dir/tool.sh" ]; then
    dbox_error "工具脚本不存在: $tool_dir/tool.sh"
    return 1
  fi

  return 0
}

# 检查工具是否是服务型（存在 service.sh）
dbox_is_service() {
  local tool="$1"
  [ -f "$DBOX_ROOT/$tool/service.sh" ]
}

# 检测是否是 iTerm2
dbox_is_iterm2() {
  [ "$TERM_PROGRAM" = "iTerm.app" ]
}

# 加载工具配置
dbox_load_config() {
  local tool="$1"
  local config_file="$DBOX_ROOT/$tool/config"

  # 默认值
  TMUX_IN_ITERM=false

  if [ -f "$config_file" ]; then
    source "$config_file"
  fi
}

# ===== 容器管理函数 =====
# 生成容器名称
dbox_container_name() {
  local tool="$1"
  local profile="${2:-default}"
  echo "dbox-${tool}-${profile}"
}

# 确保镜像存在
dbox_ensure_image() {
  if ! docker image inspect "$DBOX_IMAGE_NAME" &>/dev/null; then
    dbox_info "📦 构建 Docker 镜像: $DBOX_IMAGE_NAME"
    docker build -t "$DBOX_IMAGE_NAME" "$DBOX_ROOT"
    dbox_info ""
  fi
}

# 检查容器是否运行中
dbox_container_running() {
  local container_name="$1"
  docker ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

# 检查容器是否存在（包括停止的）
dbox_container_exists() {
  local container_name="$1"
  docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"
}

# ===== Profile 管理函数 =====
# 验证配置名
dbox_validate_profile_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-zA-Z0-9_]+$ ]]; then
    dbox_error "配置名称包含非法字符: $name（只允许字母、数字、下划线）"
    return 1
  fi
  return 0
}

# 确保 profile 存在
dbox_ensure_profile() {
  local tool="$1"
  local profile="$2"
  local tool_dir="$DBOX_ROOT/$tool"
  local profile_dir="$tool_dir/profiles/$profile"
  local template_dir="$tool_dir/profiles/template"

  # 验证 profile 名称
  if ! dbox_validate_profile_name "$profile"; then
    return 1
  fi

  if [ -d "$profile_dir" ]; then
    return 0
  fi

  if [ ! -d "$template_dir" ]; then
    dbox_error "配置目录不存在: $profile_dir"
    dbox_error "模板目录也不存在: $template_dir"
    return 1
  fi

  # 询问是否创建（default 自动创建）
  if [ "$profile" = "default" ]; then
    local create_profile="y"
  else
    echo -n "配置 '$profile' 不存在，是否从模板创建？[Y/n] "
    read -r create_profile
    create_profile="${create_profile:-y}"
    echo ""
  fi

  if [[ "$create_profile" =~ ^[Yy]$ ]]; then
    dbox_info "📁 创建配置目录: $profile_dir"
    cp -R "$template_dir" "$profile_dir"
  else
    dbox_error "配置目录不存在: $profile_dir"
    return 1
  fi

  dbox_info ""
  return 0
}

# ===== 配置加载函数 =====
# 加载环境变量
dbox_load_env() {
  local tool="$1"
  local profile="$2"
  local result_var="$3"

  eval "$result_var=()"

  # 传递终端类型
  eval "$result_var+=(\"-e\" \"TERM=$TERM\")"

  # 传递时区
  if [ -n "$TZ" ]; then
    eval "$result_var+=(\"-e\" \"TZ=$TZ\")"
  elif [ -L /etc/localtime ]; then
    local timezone_path
    timezone_path=$(readlink /etc/localtime)
    if [[ "$timezone_path" == */zoneinfo/* ]]; then
      local tz_value="${timezone_path#*/zoneinfo/}"
      eval "$result_var+=(\"-e\" \"TZ=$tz_value\")"
    fi
  fi
}

# 加载映射配置
dbox_load_mappings() {
  local tool="$1"
  local profile="$2"
  local mounts_var="$3"
  local workdir_var="$4"
  local workspace_dir="$(pwd)"

  local tool_dir="$DBOX_ROOT/$tool"
  local profile_dir="$tool_dir/profiles/$profile"

  eval "$mounts_var=()"
  eval "$workdir_var=()"

  # 映射 entrypoint
  eval "$mounts_var+=(\"-v\" \"$DBOX_ROOT/exec.sh:/sandbox/entrypoint:ro\")"

  # 加载全局、工具级和 Profile 级 mappings
  for dir in "$DBOX_ROOT" "$tool_dir" "$profile_dir"; do
    for mappings_file in "$dir/mappings" "$dir/mappings.local"; do
      if [ -f "$mappings_file" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
          [[ -z "$line" || "$line" == \#* ]] && continue

          if [[ ! "$line" =~ ^([fd]):([^:]+):(.+)$ ]]; then
            dbox_error "映射格式错误，必须使用 f:src:dst 或 d:src:dst 格式: $line"
            return 1
          fi

          local map_type="${BASH_REMATCH[1]}"
          local host_path="${BASH_REMATCH[2]}"
          local container_path="${BASH_REMATCH[3]}"

          local host_is_cwd=false
          if [[ "$host_path" == "{cwd}" ]]; then
            host_path="$workspace_dir"
            host_is_cwd=true
          fi
          if [[ "$container_path" == "{cwd}" ]]; then
            container_path="$workspace_dir"
          fi

          if [[ "$host_path" != /* ]]; then
            host_path="$dir/$host_path"
          fi

          if [ "$map_type" = "d" ]; then
            if [ ! -e "$host_path" ]; then
              mkdir -p "$host_path"
            elif [ ! -d "$host_path" ]; then
              dbox_error "映射源路径不是目录: $host_path"
              return 1
            fi
          else
            if [ ! -e "$host_path" ]; then
              touch "$host_path"
            elif [ ! -f "$host_path" ]; then
              dbox_error "映射源路径不是文件: $host_path"
              return 1
            fi
          fi

          local escaped_host_path="${host_path//\\/\\\\}"
          escaped_host_path="${escaped_host_path//\"/\\\"}"
          local escaped_container_path="${container_path//\\/\\\\}"
          escaped_container_path="${escaped_container_path//\"/\\\"}"

          eval "$mounts_var+=(\"-v\" \"$escaped_host_path:$escaped_container_path\")"

          if [ "$host_is_cwd" = true ]; then
            eval "$workdir_var+=(\"-w\" \"$escaped_container_path\")"
          fi
        done < "$mappings_file"
      fi
    done
  done
}

# 加载 env 文件映射
dbox_load_env_files() {
  local tool="$1"
  local profile="$2"
  local mounts_var="$3"
  local tool_dir="$DBOX_ROOT/$tool"
  local profile_dir="$tool_dir/profiles/$profile"

  eval "$mounts_var=()"

  if [ -f "$DBOX_ROOT/env" ]; then
    eval "$mounts_var+=(\"-v\" \"$DBOX_ROOT/env:/sandbox/env/global:ro\")"
  fi
  if [ -f "$DBOX_ROOT/env.local" ]; then
    eval "$mounts_var+=(\"-v\" \"$DBOX_ROOT/env.local:/sandbox/env/global.local:ro\")"
  fi
  if [ -f "$tool_dir/env" ]; then
    eval "$mounts_var+=(\"-v\" \"$tool_dir/env:/sandbox/env/tool:ro\")"
  fi
  if [ -f "$tool_dir/env.local" ]; then
    eval "$mounts_var+=(\"-v\" \"$tool_dir/env.local:/sandbox/env/tool.local:ro\")"
  fi
  if [ -f "$profile_dir/env" ]; then
    eval "$mounts_var+=(\"-v\" \"$profile_dir/env:/sandbox/env/profile:ro\")"
  fi
  if [ -f "$profile_dir/env.local" ]; then
    eval "$mounts_var+=(\"-v\" \"$profile_dir/env.local:/sandbox/env/profile.local:ro\")"
  fi
}

# 加载 hooks 映射
dbox_load_hooks() {
  local tool="$1"
  local profile="$2"
  local mounts_var="$3"
  local tool_dir="$DBOX_ROOT/$tool"
  local profile_dir="$tool_dir/profiles/$profile"

  eval "$mounts_var=()"

  for hook_type in pre-exec post-exec; do
    for hook_location in "DBOX_ROOT" "tool_dir" "profile_dir"; do
      local base_dir
      case "$hook_location" in
        DBOX_ROOT) base_dir="$DBOX_ROOT" ;;
        tool_dir) base_dir="$tool_dir" ;;
        profile_dir) base_dir="$profile_dir" ;;
      esac

      local hook_name
      case "$hook_location" in
        DBOX_ROOT) hook_name="global" ;;
        tool_dir) hook_name="tool" ;;
        profile_dir) hook_name="profile" ;;
      esac

      local hook_file="$base_dir/$hook_type"
      if [ -f "$hook_file" ]; then
        eval "$mounts_var+=(\"-v\" \"$hook_file:/sandbox/hooks/${hook_name}-${hook_type}:ro\")"
      fi
      hook_file="$base_dir/${hook_type}.local"
      if [ -f "$hook_file" ]; then
        eval "$mounts_var+=(\"-v\" \"$hook_file:/sandbox/hooks/${hook_name}-${hook_type}.local:ro\")"
      fi
    done
  done
}

# ===== 挂载辅助函数 =====
# 映射 gitconfig
dbox_map_gitconfig() {
  local mounts_var="$1"
  eval "$mounts_var=()"
  if [ -f "$HOME/.gitconfig" ]; then
    eval "$mounts_var+=(\"-v\" \"$HOME/.gitconfig:/home/devuser/.gitconfig:ro\")"
  fi
}

# 映射 tool.sh
dbox_map_tool_script() {
  local tool="$1"
  local mounts_var="$2"
  local tool_dir="$DBOX_ROOT/$tool"

  eval "$mounts_var=()"

  if [ ! -f "$tool_dir/tool.sh" ]; then
    dbox_error "工具执行脚本不存在: $tool_dir/tool.sh"
    return 1
  fi
  eval "$mounts_var+=(\"-v\" \"$tool_dir/tool.sh:/sandbox/tool.sh:ro\")"
}

# 映射 service.sh
dbox_map_service_script() {
  local tool="$1"
  local mounts_var="$2"
  local tool_dir="$DBOX_ROOT/$tool"

  eval "$mounts_var=()"

  if [ ! -f "$tool_dir/service.sh" ]; then
    dbox_error "服务脚本不存在: $tool_dir/service.sh"
    return 1
  fi
  eval "$mounts_var+=(\"-v\" \"$tool_dir/service.sh:/sandbox/service.sh:ro\")"
}

# ===== 容器运行函数 =====
# 运行临时容器
dbox_run_container() {
  local mode="$1"
  local tool="$2"
  local profile="${3:-default}"
  shift 3
  local args=("$@")

  local tool_dir="$DBOX_ROOT/$tool"
  local profile_dir="$tool_dir/profiles/$profile"
  local workspace_dir="$(pwd)"

  # 确保镜像存在
  dbox_ensure_image

  # 确保 profile 存在
  dbox_ensure_profile "$tool" "$profile" || return 1

  # 加载配置
  local env_vars=()
  dbox_load_env "$tool" "$profile" env_vars

  local volume_mounts workdir_arg
  dbox_load_mappings "$tool" "$profile" volume_mounts workdir_arg || return 1

  local env_mounts
  dbox_load_env_files "$tool" "$profile" env_mounts

  local hook_mounts
  dbox_load_hooks "$tool" "$profile" hook_mounts

  local gitconfig_mounts
  dbox_map_gitconfig gitconfig_mounts

  local tool_mounts
  dbox_map_tool_script "$tool" tool_mounts || return 1

  # 合并所有挂载
  local all_mounts=()
  all_mounts+=("${volume_mounts[@]}")
  all_mounts+=("${env_mounts[@]}")
  all_mounts+=("${hook_mounts[@]}")
  all_mounts+=("${gitconfig_mounts[@]}")
  all_mounts+=("${tool_mounts[@]}")

  # 根据模式决定运行命令
  local container_cmd=()
  case "$mode" in
    run)
      container_cmd=("/sandbox/tool.sh" "${args[@]}")
      ;;
    shell)
      container_cmd=("/bin/bash" "${args[@]}")
      ;;
    tmux)
      local exec_cmd_str="/sandbox/tool.sh"
      for arg in "${args[@]}"; do
        exec_cmd_str="$exec_cmd_str $(printf '%q' "$arg")"
      done
      container_cmd=("tmux" "-CCu" "new" "$exec_cmd_str")
      ;;
    *)
      dbox_error "未知的模式: $mode"
      return 1
      ;;
  esac

  # 检测是否在 TTY 中
  local tty_flag=""
  if [ -t 0 ]; then
    tty_flag="-it"
  fi

  # 启动容器
  docker run $tty_flag --rm --init \
    --entrypoint /sandbox/entrypoint \
    "${workdir_arg[@]}" \
    "${env_vars[@]}" \
    "${all_mounts[@]}" \
    "$DBOX_IMAGE_NAME" \
    "${container_cmd[@]}"
}

# 在已运行容器中执行命令
dbox_exec_container() {
  local tool="$1"
  local profile="${2:-default}"
  shift 2
  local args=("$@")

  local container_name
  container_name="$(dbox_container_name "$tool" "$profile")"

  # 检查容器是否在运行
  if ! dbox_container_running "$container_name"; then
    dbox_error "服务容器未运行: $container_name"
    dbox_info "请先用以下命令启动:"
    if [ "$profile" = "default" ]; then
      dbox_info "  d -u ${tool}"
    else
      dbox_info "  d -u ${tool}-${profile}"
    fi
    return 1
  fi

  docker exec -it "$container_name" /sandbox/entrypoint /sandbox/tool.sh "${args[@]}"
}

# 启动容器 shell
dbox_shell_container() {
  local tool="$1"
  local profile="${2:-default}"

  local container_name
  container_name="$(dbox_container_name "$tool" "$profile")"

  # 服务型：在已运行容器中进入 shell
  if dbox_is_service "$tool"; then
    if ! dbox_container_running "$container_name"; then
      dbox_error "服务容器未运行: $container_name"
      dbox_info "请先用以下命令启动:"
      dbox_info "  d -u ${tool}"
      return 1
    fi

    docker exec -it "$container_name" /bin/bash
  else
    # 命令型：启动新容器进入 shell
    dbox_run_container "shell" "$tool" "$profile"
  fi
}

# ===== 服务管理函数 =====
# 启动服务容器
dbox_start_service() {
  local tool="$1"
  local profile="${2:-default}"

  local tool_dir="$DBOX_ROOT/$tool"
  local profile_dir="$tool_dir/profiles/$profile"

  local container_name
  container_name="$(dbox_container_name "$tool" "$profile")"

  # 检查是否已在运行
  if dbox_container_running "$container_name"; then
    dbox_info "✓ 服务已在运行: $container_name"
    return 0
  fi

  # 检查是否存在但已停止
  if dbox_container_exists "$container_name"; then
    dbox_info "启动已存在的容器: $container_name"
    docker start "$container_name"
    dbox_info "✓ 服务已启动: $container_name"
    return 0
  fi

  # 确保镜像存在
  dbox_ensure_image

  # 确保 profile 存在
  dbox_ensure_profile "$tool" "$profile" || return 1

  # 加载配置
  local env_vars=()
  dbox_load_env "$tool" "$profile" env_vars

  local volume_mounts workdir_arg
  dbox_load_mappings "$tool" "$profile" volume_mounts workdir_arg || return 1

  local env_mounts
  dbox_load_env_files "$tool" "$profile" env_mounts

  local hook_mounts
  dbox_load_hooks "$tool" "$profile" hook_mounts

  local gitconfig_mounts
  dbox_map_gitconfig gitconfig_mounts

  # 检查 service.sh 是否存在
  if [ ! -f "$tool_dir/service.sh" ]; then
    dbox_error "$tool 不是服务型工具"
    return 1
  fi

  local service_mounts
  dbox_map_service_script "$tool" service_mounts || return 1
  local start_cmd="/sandbox/service.sh"

  # 合并所有挂载
  local all_mounts=()
  all_mounts+=("${volume_mounts[@]}")
  all_mounts+=("${env_mounts[@]}")
  all_mounts+=("${hook_mounts[@]}")
  all_mounts+=("${gitconfig_mounts[@]}")
  if [ -n "${service_mounts:-}" ]; then
    all_mounts+=("${service_mounts[@]}")
  fi

  # 启动容器（后台运行）
  docker run -d \
    --name "$container_name" \
    --restart unless-stopped \
    --init \
    --entrypoint /sandbox/entrypoint \
    "${workdir_arg[@]}" \
    "${env_vars[@]}" \
    "${all_mounts[@]}" \
    "$DBOX_IMAGE_NAME" \
    $start_cmd > /dev/null

  dbox_info "✓ 服务已启动: $container_name"
}

# 停止服务容器
dbox_stop_service() {
  local tool="$1"
  local profile="${2:-default}"

  local container_name
  container_name="$(dbox_container_name "$tool" "$profile")"

  # 检查容器是否存在
  if ! dbox_container_exists "$container_name"; then
    dbox_error "容器不存在: $container_name"
    return 1
  fi

  # Graceful shutdown (30秒)
  docker stop -t 30 "$container_name" > /dev/null
  docker rm "$container_name" > /dev/null

  dbox_info "✓ 服务已停止: $container_name"
}

# 重启服务容器
dbox_restart_service() {
  local tool="$1"
  local profile="${2:-default}"

  dbox_stop_service "$tool" "$profile" 2>/dev/null || true
  dbox_start_service "$tool" "$profile"
}

# 列出服务容器
dbox_list_services() {
  docker ps --filter "name=dbox-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
}

# ===== 主入口 =====
main() {
  dbox_parse_args "$@"

  case "$ACTION" in
    help)
      dbox_show_help
      exit 0
      ;;
    version)
      dbox_show_version
      exit 0
      ;;
    list)
      dbox_list_services
      exit 0
      ;;
    up)
      if [ -z "$TOOL" ]; then
        dbox_error "必须指定工具"
        dbox_show_help
        exit 1
      fi
      dbox_check_tool "$TOOL" || exit 1
      if ! dbox_is_service "$TOOL"; then
        dbox_error "$TOOL 不是服务型工具"
        exit 1
      fi
      dbox_start_service "$TOOL" "$PROFILE"
      ;;
    down)
      if [ -z "$TOOL" ]; then
        dbox_error "必须指定工具"
        dbox_show_help
        exit 1
      fi
      dbox_stop_service "$TOOL" "$PROFILE"
      ;;
    restart)
      if [ -z "$TOOL" ]; then
        dbox_error "必须指定工具"
        dbox_show_help
        exit 1
      fi
      dbox_restart_service "$TOOL" "$PROFILE"
      ;;
    shell)
      if [ -z "$TOOL" ]; then
        dbox_error "必须指定工具"
        dbox_show_help
        exit 1
      fi
      dbox_check_tool "$TOOL" || exit 1
      dbox_shell_container "$TOOL" "$PROFILE"
      ;;
    "")
      # 无标志，执行工具
      if [ -z "$TOOL" ]; then
        dbox_show_help
        exit 0
      fi
      dbox_check_tool "$TOOL" || exit 1

      # 加载工具配置
      dbox_load_config "$TOOL"

      if dbox_is_service "$TOOL"; then
        # 服务型：在已运行容器中执行
        dbox_exec_container "$TOOL" "$PROFILE" "${ARGS[@]}"
      else
        # 命令型：判断是否使用 tmux 模式
        local mode="run"
        if dbox_is_iterm2 && [ "$TMUX_IN_ITERM" = "true" ]; then
          mode="tmux"
        fi
        dbox_run_container "$mode" "$TOOL" "$PROFILE" "${ARGS[@]}"
      fi
      ;;
    *)
      dbox_error "未知操作: $ACTION"
      dbox_show_help
      exit 1
      ;;
  esac
}

# 执行主入口
main "$@"
