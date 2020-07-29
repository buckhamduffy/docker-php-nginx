FROM php:7.4-fpm-alpine


# Setup extensions
RUN apk add --no-cache \
      freetype \
      libjpeg-turbo \
      libpng \
      freetype-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      oniguruma-dev \
      libxml2-dev \
      curl-dev \
      zip libzip-dev \
      $PHPIZE_DEPS \
      nginx \
      supervisor \
      curl \
    && docker-php-ext-configure gd \
      --with-freetype=/usr/include/ \
      --with-jpeg=/usr/include/ \
    && docker-php-ext-configure zip \
    && docker-php-ext-install -j$(nproc) gd pdo_mysql opcache mbstring xml curl zip \
    && docker-php-ext-enable gd pdo_mysql opcache mbstring xml curl zip \
    && apk del --no-cache \
      freetype-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      oniguruma-dev \
      libxml2-dev \
      curl-dev \
    && rm -rf /tmp/* \
    && rm /etc/nginx/conf.d/default.conf

# Install Redis
RUN pecl install redis \
    && docker-php-ext-enable redis

RUN curl http://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer && composer global require hirak/prestissimo

# Nginx
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/php-fpm.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Setup document root
RUN mkdir -p /var/www/html && \
  chown -R nobody.nobody /var/www/html && \
  chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/log/nginx

# Add application
WORKDIR /var/www/html
#COPY --chown=nobody ./ /var/www/html/

# Expose the port nginx is reachable on
EXPOSE 80

# Let supervisord start nginx & php-fpm
CMD ["sh","/entrypoint.sh"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping