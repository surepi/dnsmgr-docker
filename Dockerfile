ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION}

WORKDIR /app/www

# 1. 安装基础依赖
RUN apk add --no-cache \
    bash curl nginx supervisor \
    php82 php82-fpm php82-ctype php82-curl php82-dom php82-fileinfo \
    php82-gd php82-intl php82-mbstring php82-mysqli php82-opcache \
    php82-openssl php82-phar php82-session php82-simplexml php82-tokenizer \
    php82-xml php82-xmlreader php82-xmlwriter php82-zip php82-pdo \
    php82-pdo_mysql php82-pecl-swoole

# 2. 拷贝配置文件
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/fpm-pool.conf /etc/php82/php-fpm.d/www.conf

# 3. 准备源码 (假设你本地有代码，如果没有则保留你原来的 wget 逻辑)
COPY . /usr/src/www
RUN rm -rf /usr/src/www/config /usr/src/www/Dockerfile # 移除镜像内不需要的配置源码

# 4. 安装 Composer 并处理依赖
RUN wget https://mirrors.aliyun.com/composer/composer.phar -O /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer && \
    cd /usr/src/www && composer install --no-dev --optimize-autoloader

# 5. 用户与权限
RUN adduser -D -s /sbin/nologin -g www www && \
    chown -R www.www /var/lib/nginx /var/log/nginx

# 6. 定时任务
# 1. 原有的 opiptask (每15分钟)
# 2. 新增的 certtask (每1分钟)
RUN echo "*/15 * * * * cd /app/www && /usr/bin/php82 think opiptask" > /var/spool/cron/crontabs/www && \
    echo "* * * * * cd /app/www && /usr/bin/php82 think certtask" >> /var/spool/cron/crontabs/www && \
    chown www:www /var/spool/cron/crontabs/www && \
    chmod 600 /var/spool/cron/crontabs/www

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1