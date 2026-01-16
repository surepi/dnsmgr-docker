# 使用指定的 Alpine 版本
ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION}

# 设置工作目录
WORKDIR /app/www

# 1. 安装系统依赖、Nginx、PHP 8.2 以及常用扩展
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    unzip \
    nginx \
    supervisor \
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
    php82-pecl-swoole

# 2. 配置 Nginx、PHP-FPM 和 Supervisor
# 请确保你的 config 目录下有这些文件
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php82/php-fpm.d/www.conf
COPY config/php.ini /etc/php82/conf.d/custom.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 3. 准备代码更新脚本
# 我们将更新逻辑写在脚本里，方便 crontab 调用
COPY config/update_code.sh /usr/local/bin/update_code.sh
RUN chmod +x /usr/local/bin/update_code.sh

# 4. 设置 Composer (可选：如果在构建时需要跑依赖)
RUN wget https://mirrors.aliyun.com/composer/composer.phar -O /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# 5. 创建运行用户并配置目录权限
RUN adduser -D -s /sbin/nologin -g www www && \
    mkdir -p /usr/src/www && \
    chown -R www.www /var/lib/nginx /var/log/nginx /app/www

# 6. 配置计划任务 (Crontab)
# - 每 15 分钟运行一次 opiptask
# - 每 1 分钟运行一次 certtask
# - 每 4 小时通过 update_code.sh 更新一次源码
RUN echo "*/15 * * * * cd /app/www && /usr/bin/php82 think opiptask" > /var/spool/cron/crontabs/www && \
    echo "* * * * * cd /app/www && /usr/bin/php82 think certtask" >> /var/spool/cron/crontabs/www && \
    echo "0 */4 * * * /usr/local/bin/update_code.sh >> /var/log/cron.log 2>&1" >> /var/spool/cron/crontabs/www && \
    chown www:www /var/spool/cron/crontabs/www && \
    chmod 600 /var/spool/cron/crontabs/www

# 7. 拷贝并配置入口脚本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 暴露 80 端口
EXPOSE 80

# 容器入口
ENTRYPOINT ["/entrypoint.sh"]

# 启动 Supervisord (它会拉起 Nginx 和 PHP-FPM)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# 健康检查
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1