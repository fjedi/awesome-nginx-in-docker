# @fjedi/docker-awesome-nginx

_The simpliest solution to run fine-tuned web-server with auto-ssl, data-compression and security settings_

![build](https://img.shields.io/docker/cloud/build/fjedi/nginx.svg)
![build](https://img.shields.io/docker/pulls/fjedi/nginx.svg)

### Features

- Custom nginx image based on [OpenResty](https://github.com/openresty/openresty) with `lua` lang support and as a result - the ability to extend default nginx functionality with lots of [lua-based modules](https://www.nginx.com/resources/wiki/modules/lua/)
- `Free ssl` certificates from LetsEncrypt generated on-the-fly (using [lua-resty-auto-ssl](https://github.com/auto-ssl/lua-resty-auto-ssl))
- Reasonable and battle-tested `security and optimization settings` that could optionally be included into your custom virtual-host config
- Better than simple gzip `data compression` with google's [brotli](https://github.com/google/ngx_brotli) module
- `GeoIP` module with MaxMind GeoIP databases and optional white/blacklisting by country
- Graceful `auto-reload` of the nginx process in case of configuration changes
- A set of `configuration snippets` that will help to set up _proxy_ or default _location_ paths

### Usage

Quick start to generate and auto-renew certs for your awesome app:

```Bash
# Type your site's address instead of example.com
export DOMAINS='example1.com|example2.com'

# Then run this command (you will need to have docker installed on your server/pc)
docker run -d \
  --name awesome-nginx \
  --restart unless-stopped \
  --network bridge \
  -e DOMAINS="$DOMAINS" \
  fjedi/nginx
```

Or if you use [docker-compose](https://docs.docker.com/compose/), then your config may look smth like this:

```yaml
# docker-compose.yml
version: "3.0"

services:
  nginx:
    image: fjedi-nginx
    build:
      context: .
    environment:
      DOMAINS: "example1.com|example2.com"
      # NGX_MAX_WORKER_CONNECTIONS: 512
      # NGX_DNS_SERVER: 8.8.8.8
      # NGX_GZIP_COMPRESSION_LEVEL: 5
      # NGX_BROTLI_COMPRESSION_LEVEL: 5
    container_name: "nginx"
    network_mode: bridge
    expose:
      - 80
      - 443
    ports:
      - 80:80
      - 443:443
    restart: unless-stopped
    volumes:
      # don't map particular conf files, supervisor won't restart nginx on change in such files
      # only map directory conf.d with vhosts, in this case everything works fine
      - type: bind
        source: ./conf
        target: /etc/nginx/conf.d
      # we will store here ssl certificates
      - type: bind
        source: /etc/resty-auto-ssl
        target: /etc/resty-auto-ssl
      # remove it if you don't want to persist logs
      - type: bind
        source: /var/log/nginx
        target: /var/log/nginx
```

start using

```Bash
docker compose up -d
```

### Available configuration options

| Variable                     | Example                                | Description                                                                                                                        |
| ---------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| DOMAINS                      | `example.com`, `([a-z]+.)?example.com` | Regex pattern of allowed domains. Internally, we're using [ngx.re.match](https://github.com/openresty/lua-nginx-module#ngxrematch) |
| NGX_DNS_SERVER               | `8.8.8.8`                              | DNS resolver used for OCSP stapling. `8.8.8.8` by default.                                                                         |
| NGX_MAX_BODY_SIZE            | `50M`                                  | Max allowed body size. `50M` by default.                                                                                           |
| NGX_GZIP_COMPRESSION_LEVEL   | `6`                                    | gzip compression level. `6` by default.                                                                                            |
| NGX_BROTLI_COMPRESSION_LEVEL | `6`                                    | gzip compression level. `6` by default.                                                                                            |
| NGX_MAX_WORKER_CONNECTIONS   | `1024`                                 | Determines how many clients will be served by each worker process. `1024` by default.                                              |

## LICENCE

MIT
