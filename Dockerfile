FROM robertcsmith/base1.0-alpine:3.8base-docker

LABEL robertcsmith.openresty.namespace="robertcsmith/" \
    robertcsmith.openresty.name="openresty" \
    robertcsmith.openresty.release="1.13.6.2" \
    robertcsmith.openresty.flavor="-alpine3.8" \
    robertcsmith.openresty.version="-docker" \
    robertcsmith.openresty.tag=":1.0, :latest" \
    robertcsmith.openresty.image="robertcsmith/openresty1.13.6.2-alpine3.8-docker" \
    robertcsmith.openresty.vcs-url="https://github.com/robertcsmith/openresty1.13.6.2-alpine3.8-docker" \
    robertcsmith.openresty.maintainer="Robert C Smith <robertchristophersmith@gmail.com>" \
    robertcsmith.openresty.usage="README.md" \
    robertcsmith.openresty.description="\
For this project, the following volumes, bind mount directories and source code directories set in Compose should have been created by the installer/utility after git installs the file structure then installs each subtree based on individual repos and assigns correct permissions for use by both the web server container (openresty) and application container (php-fpm) \
  Named Volumes:\
    - phpmyadmin-openresty-socket:/var/run/php/phpmyadmin \
    - wufgear-openresty-socket:/var/run/php/wufgear \
  Bind-mounts:\
    - /app/binds/openresty/usr-local-etc-php-fpm.d:/usr/local/etc/php-fpm.d \
  Source code: (where the application code resides and should be changed into named volumes for production:\
    - /app/src/phpmyadmin:/var/www/phpmyadmin \
    - /app/src/wufgear:/var/www/wufgear \
The production deployment of this container should not use bind mounts (currently used for ease of access) and should be converted to named volumes unless it is the only way to safely deploy the app."

# Docker Build Arguments
ARG RESTY_VERSION="1.13.6.2"
ARG RESTY_OPENSSL_VERSION="1.0.2p"
ARG RESTY_PCRE_VERSION="8.42"
ARG RESTY_J="1"
ARG RESTY_CONFIG_OPTIONS="\
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"

# Set system GIDs (make sure they are the same on each PHP Dockerfile and assign to the "app" user
RUN set -ex; \
    addgroup -S -g 82 www-data && addgroup -S -g 101 nginx; \
    addgroup app www-data && addgroup app nginx;

RUN set -xe; \
    # Update apk's indexes
    apk update && apk upgrade; \
    # Install apk dependencies
    apk add --no-cache --virtual .build-base \
        curl \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        readline-dev \
    && apk add --no-cache \
        gd \
        geoip \
        libxslt; \
    cd /tmp; \
    # Download and untar OpenSSL
    curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz; \
    # Download and untar PCRE
    curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz; \
    # Download, untar and make/build OpenResty
    curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} && make -j${RESTY_J} install; \
    # Symlink access and error log locations
    ln -sf /dev/stdout /usr/local/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/nginx/logs/error.log; \
    # Cleanup
    cd /tmp && rm -rf openssl-${RESTY_OPENSSL_VERSION}.tar.gz openssl-${RESTY_OPENSSL_VERSION} \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION}; \
    apk del .build-deps && rm -rf /var/cache/apk/* 2>/dev/null; \

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/nginx/luajit/bin:/usr/local/nginx/sbin:/usr/local/openresty/bin

# Copy nginx configuration files
COPY --chown=app:nginx files/nginx.conf /usr/local/nginx/conf/nginx.conf
COPY --chown=app:nginx files/fastcgi-params /etc/nginx/fastcgi-params
COPY --chown=app:nginx files/mime.types /etc/nginx/mime.types

# Create additional directories used for FPM users
RUN set -xe; \
    mkdir -p /etc/nginx/conf.d /var/run/nginx /var/run/php/wufgear && touch /var/run/nginx/openresty.pid; \
    chown -rf app:nginx /var/run/nginx /etc/nginx/*; \
    chmod -rf 0660 /var/run/nginx /etc/nginx/* && chmod -rf 0777 /etc/nginx/conf.d;

EXPOSE 80 443

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
