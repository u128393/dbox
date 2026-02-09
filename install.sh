#!/bin/bash

# dbox 安装脚本
# 在 ~/.local/bin/ 创建 d、ds、dt 命令链接

set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
DBOX_SCRIPT="$SCRIPT_DIR/dbox.sh"

# 创建 ~/.local/bin 目录（如果不存在）
mkdir -p "$BIN_DIR"

echo "🔍 安装 dbox 命令..."

# 检查 dbox.sh 是否存在
if [ ! -f "$DBOX_SCRIPT" ]; then
  echo "❌ 错误: dbox.sh 不存在于 $SCRIPT_DIR" >&2
  exit 1
fi

# 确保可执行
chmod +x "$DBOX_SCRIPT"

# 安装函数
install_command() {
  local link_name="$1"
  local link_target="$BIN_DIR/$link_name"

  echo
  echo "📌 安装 $link_name..."

  # 检查符号链接是否已存在
  if [ -L "$link_target" ]; then
    existing_target="$(readlink "$link_target")"
    if [ "$existing_target" = "$DBOX_SCRIPT" ]; then
      echo "   ✓ $link_name 已正确链接"
      return 0
    else
      echo "   ⚠️  $link_name 已指向其他目标: $existing_target"
      read -p "   是否覆盖？[y/N] "
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$link_target"
        ln -s "$DBOX_SCRIPT" "$link_target"
        echo "   ✅ $link_name -> $DBOX_SCRIPT"
        return 0
      else
        echo "   ⏭️  跳过 $link_name"
        return 0
      fi
    fi
  elif [ -e "$link_target" ]; then
    echo "   ⚠️  $link_name 已存在且不是符号链接"
    read -p "   是否覆盖？[y/N] "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm "$link_target"
      ln -s "$DBOX_SCRIPT" "$link_target"
      echo "   ✅ $link_name -> $DBOX_SCRIPT"
      return 0
    else
      echo "   ⏭️  跳过 $link_name"
      return 0
    fi
  else
    # 创建符号链接
    ln -s "$DBOX_SCRIPT" "$link_target"
    echo "   ✅ $link_name -> $DBOX_SCRIPT"
    return 0
  fi
}

# 安装所有命令
install_command "d"
install_command "ds"
install_command "dt"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "安装完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "可用命令:"
echo "   d  <tool>[-<profile>] [args...]  # 运行工具（如 claude）"
echo "   ds <tool>[-<profile>] [args...]  # 启动 bash shell"
echo "   dt <tool>[-<profile>]            # 以 tmux 模式运行工具"
echo
echo "示例:"
echo "   d claude           # 运行 claude (默认配置)"
echo "   d claude-zai       # 运行 claude (zai 配置)"
echo "   d claude --version # 传递工具参数"
echo "   ds claude          # 启动 claude 容器的 bash shell"
echo "   dt claude          # 以 tmux 模式运行 claude"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "自动补全设置"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "在 ~/.bashrc 或 ~/.zshrc 中添加以下行来启用自动补全："
echo
echo "   source \"$SCRIPT_DIR/completion\""
echo
