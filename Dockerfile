ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION} AS builder

# Install build dependencies
RUN apk add --no-cache \
    wget \
    unzip \
    php82 \
    php82-phar \
    php82-openssl \
    php82-curl

# Install composer
RUN wget -q https://mirrors.aliyun.com/composer/composer.phar -O /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# Download and prepare application
RUN mkdir -p /usr/src && \
    wget -q https://github.com/netcccyun/dnsmgr/archive/refs/heads/main.zip -O /usr/src/www.zip && \
    unzip -q /usr/src/www.zip -d /usr/src/ && \
    mv /usr/src/dnsmgr-main /usr/src/www && \
    rm -f /usr/src/www.zip

# Install composer dependencies
RUN composer install -d /usr/src/www --no-dev --no-interaction --prefer-dist --optimize-autoloader && \
    composer clear-cache

# Final stage
FROM alpine:${ALPINE_VERSION}

# Install runtime packages
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
    supervisor \
    dcron && \
    rm -rf /var/cache/apk/* /tmp/*

# Create www user
RUN adduser -D -s /sbin/nologin -u 1000 -g www www

# Setup document root
WORKDIR /app/www

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
ENV PHP_INI_DIR=/etc/php82
COPY config/fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY config/php.ini ${PHP_INI_DIR}/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy application from builder
COPY --from=builder --chown=www:www /usr/src/www /usr/src/www

# Set permissions
RUN chown -R www:www /var/lib/nginx /var/log/nginx /run && \
    mkdir -p /app/www/runtime && \
    chown -R www:www /app/www

# Setup crontab
RUN echo "*/15 * * * * cd /app/www && /usr/bin/php82 think opiptask" | crontab -u www -

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Start services
CMD crond && /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
