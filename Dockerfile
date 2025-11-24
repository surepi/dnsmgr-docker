ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION}
# Setup document root
WORKDIR /usr/src/www

# Install packages and remove default server definition
RUN apk add --no-cache \
  bash \
  curl \
  nginx \
  php82 \
  php82-ctype \
  php82-curl \
  php82-dom \
  php82-fileinfo \
  php82-fpm \
  php82-gd \
  php82-gettext \
  php82-intl \
  php82-iconv \
  php82-mbstring \
  php82-mysqli \
  php82-opcache \
  php82-openssl \
  php82-phar \
  php82-sodium \
  php82-session \
  php82-simplexml \
  php82-tokenizer \
  php82-xml \
  php82-xmlreader \
  php82-xmlwriter \
  php82-zip \
  php82-pdo \
  php82-pdo_mysql \
  php82-pdo_sqlite \
  php82-pecl-swoole \
  php82-bcmath \
  php82-json \
  supervisor

# Configure nginx - http
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
ENV PHP_INI_DIR=/etc/php82
COPY config/fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY config/php.ini ${PHP_INI_DIR}/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add application
RUN mkdir -p /usr/src && \
    wget --timeout=30 --tries=3 https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip -O /usr/src/www.zip && \
    unzip /usr/src/www.zip -d /usr/src/ && \
    mv /usr/src/dnsmgr-main /usr/src/www && \
    rm -f /usr/src/www.zip && \
    ls -la /usr/src/www && \
    test -f /usr/src/www/composer.json || (echo "composer.json not found" && exit 1)

# Install composer
RUN wget https://mirrors.aliyun.com/composer/composer.phar -O /usr/local/bin/composer && chmod +x /usr/local/bin/composer

# Install composer dependencies after application is copied
RUN cd /usr/src/www && \
    composer validate --no-check-publish && \
    composer install --no-dev --optimize-autoloader --ignore-platform-req=ext-ssh2 --ignore-platform-req=ext-ftp --no-interaction

RUN adduser -D -s /sbin/nologin -g www www && chown -R www.www /usr/src/www /var/lib/nginx /var/log/nginx

# 创建源码更新脚本
RUN cat > /usr/local/bin/update-source.sh << 'EOF'
#!/bin/bash
set -e

cd /usr/src

# 备份当前源码
if [ -d www ]; then
    cp -r www www.backup.$(date +%Y%m%d%H%M%S)
fi

# 下载最新源码
if wget --timeout=30 --tries=3 -q https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip -O www.zip; then
    # 解压源码
    if unzip -o www.zip -d /usr/src/; then
        # 移动源码到正确位置
        rm -rf www
        mv dnsmgr-main www
        rm -f www.zip
        
        # 安装依赖
        cd www
        composer validate --no-check-publish && \
        composer install --no-dev --optimize-autoloader --ignore-platform-req=ext-ssh2 --ignore-platform-req=ext-ftp --no-interaction
        
        echo "源码更新成功 $(date)"
        
        # 标记需要重启服务
        touch /tmp/restart-required
    else
        echo "解压失败，恢复备份"
        # 恢复备份
        if [ -d www.backup.* ]; then
            rm -rf www
            mv www.backup.* www
        fi
    fi
else
    echo "下载失败，跳过更新"
fi
EOF

RUN chmod +x /usr/local/bin/update-source.sh

# 创建服务重启脚本
RUN cat > /usr/local/bin/restart-services.sh << 'EOF'
#!/bin/bash
while read line; do
    # 检查是否需要重启服务
    if [ -f /tmp/restart-required ]; then
        echo "检测到源码更新，重启服务..."
        rm -f /tmp/restart-required
        
        # 优雅重启PHP-FPM
        pkill -USR2 php-fpm82 2>/dev/null || true
        
        # 优雅重启Nginx
        nginx -s reload 2>/dev/null || true
        
        echo "服务重启完成"
    fi
done
EOF

RUN chmod +x /usr/local/bin/restart-services.sh

# crontab - 业务任务和源码更新
RUN (echo "*/15 * * * * cd /usr/src/www && /usr/bin/php82 think opiptask"; \
     echo "0 * * * * /usr/local/bin/update-source.sh >> /var/log/update-source.log 2>&1") | crontab -u www -

# copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["sh", "/entrypoint.sh"]

# Expose the port nginx is reachable on
EXPOSE 80

# Let supervisord start nginx & php-fpm
CMD ["sh", "-c", "crond && /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1