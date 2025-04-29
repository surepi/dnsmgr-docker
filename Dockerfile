# 基础镜像
ARG ALPINE_VERSION=3.18
FROM alpine:${ALPINE_VERSION}

# 工作目录
WORKDIR /app/www
ENV PATH="/usr/bin:${PATH}"
# 安装依赖包并清理缓存
RUN apk add --no-cache \
    bash \
    curl \
    unzip \
    nginx \
    php80 \
    php80-ctype \
    php80-curl \
    php80-dom \
    php80-fileinfo \
    php80-fpm \
    php80-gd \
    php80-gettext \
    php80-intl \
    php80-iconv \
    php80-mbstring \
    php80-mysqli \
    php80-opcache \
    php80-openssl \
    php80-phar \
    php80-sodium \
    php80-session \
    php80-simplexml \
    php80-tokenizer \
    php80-xml \
    php80-xmlreader \
    php80-xmlwriter \
    php80-zip \
    php80-pdo \
    php80-pdo_mysql \
    php80-pdo_sqlite \
    php80-pecl-swoole \
    php80-ssh2 \
    php80-ftp \
    supervisor && \
    rm -rf /var/cache/apk/*

# 配置 Nginx、PHP-FPM 和 supervisord
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php80/php-fpm.d/www.conf
COPY config/php.ini /etc/php80/conf.d/custom.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# 下载应用代码
RUN mkdir -p /usr/src && \
wget -q https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip -O /usr/src/www.zip && \
unzip /usr/src/www.zip -d /usr/src/ && \
mv /usr/src/dnsmgr-main /usr/src/www && \
rm -f /usr/src/www.zip && \
chown -R www:www /usr/src/www && \
chmod -R 755 /usr/src/www

# 下载并安装 Composer
RUN wget -q https://mirrors.aliyun.com/composer/composer.phar -O /usr/local/bin/composer && \
chmod +x /usr/local/bin/composer

# 安装 Composer 依赖
RUN /usr/local/bin/composer install -d /usr/src/www --no-dev && \
/usr/local/bin/composer clear-cache
# 创建用户并设置权限
RUN adduser -D -s /sbin/nologin -g www www && \
    mkdir -p /var/lib/nginx /var/log/nginx && \
    chown -R www:www /usr/src/www /var/lib/nginx /var/log/nginx

# 配置 crontab
RUN echo "*/15 * * * * cd /app/www && /usr/bin/php80 think opiptask" | crontab -u www - && \
    echo "*/1 * * * * cd /app/www && /usr/bin/php80 think certtask" | crontab -u www - && \
    crontab -l -u www

# 复制 entrypoint 脚本并设置权限
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 暴露端口
EXPOSE 80

# 启动命令
CMD ["sh", "/entrypoint.sh"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl --silent --fail http://127.0.0.1 || exit 1