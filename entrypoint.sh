#!/bin/bash
set -e

# 如果 /app/www 是空的（比如挂载了卷），则把源码拷贝进去
if [ ! -f "/app/www/think" ]; then
    cp -r /usr/src/www/. /app/www/
fi

# 设置权限
chown -R www.www /app/www/runtime /app/www/extend 2>/dev/null || true

# 启动 Crontab
crond -L /var/log/cron.log

# 执行命令
exec "$@"