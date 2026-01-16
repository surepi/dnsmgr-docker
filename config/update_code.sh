#!/bin/bash
# 下载、解压并覆盖代码，重新设置权限
wget https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip -O /tmp/www.zip
unzip -o /tmp/www.zip -d /tmp/
if [ -d "/tmp/dnsmgr-main" ]; then
    cp -r /tmp/dnsmgr-main/. /app/www/
    rm -rf /tmp/dnsmgr-main
fi
rm -f /tmp/www.zip
chown -R www.www /app/www/runtime /app/www/extend 2>/dev/null || true