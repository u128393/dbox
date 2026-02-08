#!/bin/bash

# 根据 NO_SKIP_PERMISSIONS 环境变量决定是否跳过权限确认
if [ "$NO_SKIP_PERMISSIONS" = "1" ]; then
  exec claude "$@"
else
  exec claude --dangerously-skip-permissions "$@"
fi
