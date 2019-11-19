# Starting point
FROM debian:stretch

# Start in the DocumentRoot
WORKDIR /var/www/html

# Make apt tools stop complaining about the terminal
ENV DEBIAN_FRONTEND=noninteractive \
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

# apt-utils needed by apt-get for later
RUN >&2 echo "# Installing some basic packages..." \
    && apt-get -y update \
    && apt-get install -y \
        apt-utils locales \
        sudo man git htop vim mc \
        software-properties-common \
        apt-transport-https lsb-release wget lynx telnet curl \
        parallel bzip2 acl gnupg \
        exim4-daemon-light \
        supervisor nginx \
        jpegoptim optipng

RUN >&2 echo "# Configuring locales..." \
    && echo en_US.UTF-8 UTF-8 | tee /etc/locale.gen \
    && locale-gen \
    && dpkg-reconfigure locales \
    && update-locale LANG="en_US.UTF-8" LANGUAGE="en_US:en" LC_ALL="en_US.UTF-8"
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN >&2 echo "# Setting system timezone..." \
    && echo "Europe/Amsterdam" | tee /etc/timezone \
    && dpkg-reconfigure tzdata

RUN >&2 echo "# Setting up users and permissions..." \
    && adduser --gecos '' --uid 1000 --gid 50 --disabled-password php \
    && adduser php staff

RUN >&2 echo "# Install PHP 7 with extensions and update settings" \
    && wget -O - https://www.dotdeb.org/dotdeb.gpg | apt-key add - \
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

RUN >&2 echo "# Installing tooling (composer, nodejs)..." \
    && EXPECTED_SIGNATURE=$(wget -q -O - 'https://composer.github.io/installer.sig') \
    && wget -O composer-installer.php 'https://getcomposer.org/installer' \
    && INSTALLER_SIGNATURE=$(openssl dgst --sha384 -hex composer-installer.php | sed 's/^.* \(.*\)$/\1/') \
    && if [ "$INSTALLER_SIGNATURE" != "$EXPECTED_SIGNATURE" ] ; then >&2 echo 'ERROR: Invalid installer signature' && exit 1 ; fi \
    && php composer-installer.php --install-dir=/usr/local/bin --filename=composer \
    && rm composer-installer.php \
    && curl -sL https://deb.nodesource.com/setup_6.x | bash - \
    && apt-get install -y nodejs

RUN >&2 echo "# Ensure everything is up to date and cleaning up..." \
    && apt-get -y update && apt-get -y dist-upgrade \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* index.nginx-debian.html

# Add application
ADD ./web /var/www/html/web

RUN >&2 echo "# Give ownership of the web files to the php user" \
    && chown -R php.staff /var/www/html

# Expose web server
EXPOSE 80

RUN >&2 echo "# Redirecting nginx logs to stdout and stderr ..." \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log
# Copy config files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx-site.conf /etc/nginx/sites-enabled/default

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
