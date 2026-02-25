#!/bin/bash

# 如果 aria2 没有运行才启动
pgrep -x aria2c >/dev/null || aria2c --daemon=true

# 启动 Firefox
exec firefox "$@"