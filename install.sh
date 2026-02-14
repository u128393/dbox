#!/bin/bash

# dbox 安装脚本

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

# 安装 d 命令
install_command "d"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "安装完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "可用命令:"
echo "   d [flags] <tool>[-<profile>] [args...]  # 运行工具"
echo
echo "常用标志:"
echo "   -s, --shell    启动容器 shell"
echo "   -u, --up       启动服务（后台运行）"
echo "   -d, --down     停止服务"
echo "   -l, --list     列出所有容器"
echo "   -h, --help     显示帮助"
echo
echo "示例:"
echo "   d claude           # 运行 claude (默认配置)"
echo "   d claude-zai       # 运行 claude (zai 配置)"
echo "   d claude --version # 传递工具参数"
echo "   d -s claude        # 启动 claude 容器 shell"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "自动补全设置"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "在 ~/.bashrc 或 ~/.zshrc 中添加以下行来启用自动补全："
echo
echo "   source \"$SCRIPT_DIR/completion\""
echo
