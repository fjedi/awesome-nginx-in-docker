#!/bin/bash
set -euo pipefail

NGINX_DIR=/usr/local/openresty/nginx
NGINX_CONF=${NGINX_DIR}/conf/nginx.conf

# If config doesn't exist, initialize with sane defaults

if [ ! -e "${NGINX_CONF}" ]; then
tee -a >${NGINX_CONF} <<EOF
# Load nginx/openresty lua modules
load_module "modules/ngx_http_geoip_module.so";

user nginx;
# This number should be, at maximum, the number of CPU cores on your system.
worker_processes auto;
# Number of file descriptors used for Nginx.
worker_rlimit_nofile 65535;

events {
  # Accept as many connections as possible, after nginx gets notification about a new connection.
  multi_accept on;

  # Determines how many clients will be served by each worker process.
  worker_connections ${NGX_MAX_WORKER_CONNECTIONS:-1024};

  # The effective method, used on Linux 2.6+, optmized to serve many clients with each thread.
  use epoll;
}

http {
  charset utf-8;
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  log_not_found off;
  types_hash_max_size 2048;
  #
  server_tokens off;
  # Clear the Server output header
  more_clear_headers 'Server';

  #
  include mime.types;
	default_type application/octet-stream;

  # The "auto_ssl" shared dict should be defined with enough storage space to
  # hold your certificate data. 1MB of storage holds certificates for
  # approximately 100 separate domains.
  lua_shared_dict auto_ssl 10m;
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
  resolver ${NGX_DNS_SERVER:-8.8.8.8};
  resolver_timeout 3s;

  #
  client_max_body_size ${NGX_MAX_BODY_SIZE:-50M};

  # PageSpeed module
  pagespeed ${NGX_PAGESPEED_MODULE_STATUS:-off};
  include nginx.pagespeed.core.conf;
  # Set the value of the `X-Page-Speed` response header
  # https://modpagespeed.com/doc/configuration#XHeaderValue
  pagespeed XHeaderValue "pagespeed";

  # set REMOTE_ADDR from any internal proxies
  # see http://nginx.org/en/docs/http/ngx_http_realip_module.html
  set_real_ip_from 127.0.0.1;
  set_real_ip_from 10.0.0.0/8;
  set_real_ip_from 192.168.0.0/16;
  set_real_ip_from 172.16.0.0/12;
  real_ip_recursive on;
  #
  real_ip_header X-Forwarded-For;
  # Uncomment this line if you want to get client's real ip
  # and your server is behind CloudFlare reverse-proxy
  # include presets/geoip_cloudflare.conf;

  # GeoIP databases
  geoip_country /usr/local/openresty/nginx/data/geoip/countries.dat;
  geoip_city /usr/local/openresty/nginx/data/geoip/cities.dat;

  ##
  # Gzip Settings
  ##
  gzip on;
  gzip_http_version 1.0;
  gzip_comp_level ${NGX_GZIP_COMPRESSION_LEVEL:-6};
  gzip_proxied any;
  gzip_types text/plain text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript application/json;
  #
  brotli on;
  brotli_static on;
  brotli_types text/plain text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript application/json;
  # Sets on-the-fly compression Brotli quality (compression) level. Acceptable values are in the range from 0 to 11.
  brotli_comp_level ${NGX_BROTLI_COMPRESSION_LEVEL:-6};

  # Initial setup tasks.
  init_by_lua_block {
    auto_ssl = (require "resty.auto-ssl").new()

    -- Define a function to determine which SNI domains to automatically handle
    -- and register new certificates for. Defaults to not allowing any domains,
    -- so this must be configured.
    auto_ssl:set("allow_domain", function(domain)
      return ngx.re.match(domain, "^(${DOMAINS})$", "ijo")
    end)

    -- Comment this line if you start this server in production environment
    auto_ssl:set("ca", "https://acme-staging-v02.api.letsencrypt.org/directory")

    auto_ssl:init()
  }

  init_worker_by_lua_block {
    auto_ssl:init_worker()
  }

  #  HTTPS server
  #  !YOU NEED TO SET YOUR CUSTOM HTTPS-SERVER CONFIGURATION!
  #  server {
  #    listen 443 ssl;
  #
  #    # This include will add recommended ssl/security settings
  #    include nginx.ssl.default.conf;
  #  }

  # HTTP server
  server {
    listen 80;

    #
    include presets/error_pages.conf;

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
  exec /usr/bin/supervisord;
else
  exec "$@"
fi
