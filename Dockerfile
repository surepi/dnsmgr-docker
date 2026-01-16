ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION}

# 1. 预定义变量，方便维护
ARG PHP_VER=php82
ENV TZ=Asia/Shanghai

# 2. 从官方镜像获取 Composer (比 wget 更标准、安全且体积小)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 3. 安装依赖 (合并 RUN 指令以减少层数)
# 移除了 bash (Alpine 默认 ash 足够)，添加了必要的 unzip/zip 用于源码解压
RUN apk add --no-cache \
    curl \
    nginx \
    supervisor \
    unzip \
    zip \
    ${PHP_VER} \
    ${PHP_VER}-fpm \
    ${PHP_VER}-ctype \
    ${PHP_VER}-curl \
    ${PHP_VER}-dom \
    ${PHP_VER}-fileinfo \
    ${PHP_VER}-gd \
    ${PHP_VER}-gettext \
    ${PHP_VER}-intl \
    ${PHP_VER}-iconv \
    ${PHP_VER}-mbstring \
    ${PHP_VER}-mysqli \
    ${PHP_VER}-opcache \
    ${PHP_VER}-openssl \
    ${PHP_VER}-phar \
    ${PHP_VER}-sodium \
    ${PHP_VER}-session \
    ${PHP_VER}-simplexml \
    ${PHP_VER}-tokenizer \
    ${PHP_VER}-xml \
    ${PHP_VER}-xmlreader \
    ${PHP_VER}-xmlwriter \
    ${PHP_VER}-zip \
    ${PHP_VER}-pdo \
    ${PHP_VER}-pdo_mysql \
    ${PHP_VER}-pdo_sqlite \
    ${PHP_VER}-pecl-swoole \
    ${PHP_VER}-bcmath \
    ${PHP_VER}-json \
    && ln -sf /usr/bin/${PHP_VER} /usr/bin/php \
    && adduser -D -s /sbin/nologin -g www www \
    && mkdir -p /usr/src/www /var/log/nginx \
    && chown -R www:www /var/lib/nginx /var/log/nginx

# 4. 配置 Nginx 和 PHP
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/${PHP_VER}/php-fpm.d/www.conf
COPY config/php.ini /etc/${PHP_VER}/conf.d/custom.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 5. 下载源码并安装依赖 (核心优化：使用 COPY --chown 避免二次权限修改)
# 注意：这里假设你希望构建时就包含代码。如果代码必须动态拉取，保留原有 wget 逻辑
WORKDIR /usr/src/www

# 使用中间临时层或直接下载，这里合并操作减少体积
RUN curl -L https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip -o /tmp/source.zip \
    && unzip -q /tmp/source.zip -d /tmp/source \
    && mv /tmp/source/dnsmgr-main/* . \
    && mv /tmp/source/dnsmgr-main/.[!.]* . 2>/dev/null || true \
    && rm -rf /tmp/source* \
    && composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/ \
    && composer install --no-dev --optimize-autoloader --ignore-platform-req=ext-ssh2 --ignore-platform-req=ext-ftp --no-interaction \
    && chown -R www:www /usr/src/www

# 6. 写入脚本 (优化了 Shell 脚本的逻辑和安全性)
# update-source.sh
RUN cat > /usr/local/bin/update-source.sh << 'EOF'
#!/bin/sh
set -e
WORKDIR="/usr/src/www"
BACKUP_DIR="/usr/src/www.backup.$(date +%Y%m%d%H%M%S)"

echo "Starting update at $(date)"

# 下载测试
if ! curl -sI https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip > /dev/null; then
    echo "Network unreachable, skipping update."
    exit 0
fi

# 备份
cp -r "$WORKDIR" "$BACKUP_DIR"

# 下载与部署
if curl -L -o /tmp/new_source.zip https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip; then
    unzip -q -o /tmp/new_source.zip -d /tmp/new_source
    
    # 覆盖文件 (使用 rsync 逻辑的替代方案，保留 vendor 以加速)
    cp -rf /tmp/new_source/dnsmgr-main/* "$WORKDIR/"
    
    rm -rf /tmp/new_source /tmp/new_source.zip
    
    cd "$WORKDIR"
    composer install --no-dev --optimize-autoloader --ignore-platform-req=ext-ssh2 --ignore-platform-req=ext-ftp --no-interaction
    
    # 修复权限
    chown -R www:www "$WORKDIR"
    
    echo "Update successful."
    touch /tmp/restart-required
    
    # 清理旧备份 (保留最近3个)
    ls -d /usr/src/www.backup.* | sort -r | tail -n +4 | xargs rm -rf 2>/dev/null || true
else
    echo "Download failed."
    rm -rf "$BACKUP_DIR"
    exit 1
fi
EOF

# restart-services.sh (改为检测脚本)
RUN cat > /usr/local/bin/check-restart.sh << 'EOF'
#!/bin/sh
if [ -f /tmp/restart-required ]; then
    echo "Restart signal detected. Reloading services..."
    rm -f /tmp/restart-required
    
    # 优雅重载
    pkill -USR2 php-fpm || true
    nginx -s reload || true
    
    echo "Services reloaded at $(date)"
fi
EOF

RUN chmod +x /usr/local/bin/update-source.sh /usr/local/bin/check-restart.sh

# 7. 配置 Crontab
# 注意：将业务任务和检查更新任务分开
RUN echo "*/15 * * * * cd /usr/src/www && /usr/bin/php think opiptask" > /var/spool/cron/crontabs/www \
    && echo "0 * * * * /usr/local/bin/update-source.sh >> /var/log/update.log 2>&1" >> /var/spool/cron/crontabs/www \
    && echo "* * * * * /usr/local/bin/check-restart.sh >> /var/log/restart.log 2>&1" >> /var/spool/cron/crontabs/root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

# 8. 启动命令优化
# 建议由 Supervisor 接管 crond，而不是在 CMD 中通过 sh 启动
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --timeout=5s CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1