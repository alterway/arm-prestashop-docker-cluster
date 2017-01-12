FROM alterway/php:5.6-cli

ENV TERM xterm
ENV DEBIAN_FRONTEND noninteractive

RUN mkdir -p /var/www \
 && apt-get update -y \
 && apt-get install -y wget unzip \
 && wget https://www.prestashop.com/download/latest -O prestashop.zip \
 && unzip -qo prestashop.zip \
 && cp -rT prestashop /var/www \
 && chmod -R a+rw /var/www \
 && rm -rf /var/lib/apt/lists/* \
 && rm -f prestashop.zip

RUN docker-php-ext-enable bcmath mbstring pcntl zip pdo_mysql opcache gd ldap mysqli

VOLUME /var/www
