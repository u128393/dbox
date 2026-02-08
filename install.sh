#!/bin/bash

# dbox 安装脚本
# 在 ~/.local/bin/ 创建 d 命令链接

set -e

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
RUN_SCRIPT="$SCRIPT_DIR/run.sh"
LINK_NAME="d"
LINK_TARGET="$BIN_DIR/$LINK_NAME"

# 创建 ~/.local/bin 目录（如果不存在）
mkdir -p "$BIN_DIR"

echo "🔍 安装 d 命令..."

# 检查 run.sh 是否存在
if [ ! -f "$RUN_SCRIPT" ]; then
  echo "错误: run.sh 不存在于 $SCRIPT_DIR" >&2
  exit 1
fi

# 检查符号链接是否已存在
if [ -L "$LINK_TARGET" ]; then
  existing_target="$(readlink "$LINK_TARGET")"
  if [ "$existing_target" = "$RUN_SCRIPT" ]; then
    echo "   ✓ $LINK_NAME 已正确链接"
  else
    echo "   ⚠️  $LINK_NAME 已指向其他目标: $existing_target"
    read -p "   是否覆盖？[y/N] "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm "$LINK_TARGET"
      ln -s "$RUN_SCRIPT" "$LINK_TARGET"
      echo "   ✅ $LINK_NAME -> $RUN_SCRIPT"
    else
      echo "   取消安装"
      exit 1
    fi
  fi
elif [ -e "$LINK_TARGET" ]; then
  echo "   ⚠️  $LINK_NAME 已存在且不是符号链接"
  read -p "   是否覆盖？[y/N] "
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm "$LINK_TARGET"
    ln -s "$RUN_SCRIPT" "$LINK_TARGET"
    echo "   ✅ $LINK_NAME -> $RUN_SCRIPT"
  else
    echo "   取消安装"
    exit 1
  fi
else
  # 创建符号链接
  ln -s "$RUN_SCRIPT" "$LINK_TARGET"
  echo "   ✅ $LINK_NAME -> $RUN_SCRIPT"
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "安装完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "用法:"
echo "   d <tool>[-<profile>] [args...]"
echo
echo "示例:"
echo "   d claude          # 使用 claude 工具（默认配置）"
echo "   d claude-zai      # 使用 claude 工具的 zai 配置"
echo "   d claude --version # 传递参数给工具"
echo
echo "请确保 ~/.local/bin 在你的 PATH 中:"
echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "自动补全设置"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "在 ~/.bashrc 或 ~/.zshrc 中添加以下行来启用自动补全："
echo
echo "   source \"$SCRIPT_DIR/completion\""
echo
