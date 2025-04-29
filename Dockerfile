# 基础镜像
FROM debian:bookworm

# 工作目录
WORKDIR /app/www
ENV PATH="/usr/bin:${PATH}"
# 安装基础系统包
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    unzip \
    nginx \
    supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 添加PHP官方仓库
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    gnupg2 && \
    curl -sSL https://packages.sury.org/php/apt.gpg | apt-key add - && \
    echo "deb https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装PHP核心
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-cli \
    php8.2-fpm \
    php8.2-common && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装基本PHP扩展 - 第1组
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-ctype \
    php8.2-curl \
    php8.2-dom && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装系统级依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装php8.2-fileinfo
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-fileinfo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装php8.2-mbstring
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-mbstring && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# openssl功能已包含在php8.2-common中，无需单独安装

# 安装基本PHP扩展 - 第3组
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-phar \
    php8.2-tokenizer \
    php8.2-xml && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装数据库相关PHP扩展
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-mysqli \
    php8.2-pdo \
    php8.2-pdo-mysql \
    php8.2-pdo-sqlite && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装其他PHP扩展
RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-gd \
    php8.2-intl \
    php8.2-sodium \
    php8.2-zip \
    php8.2-ftp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装需要额外仓库的PHP扩展
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common && \
    add-apt-repository -y ppa:ondrej/php && \
    apt-get update && \
    apt-get install -y php-ssh2 php-swoole && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 配置 Nginx、PHP-FPM 和 supervisord
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY config/php.ini /etc/php/8.2/fpm/conf.d/custom.ini
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