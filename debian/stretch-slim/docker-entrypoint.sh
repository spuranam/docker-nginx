#!/bin/bash

function main {
    if [ "$1" != "nginx" ]; then
        args=$(getopt -n "$(basename $0)" -o h --long help,debug,version -- "$@")
        eval set --"$args"
        while true; do
            case "$1" in
                -h | --help ) print_usage; shift ;;
                --debug ) DEBUG=true; shift ;;
                --version ) print_version; shift ;;
                --) shift ; break ;;
                * ) break ;;
            esac
        done
        shift $((OPTIND-1))
        nginx_config
	for arg; do
            if [ ! -f /etc/nginx/sites-available/$arg ]; then
                vhost_config "$arg"
		ln -sf /etc/nginx/sites-available/$arg /etc/nginx/sites-enabled/$arg
            fi
            if [ ! -d /var/www/$arg ]; then
                mkdir -m 755 -p /var/www/$arg/{cgi-bin,htdocs,logs,tmp}
		cp -pr /usr/share/nginx/html/* /var/www/$arg/htdocs/
                chown -R www-data:www-data /var/www/$arg/{cgi-bin,htdocs,tmp} 
            fi
        done
        exec nginx -g 'daemon off;'
    else
        nginx_config
        exec "$@"
    fi
}

function print_usage {
cat << EOF
Usage: "$(basename $0)" [Options]... [Vhosts]...

  -h  --help     display this help and exit

      --debug    output debug information
      --version  output version information and exit

E-mail bug reports to: <developer@wilke.systems>.
EOF
exit
}

function print_version {
cat << EOF

MIT License

Copyright (c) 2017 Wilke.Systems

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF
exit
}

function vhost_config {
cat << EOF > /etc/nginx/conf.d/upstream.conf
upstream fcgiwrap {
	server unix:/run/fcgiwrap/fcgiwrap.socket;
}
upstream php5 {
	server unix:/run/php5/php5-fpm.sock;
}
upstream php7 {
	server unix:/run/php7/php7.0-fpm.sock;
}
EOF
cat << EOF > /etc/nginx/snippets/letsencrypt-acme-challenge.conf
location ^~ /.well-known/acme-challenge/ {
	default_type "text/plain";
	root /var/www/default;
}
location = /.well-known/acme-challenge/ {
	return 404;
}
EOF
cat << EOF > /etc/nginx/sites-available/$1
server {
	listen 80;
	listen [::]:80;

	server_name $1 *.$1;

	root /var/www/$1/htdocs;
	index default.html index.php index.php5 index.php7 index.html index.htm;

	location / {
		try_files \$uri \$uri/ =404;
	}

	location /cgi-bin {
		root /var/www/$1;
		index index.html index.htm index.cgi index.pl index.sh;
	 	location ~ \.(cgi|pl|sh)$ {
			gzip off;
			include /etc/nginx/fastcgi.conf;
			fastcgi_pass fcgiwrap;
	 	}
	}

	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
 		fastcgi_pass php7;
	}

	location ~ \.php5$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass php5;
	}

	location ~ \.php7$ {
		include snippets/fastcgi-php.conf;
 		fastcgi_pass php7;
	}

	include /etc/nginx/snippets/letsencrypt-acme-challenge.conf;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;
}
EOF
if [ -f /etc/letsencrypt/live/$1/cert.pem ]; then
cat << EOF > /etc/nginx/sites-available/$1
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	server_name www.$1;

	root /var/www/$1/htdocs;
	index default.html index.php index.php5 index.php7 index.html index.htm;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

	location / {
		try_files \$uri \$uri/ =404;
	}

	location /cgi-bin {
		root /var/www/$1;
		index index.html index.htm index.cgi index.pl index.sh;
		location ~ \.(cgi|pl|sh)$ {
			gzip off;
			include /etc/nginx/fastcgi.conf;
			fastcgi_pass fcgiwrap;
		}
	}

	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass php7;
	}

	location ~ \.php5$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass php5;
	}

	location ~ \.php7$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass php7;
	}

	include /etc/nginx/snippets/letsencrypt-acme-challenge.conf;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;
}

server {
	listen 80;
	listen [::]:80;

	server_name $1 *.$1;

	root /var/www/default;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	include snippets/letsencrypt-acme-challenge.conf;

	return 301 https://www.$1\$request_uri;
}

server {
	listen 443;
	listen [::]:443;

	server_name $1 *.$1;

	root /var/www/default;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	include snippets/letsencrypt-acme-challenge.conf;

	return 301 https://www.$1\$request_uri;
}
EOF
fi
if [ -f /etc/letsencrypt/live/$1/cert.pem -a -f /var/www/$1/htdocs/wp-config.php -a -d /var/www/$1/htdocs/wp-admin ]; then
cat << EOF > /etc/nginx/sites-available/$1
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	server_name www.$1;

	root /var/www/$1/htdocs;

	index index.php;

        ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

        include /etc/nginx/snippets/letsencrypt-acme-challenge.conf;

        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }

        location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
        }

        location / {
                try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_intercept_errors on;
                fastcgi_pass php7;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
                expires max;
                log_not_found off;
        }

	location ~ ([^/]*)sitemap(.*).x(m|s)l$ {
		rewrite ^/sitemap.xml$ /sitemap_index.xml permanent;
		rewrite ^/([a-z]+)?-?sitemap.xsl$ /index.php?xsl=\$1 last;
		rewrite ^/sitemap_index.xml$ /index.php?sitemap=1 last;
		rewrite ^/([^/]+?)-sitemap([0-9]+)?.xml$ /index.php?sitemap=\$1&sitemap_n=\$2 last;
		rewrite ^/news-sitemap.xml$ /index.php?sitemap=wpseo_news last;
		rewrite ^/locations.kml$ /index.php?sitemap=wpseo_local_kml last;
		rewrite ^/geo-sitemap.xml$ /index.php?sitemap=wpseo_local last;
		rewrite ^/video-sitemap.xsl$ /index.php?xsl=video last;
	}

        access_log /var/www/$1/logs/access.log;
        error_log /var/www/$1/logs/error.log warn;
}

server {
	listen 80;
	listen [::]:80;

	server_name $1 *.$1;

	root /var/www/default;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	include snippets/letsencrypt-acme-challenge.conf;

	return 301 https://www.$1\$request_uri;
}

server {
	listen 443;
	listen [::]:443;

	server_name $1 *.$1;

	root /var/www/default;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	include snippets/letsencrypt-acme-challenge.conf;

	return 301 https://www.$1\$request_uri;
}
EOF
fi
}

function nginx_config {
    [ "$DEBUG" = "true" ] && set -x

    if [ ! -z "$NGINX_DEFAULT_ROOT" -a "$NGINX_DEFAULT_ROOT" != "/var/www/html" ]; then
        if [ -f /etc/nginx/sites-available/default ]; then
            sed -i -e "s/root \(.*\);/root ${NGINX_DEFAULT_ROOT////\\/};/" /etc/nginx/sites-available/default
            mkdir -m 755 -p $NGINX_DEFAULT_ROOT
            if [ -f /usr/share/nginx/html/index.html ]; then
                if [ ! -f $NGINX_DEFAULT_ROOT/index.nginx-debian.html -a ! -f $NGINX_DEFAULT_ROOT/index.html ]; then
                    cp -p /usr/share/nginx/html/index.html "$NGINX_DEFAULT_ROOT/index.nginx-debian.html"
                fi
            fi
        fi
        if [ -d /var/www/html ]; then
            rm -rf /var/www/html
        fi
    fi

    if [ ! -z "$NGINX_GZIP" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip \(.*\);/gzip \1;/" -e "s/gzip \(.*\);/gzip ${NGINX_GZIP,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_DISABLE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_disable \(.*\);/gzip_disable \1;/" -e "s/gzip_disable \(.*\);/gzip_disable ${NGINX_GZIP_DISABLE,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_VARY" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_vary \(.*\);/gzip_vary \1;/" -e "s/gzip_vary \(.*\);/gzip_vary ${NGINX_GZIP_VARY,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_PROXIED" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_proxied \(.*\);/gzip_proxied \1;/" -e "s/gzip_proxied \(.*\);/gzip_proxied ${NGINX_GZIP_PROXIED,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_COMP_LEVEL" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_comp_level \(.*\);/gzip_comp_level \1;/" -e "s/gzip_comp_level \(.*\);/gzip_comp_level ${NGINX_GZIP_COMP_LEVEL,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_BUFFERS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_buffers \(.*\);/gzip_buffers \1;/" -e "s/gzip_buffers \(.*\);/gzip_buffers ${NGINX_GZIP_BUFFERS,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_HTTP_VERSION" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_http_version \(.*\);/gzip_http_version \1;/" -e "s/gzip_http_version \(.*\);/gzip_http_version ${NGINX_GZIP_HTTP_VERSION,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_TYPES" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_types \(.*\);/gzip_types \1;/" -e "s/gzip_types \(.*\);/gzip_types ${NGINX_GZIP_TYPES////\\/};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_KEEPALIVE_TIMEOUT" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# keepalive_timeout \(.*\);/keepalive_timeout \1;/" -e "s/keepalive_timeout \(.*\);/keepalive_timeout $NGINX_KEEPALIVE_TIMEOUT;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_MULTI_ACCEPT" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# multi_accept \(.*\);/multi_accept \1;/" -e "s/multi_accept \(.*\);/multi_accept ${NGINX_MULTI_ACCEPT,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_PID" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# pid \(.*\);/pid \1;/" -e "s/pid \(.*\);/pid ${NGINX_PID////\\/};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GID" -a -z "${NGINX_GID//[0-9]/}" ]; then
        groupmod -g $NGINX_GID www-data
    fi

    if [ ! -z "$NGINX_UID" -a -z "${NGINX_UID//[0-9]/}" ]; then
        usermod -u $NGINX_UID www-data
    fi

    if [ ! -z "$NGINX_SENDFILE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# sendfile \(.*\);/sendfile \1;/" -e "s/sendfile \(.*\);/sendfile ${NGINX_SENDFILE,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SERVER" ]; then
        echo "more_set_headers 'Server: $NGINX_SERVER';" > /etc/nginx/conf.d/more_set_headers.conf
    fi

    if [ ! -z "$NGINX_SERVER_NAME_IN_REDIRECT" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# server_name_in_redirect \(.*\);/server_name_in_redirect \1;/" -e "s/server_name_in_redirect \(.*\);/server_name_in_redirect ${NGINX_SERVER_NAME_IN_REDIRECT,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SERVER_NAMES_HASH_BUCKET_SIZE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# server_names_hash_bucket_size \(.*\);/server_names_hash_bucket_size \1;/" -e "s/server_names_hash_bucket_size \(.*\);/server_names_hash_bucket_size $NGINX_SERVER_NAMES_HASH_BUCKET_SIZE;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SERVER_TOKENS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# server_tokens \(.*\);/server_tokens \1;/" -e "s/server_tokens \(.*\);/server_tokens ${NGINX_SERVER_TOKENS,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SSL_PREFER_SERVER_CIPHERS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;/" -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers ${NGINX_SSL_PREFER_SERVER_CIPHERS,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SSL_PROTOCOLS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# ssl_protocols \(.*\);/ssl_protocols \1;/" -e "s/ssl_protocols \(.*\);/ssl_protocols $NGINX_SSL_PROTOCOLS;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_TCP_NODELAY" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# tcp_nodelay \(.*\);/tcp_nodelay \1;/" -e "s/tcp_nodelay \(.*\);/tcp_nodelay ${NGINX_TCP_NODELAY,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_TCP_NOPUSH" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# tcp_nopush \(.*\);/tcp_nopush \1;/" -e "s/tcp_nopush \(.*\);/tcp_nopush ${NGINX_TCP_NOPUSH,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_TYPES_HASH_MAX_SIZE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# types_hash_max_size \(.*\);/types_hash_max_size \1;/" -e "s/types_hash_max_size \(.*\);/types_hash_max_size $NGINX_TYPES_HASH_MAX_SIZE;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_USER" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# user \(.*\);/user \1;/" -e "s/user \(.*\);/user ${NGINX_USER,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_WORKER_CONNECTIONS" ]; then
        if [ ! -z "${NGINX_WORKER_CONNECTIONS//[0-9]/}" ]; then
            NGINX_WORKER_CONNECTIONS=$((65535/$(grep processor /proc/cpuinfo | wc -l)))
        fi
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# worker_connections \(.*\);/worker_connections \1;/" -e "s/worker_connections \(.*\);/worker_connections $NGINX_WORKER_CONNECTIONS;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_WORKER_PROCESSES" ]; then
        if [ ! -z "${NGINX_WORKER_PROCESSES//[0-9]/}" ]; then
            WORKER_PROCESSES=auto
        fi
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# worker_processes \(.*\);/worker_processes \1;/" -e "s/worker_processes \(.*\);/worker_processes $NGINX_WORKER_PROCESSES;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ -f /etc/nginx/sites-available/default ]; then
        sed -i -e "s/# listen 443 ssl default_server;/listen 443 ssl default_server http2;/" /etc/nginx/sites-available/default;
        sed -i -e "s/# listen \[::\]:443 ssl default_server;/listen [::]:443 ssl default_server http2;/" /etc/nginx/sites-available/default
        sed -i -e "s/# include snippets\/snakeoil.conf;/include snippets\/snakeoil.conf;/" /etc/nginx/sites-available/default
    fi

    if [ -d /etc/docker-entrypoint.d ]; then
        for NGINX_PACKAGE in /etc/docker-entrypoint.d/*.tar.gz; do
            tar xfz $NGINX_PACKAGE -C /
        done
    fi
}

main "$@"
