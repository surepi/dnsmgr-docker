#!/bin/bash
set -e

# 如果目录里没有代码，启动时执行一次全量拉取
if [ ! -f "/app/www/think" ]; then
    /usr/local/bin/update_code.sh
fi

# 启动 crond 守护进程
crond -L /var/log/cron.log

# 启动 CMD (即 supervisord)
exec "$@"