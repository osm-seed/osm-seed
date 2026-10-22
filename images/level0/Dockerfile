FROM php:8.3.36-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip sqlite3 \
    && docker-php-ext-install gettext \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

ENV LEVEL0_GITSHA=3346f1b60e32a4d0913bd03342c56b43b1e9bf75

RUN git clone https://github.com/Zverik/Level0.git /var/www/level0 \
    && cd /var/www/level0 \
    && git checkout ${LEVEL0_GITSHA} \
    && composer install --no-dev --no-interaction --no-progress

RUN sed -i 's|/var/www/html|/var/www/level0/www|g' \
        /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

COPY oauth_provider.php /var/www/level0/www/oauth_provider.php

RUN mkdir -p /var/www/level0/www/data \
    && chown -R www-data:www-data /var/www/level0

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 80
CMD ["start.sh"]
