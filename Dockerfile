# 使用 Alpine 3.19 作为基础镜像
ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION}

WORKDIR /app/www

# 1. 安装基础工具和编译 SSH2 所需的依赖
RUN apk add --no-cache \
    bash curl wget unzip nginx supervisor \
    libssh2-dev \
    gcc g++ make autoconf # 编译工具

# 2. 安装 PHP 8.2 及其核心扩展
RUN apk add --no-cache \
    php82 php82-dev php82-pear \
    php82-fpm php82-ctype php82-curl php82-dom php82-fileinfo \
    php82-gd php82-gettext php82-intl php82-iconv php82-mbstring \
    php82-mysqli php82-opcache php82-openssl php82-phar php82-sodium \
    php82-session php82-simplexml php82-tokenizer php82-xml \
    php82-xmlreader php82-xmlwriter php82-zip php82-pdo \
    php82-pdo_mysql php82-pdo_sqlite php82-pecl-swoole

# 3. 编译并启用 SSH2 扩展
RUN pecl82 install ssh2-1.3.1 && \
    echo "extension=ssh2.so" > /etc/php82/conf.d/ssh2.ini && \
    apk del gcc g++ make autoconf # 编译完成后卸载工具以减小体积

# 4. 拷贝项目配置文件
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php82/php-fpm.d/www.conf
COPY config/php.ini /etc/php82/conf.d/custom.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/update_code.sh /usr/local/bin/update_code.sh
RUN chmod +x /usr/local/bin/update_code.sh

# 5. 准备应用环境
RUN adduser -D -s /sbin/nologin -g www www && \
    chown -R www.www /var/lib/nginx /var/log/nginx /app/www

# 6. 配置计划任务 (Crontab)
RUN echo "*/15 * * * * cd /app/www && /usr/bin/php82 think opiptask" > /var/spool/cron/crontabs/www && \
    echo "* * * * * cd /app/www && /usr/bin/php82 think certtask" >> /var/spool/cron/crontabs/www && \
    echo "0 */4 * * * /usr/local/bin/update_code.sh >> /var/log/cron.log 2>&1" >> /var/spool/cron/crontabs/www && \
    chown www:www /var/spool/cron/crontabs/www && \
    chmod 600 /var/spool/cron/crontabs/www

# 7. 拷贝预构建的代码 (由 GitHub Actions 准备好的带 vendor 的代码)
COPY . /usr/src/www

# 8. 入口设置
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1