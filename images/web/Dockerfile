FROM ruby:3.4-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    workdir=/var/www \
    BUNDLE_PATH=/usr/local/bundle \
    GEM_HOME=/usr/local/bundle \
    GEM_PATH=/usr/local/bundle \
    PATH="/usr/local/bundle/bin:$PATH" \
    RAILS_ENV=production

WORKDIR $workdir

# Install base build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git curl gnupg build-essential \
    libarchive-dev zlib1g-dev libcurl4-openssl-dev libgd-dev libvips-dev \
    apache2 apache2-dev libapache2-mod-fcgid libapr1-dev libaprutil1-dev \
    postgresql-client libpq-dev libxml2-dev libyaml-dev \
    pngcrush optipng advancecomp pngquant jhead jpegoptim gifsicle libjpeg-progs unzip\
    && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn svgo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


# Clone OSM Website
ENV OPENSTREETMAP_WEBSITE_GITSHA=9da20921c0a257d4d7ddd52de36bd3b75f3c8372
ENV OSM_WEBSITE_URL=https://github.com/openstreetmap/openstreetmap-website/archive/${OPENSTREETMAP_WEBSITE_GITSHA}.zip
RUN rm -rf $workdir/* && curl -fsSL $OSM_WEBSITE_URL -o /tmp/openstreetmap-website.zip && \
    unzip /tmp/openstreetmap-website.zip -d /tmp && \
    mv /tmp/openstreetmap-website-$OPENSTREETMAP_WEBSITE_GITSHA/* $workdir && \
    rm -rf /tmp/*

RUN gem install bundler -v 4.0.20 --no-document && \
    bundle install && \
    yarn install && \
    bundle exec rake yarn:install

# Dummy config for precompile
RUN cp config/example.database.yml config/database.yml && \
    cp config/example.storage.yml config/storage.yml && \
    touch config/settings.local.yml && \
    chmod 600 config/database.yml

# Create dummy credentials
RUN rm -f config/credentials.yml.enc && \
    export RAILS_MASTER_KEY=$(openssl rand -hex 16) && \
    export SECRET_KEY_BASE=$(bundle exec rails secret) && \
    echo $RAILS_MASTER_KEY > config/master.key && \
    EDITOR="echo" RAILS_MASTER_KEY=$RAILS_MASTER_KEY bundle exec rails credentials:edit && \
    RAILS_MASTER_KEY=$RAILS_MASTER_KEY bundle exec rails runner "\
    require 'active_support/encrypted_configuration'; \
    require 'yaml'; \
    creds = ActiveSupport::EncryptedConfiguration.new(\
        config_path: 'config/credentials.yml.enc', \
        key_path: 'config/master.key', \
        env_key: 'RAILS_MASTER_KEY', \
        raise_if_missing_key: true \
    ); \
    credentials = { secret_key_base: '$SECRET_KEY_BASE' }; \
    creds.write(credentials.to_yaml); \
    puts 'Credentials configured correctly.'"

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1  \
    bundle exec i18n export && \
    bundle exec rails assets:precompile

# Apply patches for OSM
COPY patches/ /$workdir/
RUN patch /$workdir/config/initializers/doorkeeper.rb /$workdir/config/initializers/doorkeeper.rb.patch


FROM ruby:3.4-slim

ENV DEBIAN_FRONTEND=noninteractive \
    workdir=/var/www \
    BUNDLE_PATH=/usr/local/bundle \
    GEM_HOME=/usr/local/bundle \
    GEM_PATH=/usr/local/bundle \
    PATH="/usr/local/bundle/bin:$PATH" \
    RAILS_ENV=production \
    PATH="$PATH:$GEM_HOME/bin"

# Install base dependencies for Passenger gem compilation and runtime
RUN BUILD_DEPS=" \
    build-essential \
    apache2-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    npm \
    " \
    && apt-get update && apt-get install -y --no-install-recommends \
    $BUILD_DEPS \
    apache2 \
    libapache2-mod-fcgid \
    libpq5 \
    libxml2 \
    libyaml-0-2 \
    libarchive13 \
    file \
    pngcrush \
    optipng \
    advancecomp \
    pngquant \
    jhead \
    jpegoptim \
    gifsicle \
    postgresql-client \
    curl \
    libvips \
    nodejs \
    \
    && npm install -g svgo \
    \
    # Install Passenger as a gem and compile the Apache module
    \
    && gem install passenger -v 6.1.3 --no-document \
    && yes | passenger-install-apache2-module --auto --languages ruby \
    && passenger-config validate-install --auto \
    \
    # Delete the build dependencies to reduce image size
    \
    && apt-get purge -y --auto-remove $BUILD_DEPS \
    \
    # libgd-dev is requiered by the app on run time to process gps files
    \
    && apt-get update && apt-get install -y --no-install-recommends libgd3 libgd-dev \
    \
    # Final cleanup
    \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


# Apache configuration
COPY config/production.conf /etc/apache2/sites-available/production.conf

RUN passenger-install-apache2-module --snippet > /etc/apache2/mods-available/passenger.load && \
    passenger-config build-native-support

RUN a2enmod headers setenvif proxy proxy_http proxy_fcgi fcgid rewrite lbmethod_byrequests passenger && \
    a2dissite 000-default && \
    a2ensite production && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    apache2ctl configtest

RUN echo '#!/bin/bash\nexec /usr/local/bin/ruby --yjit --yjit-exec-mem-size=64 "$@"' > /usr/local/bin/ruby_yjit && \
    chmod +x /usr/local/bin/ruby_yjit
    
WORKDIR $workdir

COPY --chown=www-data:www-data --from=builder /var/www /$workdir
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Install bundler matching the Gemfile.lock to avoid Passenger preloader Gem::LoadError
RUN gem install bundler -v 4.0.20 --no-document

COPY config/settings.yml $workdir/config/
COPY start.sh liveness.sh $workdir/

RUN ln -s /tmp /var/www/tmp

RUN mkdir -p /var/www/log && \
    touch /var/www/log/production.log && \
    chown -R www-data:www-data /var/www/log /var/www/public && \
    chown -R www-data:www-data /var/www

CMD ["./start.sh"]
