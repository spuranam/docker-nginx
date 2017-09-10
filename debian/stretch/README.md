# Supported tags and respective `Dockerfile` links

-	[`latest` (*debian/stretch/Dockerfile*)](https://github.com/wilkesystems/docker-nginx/blob/master/debian/stretch/Dockerfile)

# Nginx Extras on Debian Stretch
This nginx image contains almost all nginx nice modules using `nginx-extras` package.

## Get Image
[Docker hub](https://hub.docker.com/r/wilkesystems/nginx-extras)

```bash
docker pull wilkesystems/nginx:stretch
```

## How to use this image

```bash
$ docker run --name some-nginx -d -p 80:80 -p 443:443 wilkesystems/nginx
```

- `-e NGINX_DEFAULT_ROOT=...` Sets the default root directory
- `-e NGINX_GZIP=...` Enables or disables gzipping of responses
- `-e NGINX_GZIP_DISABLE=...` Disables gzipping of responses
- `-e NGINX_GZIP_VARY=...` Enables or disables inserting the Vary Accept-Encoding response
- `-e NGINX_GZIP_PROXIED=...` Enables or disables gzipping of responses for proxied requests
- `-e NGINX_GZIP_COMP_LEVEL=...` Sets a gzip compression level of a response
- `-e NGINX_GZIP_BUFFERS=...` Sets the number and size of buffers used to compress a response
- `-e NGINX_GZIP_HTTP_VERSION=...` Sets the minimum HTTP version
- `-e NGINX_GZIP_TYPES=...` Enables gzipping of responses for the specified MIME types
- `-e NGINX_KEEPALIVE_TIMEOUT=...` Sets a timeout during which a keep-alive client connection
- `-e NGINX_MULTI_ACCEPT=...` Enables or disables multi accept
- `-e NGINX_PID=...` Defines a file that will store the process ID of the main process
- `-e NGINX_UID=...` Sets the User ID of the worker processes
- `-e NGINX_GID=...` Sets the Group ID of the worker processes
- `-e NGINX_SENDFILE=...` Enables or disables the use of sendfile
- `-e NGINX_SERVER_NAME_IN_REDIRECT=...` Enables or disables the use of the primary server name
- `-e NGINX_SERVER_NAMES_HASH_BUCKET_SIZE=...` Sets the bucket size for the server
- `-e NGINX_SERVER_TOKENS=...` Enables or disables emitting nginx version
- `-e NGINX_SSL_PREFER_SERVER_CIPHERS=...` Specifies that server ciphers should be preferred
- `-e NGINX_SSL_PROTOCOLS=...` Enables the specified protocols
- `-e NGINX_TCP_NODELAY=...` Enables or disables the use of the tcp no delay socket option
- `-e NGINX_TCP_NOPUSH=...` Enables or disables the use of the tcp nopush socket option
- `-e NGINX_TYPES_HASH_MAX_SIZE=...` Sets the maximum size of the types hash tables
- `-e NGINX_USER=...` Defines user and group credentials used by worker processes
- `-e NGINX_WORKER_CONNECTIONS=...` Sets the maximum number of simultaneous worker connections
- `-e NGINX_WORKER_PROCESSES=...` Defines the number of worker processes

## Auto Builds
New images are automatically built by each new library/debian push.

## Package: nginx-extras
Package: [nginx-extras](https://packages.debian.org/stretch/nginx-extras)

Nginx ("engine X") is a high-performance web and reverse proxy server created by Igor Sysoev. It can be used both as a standalone web server and as a proxy to reduce the load on back-end HTTP or mail servers.

This package provides a version of nginx with the standard modules, plus extra features and modules such as the Perl module, which allows the addition of Perl in configuration files.

STANDARD HTTP MODULES: Core, Access, Auth Basic, Auto Index, Browser, Empty GIF, FastCGI, Geo, Limit Connections, Limit Requests, Map, Memcached, Proxy, Referer, Rewrite, SCGI, Split Clients, UWSGI.

OPTIONAL HTTP MODULES: Addition, Auth Request, Charset, WebDAV, FLV, GeoIP, Gunzip, Gzip, Gzip Precompression, Headers, HTTP/2, Image Filter, Index, Log, MP4, Embedded Perl, Random Index, Real IP, Slice, Secure Link, SSI, SSL, Stream, Stub Status, Substitution, Thread Pool, Upstream, User ID, XSLT.

MAIL MODULES: Mail Core, Auth HTTP, Proxy, SSL, IMAP, POP3, SMTP.

THIRD PARTY MODULES: Auth PAM, Cache Purge, DAV Ext, Echo, Fancy Index, Headers More, Embedded Lua, HTTP Substitutions, Nchan, Upload Progress, Upstream Fair Queue.
