# 基础镜像
ARG ALPINE_VERSION=3.18
FROM alpine:${ALPINE_VERSION}

# 工作目录
WORKDIR /app/www

# 安装依赖包
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
    supervisor && \
    rm -rf /var/cache/apk/*

# 配置 Nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# 配置 PHP-FPM
ENV PHP_INI_DIR=/etc/php82
COPY config/fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY config/php.ini ${PHP_INI_DIR}/conf.d/custom.ini

# 配置 supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 添加应用代码
RUN mkdir -p /usr/src && \
    wget -q https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip -O /usr/src/www.zip && \
    unzip /usr/src/www.zip -d /usr/src/ && \
    mv /usr/src/dnsmgr-main /usr/src/www && \
    rm -f /usr/src/www.zip && \
    chown -R www:www /usr/src/www && \
    chmod -R 755 /usr/src/www

# 安装 Composer 并安装依赖
RUN wget -q https://mirrors.aliyun.com/composer/composer.phar -O /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer && \
    composer install -d /usr/src/www --no-dev && \
    composer clear-cache

# 创建用户并设置权限
RUN adduser -D -s /sbin/nologin -g www www && \
    mkdir -p /var/lib/nginx /var/log/nginx && \
    chown -R www:www /usr/src/www /var/lib/nginx /var/log/nginx

# 配置 crontab
RUN echo "*/15 * * * * cd /app/www && /usr/bin/php82 think opiptask" | crontab -u www - && \
    echo "*/1 * * * * cd /app/www && /usr/bin/php82 think certtask" | crontab -u www - && \
    crontab -l -u www

# 复制 entrypoint 脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 暴露端口
EXPOSE 80

# 启动命令
CMD ["sh", "/entrypoint.sh"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl --silent --fail http://127.0.0.1 || exit 1