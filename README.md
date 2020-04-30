# @fjedi/docker-awesome-nginx
*The simpliest solution to run fine-tuned web-server with auto-ssl, data-compression and security settings*

![build](https://img.shields.io/docker/cloud/build/fjedi/nginx.svg)
![build](https://img.shields.io/docker/v/fjedi/nginx/latest)
![build](https://img.shields.io/docker/pulls/fjedi/nginx.svg)

### Features
* Custom nginx image based on [OpenResty](https://github.com/openresty/openresty) with `lua` lang support and as a result - the ability to extend default nginx functionality with lots of [lua-based modules](https://www.nginx.com/resources/wiki/modules/lua/)
* `Free ssl` certificates from LetsEncrypt generated on-the-fly (using [lua-resty-auto-ssl](https://github.com/auto-ssl/lua-resty-auto-ssl))
* Reasonable and battle-tested `security and optimization settings` that could optionally be included into your custom virtual-host config
* Better than simple gzip `data compression` with google's [brotli](https://github.com/google/ngx_brotli) module
* `SEO and speed optimization` for your website with google's [pagespeed](https://www.modpagespeed.com/doc/build_ngx_pagespeed_from_source) module
* Graceful `auto-reload` of the nginx process in case of configuration changes
* A set of `configuration snippets` that will help to set up *proxy* or default *location* paths

### Usage

Quick start to generate and auto-renew certs for your awesome app:

```Bash
# Type your site's address instead of example.com
export DOMAINS=example.com

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
version: '2'
services:
  nginx:
    image: fjedi/nginx
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
    volumes:
      - nginx_conf:/etc/nginx/conf.d
    environment:
      # Don't forget to change this to your domain
      DOMAINS: 'example.com'
  
  # your application
  app:
    image: nginx
    ...other options for your app's container

volumes:
  nginx_conf:
```

start using
```Bash
docker-compose up -d
```

### Available configuration options

 | Variable | Example | Description
 | --- | --- | ---|
 | DOMAINS | `example.com`, `([a-z]+.)?example.com` | Regex pattern of allowed domains. Internally, we're using [ngx.re.match](https://github.com/openresty/lua-nginx-module#ngxrematch) |
 | NGX_DNS_SERVER | `8.8.8.8` | DNS resolver used for OCSP stapling. `8.8.8.8` by default. |
 | NGX_MAX_BODY_SIZE | `50M` | Max allowed body size. `50M` by default. |
 | NGX_PAGESPEED_MODULE_STATUS | `on`, `off` | Enable/Disable pagespeed module. `off` by default. |
 | NGX_GZIP_COMPRESSION_LEVEL | `6` | gzip compression level. `6` by default. |
 | NGX_BROTLI_COMPRESSION_LEVEL | `6` | gzip compression level. `6` by default. |
 | NGX_MAX_WORKER_CONNECTIONS | `1024` | Determines how many clients will be served by each worker process. `1024` by default. |
 

## LICENCE

MIT
