#!/bin/bash

set -e

# 设置 PATH
export PATH="$HOME/.local/bin:$PATH"

# 全局 pre-exec
if [ -f "/sandbox/hooks/global-pre-exec" ]; then
  /sandbox/hooks/global-pre-exec
fi
# 全局 pre-exec.local
if [ -f "/sandbox/hooks/global-pre-exec.local" ]; then
  /sandbox/hooks/global-pre-exec.local
fi
# 工具级 pre-exec
if [ -f "/sandbox/hooks/tool-pre-exec" ]; then
  /sandbox/hooks/tool-pre-exec
fi
# 工具级 pre-exec.local
if [ -f "/sandbox/hooks/tool-pre-exec.local" ]; then
  /sandbox/hooks/tool-pre-exec.local
fi
# profile 级 pre-exec
if [ -f "/sandbox/hooks/profile-pre-exec" ]; then
  /sandbox/hooks/profile-pre-exec
fi
# profile 级 pre-exec.local
if [ -f "/sandbox/hooks/profile-pre-exec.local" ]; then
  /sandbox/hooks/profile-pre-exec.local
fi

# 执行传入的命令
EXIT_CODE=0
"$@" || EXIT_CODE=$?

# profile 级 post-exec.local
if [ -f "/sandbox/hooks/profile-post-exec.local" ]; then
  /sandbox/hooks/profile-post-exec.local
fi

# profile 级 post-exec
if [ -f "/sandbox/hooks/profile-post-exec" ]; then
  /sandbox/hooks/profile-post-exec
fi
# 工具级 post-exec.local
if [ -f "/sandbox/hooks/tool-post-exec.local" ]; then
  /sandbox/hooks/tool-post-exec.local
fi
# 工具级 post-exec
if [ -f "/sandbox/hooks/tool-post-exec" ]; then
  /sandbox/hooks/tool-post-exec
fi
# 全局 post-exec.local
if [ -f "/sandbox/hooks/global-post-exec.local" ]; then
  /sandbox/hooks/global-post-exec.local
fi
# 全局 post-exec
if [ -f "/sandbox/hooks/global-post-exec" ]; then
  /sandbox/hooks/global-post-exec
fi

exit $EXIT_CODE
