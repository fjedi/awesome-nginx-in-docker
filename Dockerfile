FROM ubuntu:bionic
MAINTAINER Alexander Radyushin <alexander@fjedi.com>

ENV NGX_BROTLI_COMMIT="bcceaab88e555f686d5ed39dfb238f898df2788c" \
    NGX_PAGESPEED_VERSION="1.13.35.2" \
    RUNTIME_DEPS="curl bash mc nano sed gcc make openssl iputils-ping net-tools" \
    PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

# Docker Build Arguments
ARG OPENRESTY_VERSION="1.15.8.3"
ARG OPENRESTY_LUAROCKS_VERSION="2.4.4"
ARG OPENRESTY_OPENSSL_VERSION="1.1.1"
ARG OPENRESTY_PCRE_VERSION="8.42"
ARG OPENRESTY_J="2"
ARG OPENRESTY_CONFIG_OPTIONS="\
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
    --add-module=/usr/src/ngx_brotli \
    --add-module=/usr/src/incubator-pagespeed-ngx-${NGX_PAGESPEED_VERSION}-stable \
    "
ARG OPENRESTY_CONFIG_OPTIONS_MORE=""

# These are not intended to be user-specified
ARG _OPENRESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${OPENRESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${OPENRESTY_PCRE_VERSION}"

# 1) Install apt dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y $RUNTIME_DEPS \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        gettext-base \
        libgd-dev \
        libgeoip-dev \
        libncurses5-dev \
        libperl-dev \
        libreadline-dev \
        libxslt1-dev \
        make \
        perl \
        unzip \
        zlib1g-dev \
        git \
        autoconf \
        libtool \
        automake \
        # Required to build ngx_pagespeed module
        uuid-dev \
    # Packages required for graceful nginx-reload on configuration changes
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        inotify-tools \
        supervisor \
    && cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${OPENRESTY_OPENSSL_VERSION}.tar.gz -o openssl-${OPENRESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${OPENRESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${OPENRESTY_PCRE_VERSION}.tar.gz -o pcre-${OPENRESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${OPENRESTY_PCRE_VERSION}.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz -o openresty-${OPENRESTY_VERSION}.tar.gz \
    && tar xzf openresty-${OPENRESTY_VERSION}.tar.gz \
    && cd /usr/local/lib \
    && git clone https://github.com/bagder/libbrotli \
    && cd /usr/local/lib/libbrotli \
    && ./autogen.sh \
    && ./configure \
    && make install \

    # Download Brotli
    && cd /usr/src \
    && echo "Downloading Brotli compression plugin..." \
    && git clone --recursive https://github.com/google/ngx_brotli.git \
    && cd ngx_brotli \
    && git checkout -b $NGX_BROTLI_COMMIT $NGX_BROTLI_COMMIT \

    # Download PageSpeed
    && cd /usr/src \
    && echo "Downloading PageSpeed..." \
    && curl -L https://github.com/pagespeed/ngx_pagespeed/archive/v${NGX_PAGESPEED_VERSION}-stable.tar.gz | tar -zx \
    # psol needs to be inside ngx_pagespeed module
    # Download PageSpeed Optimization Library and extract it to nginx source dir
    && cd /usr/src/incubator-pagespeed-ngx-${NGX_PAGESPEED_VERSION}-stable/ \
    && echo "Downloading PSOL..." \
    && curl -L https://dl.google.com/dl/page-speed/psol/${NGX_PAGESPEED_VERSION}-x64.tar.gz | tar -zx \
    && ls -la /usr/src/incubator-pagespeed-ngx-${NGX_PAGESPEED_VERSION}-stable/ \
    && mkdir -p /tmp/nginx/pagespeed/images/ \

    # Building openresty from sources
    && cd /tmp/openresty-${OPENRESTY_VERSION} \
    && ./configure -j${OPENRESTY_J} ${_OPENRESTY_CONFIG_DEPS} ${OPENRESTY_CONFIG_OPTIONS} ${OPENRESTY_CONFIG_OPTIONS_MORE} \
    && make -j${OPENRESTY_J} \
    && make -j${OPENRESTY_J} install \
    && cd /tmp \
    && rm -rf \
        openssl-${OPENRESTY_OPENSSL_VERSION} \
        openssl-${OPENRESTY_OPENSSL_VERSION}.tar.gz \
        openresty-${OPENRESTY_VERSION}.tar.gz openresty-${OPENRESTY_VERSION} \
        pcre-${OPENRESTY_PCRE_VERSION}.tar.gz pcre-${OPENRESTY_PCRE_VERSION} \
    && curl -fSL https://github.com/luarocks/luarocks/archive/${OPENRESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${OPENRESTY_LUAROCKS_VERSION}.tar.gz \
    && tar xzf luarocks-${OPENRESTY_LUAROCKS_VERSION}.tar.gz \
    && cd luarocks-${OPENRESTY_LUAROCKS_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit \
        --lua-suffix=jit-2.1.0-beta3 \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make build \
    && make install \
    && cd /tmp \
    && rm -rf luarocks-${OPENRESTY_LUAROCKS_VERSION} luarocks-${OPENRESTY_LUAROCKS_VERSION}.tar.gz \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

RUN groupadd nginx \
    && useradd -g nginx nginx \
    && usermod -s /bin/false nginx \
    && echo 'nginx ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

#
RUN luarocks install lua-resty-auto-ssl
RUN mkdir /etc/resty-auto-ssl && chown -cR nginx.nginx /etc/resty-auto-ssl && chmod 777 -cR /etc/resty-auto-ssl
RUN openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
           -subj '/CN=sni-support-required-for-valid-ssl' \
           -keyout /etc/ssl/resty-auto-ssl-fallback.key \
           -out /etc/ssl/resty-auto-ssl-fallback.crt
# Create folders required by pagespeed module
RUN mkdir -p /var/cache/nginx/pagespeed \
    && chown nginx:root /var/cache/nginx/pagespeed \
    && chmod 700 /var/cache/nginx/pagespeed \
    && mkdir /var/log/pagespeed \
    && chown nginx. /var/log/pagespeed

# Map default nginx-conf directory to openresty
RUN mkdir -p /etc/nginx/conf.d/ \
    && chown -cR nginx.nginx /etc/nginx/conf.d/ \
    && chmod 770 -cR /etc/nginx/conf.d/ \
    && ln -s /etc/nginx/conf.d /usr/local/openresty/nginx/conf/

# Remove default nginx.conf
RUN rm /usr/local/openresty/nginx/conf/nginx.conf

# Copy config that includes recommended ssl/security rules
COPY nginx.ssl.default.conf /usr/local/openresty/nginx/conf/nginx.ssl.default.conf

# Copy config with core-settings for pagespeed module
COPY nginx.pagespeed.core.conf /usr/local/openresty/nginx/conf/nginx.pagespeed.core.conf
#
ADD templates /usr/local/openresty/nginx/conf/templates
# Create folder to store nginx logs
RUN mkdir -p /var/log/nginx

#
EXPOSE 80 443
#
VOLUME ["/etc/nginx/conf.d", "/etc/resty-auto-ssl"]

COPY nginx.supervisor.conf /etc/supervisor/conf.d/nginx.conf

#
ADD ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
RUN chmod a+x /usr/local/bin/docker_entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]
