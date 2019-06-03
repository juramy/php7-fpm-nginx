# Starting point
FROM debian:latest

# Start in the DocumentRoot
WORKDIR /var/www/html

# Make apt tools stop complaining about the terminal
ENV DEBIAN_FRONTEND noninteractive

# Install basic packages
# apt-utils needed by apt-get for later
RUN apt-get -y update \
    && apt-get install -y \
        apt-utils locales \
        sudo man git htop vim mc \
        software-properties-common \
        apt-transport-https lsb-release wget lynx telnet curl \
        parallel bzip2 acl gnupg \
        exim4-daemon-light \
        supervisor nginx nodejs

# Configure locales
RUN echo en_US.UTF-8 UTF-8 | tee /etc/locale.gen \
    && locale-gen \
    && dpkg-reconfigure locales \
    && update-locale LANG="en_US.UTF-8" LANGUAGE="en_US:en" LC_ALL="en_US.UTF-8"
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Set the system's timezone
RUN echo "Europe/Amsterdam" | tee /etc/timezone \
    && dpkg-reconfigure tzdata

# Install local mail transport agent
COPY update-exim4.conf.conf /etc/exim4/update-exim4.conf.conf
RUN update-exim4.conf && service exim4 restart

# Set up users and permissions
RUN adduser --gecos '' --uid 1000 --gid 50 --disabled-password php \
    && adduser php staff

# Install PHP 7 and extensions and update settings
RUN wget -O - https://www.dotdeb.org/dotdeb.gpg | apt-key add - \
    && echo "deb https://packages.dotdeb.org $(lsb_release -sc) all" | tee /etc/apt/sources.list.d/php.list \
    && echo "deb-src https://packages.dotdeb.org $(lsb_release -sc) all" | tee -a /etc/apt/sources.list.d/php.list \
    && apt-get -y update \
    && apt-get install -y php7.0-fpm php7.0-cli php7.0-mbstring php7.0-mcrypt php7.0-intl \
    php7.0-mysql php7.0-redis php7.0-memcached php7.0-gd php7.0-curl php7.0-xsl php-imagick \
    && sed -i "s/^;\(date\.timezone\(\s*\)\?=\).*/\1 Europe\/Amsterdam/" /etc/php/7.0/cli/php.ini \
    && sed -i "s/^;\(date\.timezone\(\s*\)\?=\).*/\1 Europe\/Amsterdam/" /etc/php/7.0/fpm/php.ini \
    && sed -i "s/^\(memory_limit\(\s*\)\?=\).*/\1 4G/" /etc/php/7.0/cli/php.ini \
    && sed -i "s/^\(memory_limit\(\s*\)\?=\).*/\1 256M/" /etc/php/7.0/fpm/php.ini \
    && phpenmod -v 7.0 -s ALL mbstring mcrypt intl pdo_mysql redis memcached gd curl xml xsl imagick

# Copy in php-fpm config file
COPY php-fpm.conf /etc/php/7.0/fpm/php-fpm.conf

# Install tooling
RUN wget -O - https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && composer self-update && \
    curl -sL https://deb.nodesource.com/setup_6.x | bash -

# One last update for everything and clean up cache and temp folders
RUN apt-get -y update && apt-get -y dist-upgrade && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add application
ADD . /var/www/html

# Give ownership of the files to the php user
RUN chown -R php.staff /var/www/html

# Expose web server
EXPOSE 80

# Add nginx
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log
# Copy config files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx-site.conf /etc/nginx/sites-enabled/default

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
