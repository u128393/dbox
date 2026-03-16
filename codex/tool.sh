#!/bin/bash

if [ "$NO_SKIP_PERMISSIONS" = "1" ]; then
  exec codex "$@"
else
  exec codex --dangerously-bypass-approvals-and-sandbox "$@"
fi
