# Starting point
FROM alpine:latest

# Start in the DocumentRoot
WORKDIR /var/www/html

# Use the testing repository
RUN echo 'http://nl.alpinelinux.org/alpine/edge/testing/' | tee -a /etc/apk/repositories

# Install some tools
RUN apk add --update sed man bash sudo tzdata git htop vim mc \
    wget lynx curl parallel

# System wide customizations
RUN echo "alias ll='ls -la --color'" | tee -a /etc/profile.d/bash-aliases.sh

# Set up timezone
RUN cp /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime \
    && echo "Europe/Amsterdam" >  /etc/timezone \
    && apk del tzdata

# Install PHP 7 and nginx
RUN apk --update add php7 php7-fpm nginx supervisor \
    php7-mbstring php7-mcrypt php7-intl php7-json php7-pdo_mysql php7-redis \
    php7-memcached php7-gd php7-curl php7-xsl php7-phar php7-openssl \
    && ln -s /usr/bin/php7 /usr/bin/php

# Customizations
RUN sed -i "s/^;\(date\.timezone\(\s*\)\?=\).*/\1 Europe\/Amsterdam/" /etc/php7/php.ini \
    && sed -i "s/^;\(date\.timezone\(\s*\)\?=\).*/\1 Europe\/Amsterdam/" /etc/php7/php.ini \
    && sed -i "s/^\(memory_limit\(\s*\)\?=\).*/\1 4G/" /etc/php7/php.ini

# Install composer
RUN wget -O - https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && composer self-update

# Clean up after install
RUN rm -rf /var/cache/apk/*

# Add application
RUN rm -rf /var/www/html
ADD . /var/www/html

# Expose web server
EXPOSE 80

# Add nginx
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && mkdir /run/nginx
# Copy in config files
COPY php-fpm.conf /etc/php7/php-fpm.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY nginx-site.conf /etc/nginx/sites-enabled/default

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
