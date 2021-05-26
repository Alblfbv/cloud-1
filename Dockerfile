FROM php:7.4-fpm

COPY ./app                              /code

COPY ./docker-conf/mail.ini             /usr/local/etc/php/conf.d/mail.ini
COPY ./docker-conf/msmtprc              /etc/msmtprc

RUN apt upgrade && apt update && apt install -y libpng-dev
RUN DEBIAN_FRONTEND=noninteractive apt install -y msmtp msmtp-mta zip vim

RUN docker-php-ext-install pdo pdo_mysql gd

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

RUN pecl install xdebug 
RUN docker-php-ext-enable xdebug

WORKDIR /code

COPY ./docker-conf/php-entrypoint.sh    /usr/local/bin
RUN chmod 777 /usr/local/bin/php-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/php-entrypoint.sh"]