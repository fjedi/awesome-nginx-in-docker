#!/bin/bash
set -euo pipefail

NGINX_DIR=/usr/local/openresty/nginx
NGINX_CONF=${NGINX_DIR}/conf/nginx.conf

# If config doesn't exist, initialize with sane defaults

if [ ! -e "${NGINX_CONF}" ]; then
tee -a >${NGINX_CONF} <<EOF
events {
  worker_connections 1024;
}

http {
  # The "auto_ssl" shared dict should be defined with enough storage space to
  # hold your certificate data. 1MB of storage holds certificates for
  # approximately 100 separate domains.
  lua_shared_dict auto_ssl 1m;
  # The "auto_ssl_settings" shared dict is used to temporarily store various settings
  # like the secret used by the hook server on port 8999. Do not change or
  # omit it.
  lua_shared_dict auto_ssl_settings 64k;

  # A DNS resolver must be defined for OCSP stapling to function.
  #
  # This example uses Google's DNS server. You may want to use your system's
  # default DNS servers, which can be found in /etc/resolv.conf. If your network
  # is not IPv6 compatible, you may wish to disable IPv6 results by using the
  # "ipv6=off" flag (like "resolver 8.8.8.8 ipv6=off").
  resolver 8.8.8.8;

  #
  server_tokens off;
  client_max_body_size 50M;

  # set REMOTE_ADDR from any internal proxies
  # see http://nginx.org/en/docs/http/ngx_http_realip_module.html
  set_real_ip_from 127.0.0.1;
  set_real_ip_from 10.0.0.0/8;
  set_real_ip_from 172.0.0.0/16;
  real_ip_header X-Forwarded-For;
  real_ip_recursive on;

  ##
  # Gzip Settings
  ##
  gzip on;
  gzip_http_version 1.0;
  gzip_comp_level 2;
  gzip_proxied any;
  gzip_types text/plain text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript application/json;
  #
  brotli on;
  brotli_static on;
  brotli_types text/plain text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript application/json;
  # Sets on-the-fly compression Brotli quality (compression) level. Acceptable values are in the range from 0 to 11.
  brotli_comp_level 6;

  # Initial setup tasks.
  init_by_lua_block {
    auto_ssl = (require "resty.auto-ssl").new()

    -- Define a function to determine which SNI domains to automatically handle
    -- and register new certificates for. Defaults to not allowing any domains,
    -- so this must be configured.
    auto_ssl:set("allow_domain", function(domain)
      return ngx.re.match(domain, "^(${DOMAINS})$", "ijo")
    end)

    auto_ssl:init()
  }

  init_worker_by_lua_block {
    auto_ssl:init_worker()
  }

  # HTTPS server
  # !YOU NEED TO SET YOU CUSTOM HTTPS-SERVER CONFIGURATION!
  #  server {
  #    listen 443 ssl;
  #
  #    # Dynamic handler for issuing or returning certs for SNI domains.
  #    ssl_certificate_by_lua_block {
  #      auto_ssl:ssl_certificate()
  #    }
  #
  #    # You must still define a static ssl_certificate file for nginx to start.
  #    #
  #    # You may generate a self-signed fallback with:
  #    #
  #    # openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  #    #   -subj '/CN=sni-support-required-for-valid-ssl' \
  #    #   -keyout /etc/ssl/resty-auto-ssl-fallback.key \
  #    #   -out /etc/ssl/resty-auto-ssl-fallback.crt
  #    ssl_certificate /etc/ssl/resty-auto-ssl-fallback.crt;
  #    ssl_certificate_key /etc/ssl/resty-auto-ssl-fallback.key;
  #  }

  # HTTP server
  server {
    listen 80;

    # Endpoint used for performing domain verification with Let's Encrypt.
    location /.well-known/acme-challenge/ {
      content_by_lua_block {
        auto_ssl:challenge_server()
      }
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
  }

  # Internal server running on port 8999 for handling certificate tasks.
  server {
    listen 127.0.0.1:8999;

    # Increase the body buffer size, to ensure the internal POSTs can always
    # parse the full POST contents into memory.
    client_body_buffer_size 128k;
    client_max_body_size 128k;

    location / {
      content_by_lua_block {
        auto_ssl:hook_server()
      }
    }
  }

  map \$http_upgrade \$connection_upgrade {
      default upgrade;
      ''      close;
  }

  include /etc/nginx/conf.d/*.conf;
}
EOF
fi

if [ $# -eq 0 ]; then
  exec /usr/local/openresty/bin/openresty -c $NGINX_CONF -g "daemon off;";
else
  exec "$@"
fi
