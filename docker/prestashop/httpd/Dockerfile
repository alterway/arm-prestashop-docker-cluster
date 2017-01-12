FROM alterway/httpd:2.4

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
VOLUME /var/www