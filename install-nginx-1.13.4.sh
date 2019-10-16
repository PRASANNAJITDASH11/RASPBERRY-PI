#!/usr/bin/env bash
 
# names of latest versions of each package
export NGINX_VERSION=1.13.4
export VERSION_PCRE=pcre-8.41
export VERSION_LIBRESSL=libressl-2.6.0
export VERSION_ZLIB=zlib-1.2.11
export VERSION_NGINX=nginx-$NGINX_VERSION
 
# URLs to the source directories
export SOURCE_LIBRESSL=http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/
export SOURCE_PCRE=ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
export SOURCE_ZLIB=http://zlib.net/
export SOURCE_NGINX=http://nginx.org/download/
export SOURCE_RTMP=https://github.com/arut/nginx-rtmp-module.git
 
# clean out any files from previous runs of this script
rm -rf build
mkdir build

# proc for building faster
NB_PROC=$(grep -c ^processor /proc/cpuinfo)
 
# ensure that we have the required software to compile our own nginx
sudo apt-get -y install curl wget build-essential libgd2-xpm libgd2-xpm-dev libgeoip-dev checkinstall git
 
# grab the source files
echo "Download sources"
wget -P ./build $SOURCE_PCRE$VERSION_PCRE.tar.gz
wget -P ./build $SOURCE_LIBRESSL$VERSION_LIBRESSL.tar.gz
wget -P ./build $SOURCE_NGINX$VERSION_NGINX.tar.gz
wget -P ./build $SOURCE_ZLIB$VERSION_ZLIB.tar.gz
git clone $SOURCE_RTMP ./build/rtmp

# expand the source files
echo "Extract Packages"
cd build
tar xzf $VERSION_NGINX.tar.gz
tar xzf $VERSION_LIBRESSL.tar.gz
tar xzf $VERSION_PCRE.tar.gz
tar xzf $VERSION_ZLIB.tar.gz
cd ../

# set where LibreSSL and nginx will be built
export BPATH=$(pwd)/build
export STATICLIBSSL=$BPATH/$VERSION_LIBRESSL
 
# build static LibreSSL
echo "Configure & Build LibreSSL"
cd $STATICLIBSSL
./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ && make install-strip -j $NB_PROC
 
# build nginx, with various modules included/excluded
echo "Configure & Build Nginx"
cd $BPATH/$VERSION_NGINX
mkdir -p $BPATH/nginx
./configure --with-openssl=$STATICLIBSSL \
--with-ld-opt="-lrt" \
--sbin-path=/usr/sbin/nginx \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--with-pcre=$BPATH/$VERSION_PCRE \
--with-zlib=$BPATH/$VERSION_ZLIB \
--with-http_ssl_module \
--with-http_v2_module \
--with-file-aio \
--with-ipv6 \
--with-http_gzip_static_module \
--with-http_stub_status_module \
--without-mail_pop3_module \
--without-mail_smtp_module \
--without-mail_imap_module \
--with-http_image_filter_module \
--lock-path=/var/lock/nginx.lock \
--pid-path=/run/nginx.pid \
--http-client-body-temp-path=/var/lib/nginx/body \
--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
--http-proxy-temp-path=/var/lib/nginx/proxy \
--http-scgi-temp-path=/var/lib/nginx/scgi \
--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
--with-debug \
--with-pcre-jit \
--with-http_stub_status_module \
--with-http_realip_module \
--with-http_auth_request_module \
--with-http_addition_module \
--with-http_geoip_module \
--with-http_gzip_static_module \
--add-module=$BPATH/rtmp
 
touch $STATICLIBSSL/.openssl/include/openssl/ssl.h
make -j $NB_PROC && sudo checkinstall --pkgname="nginx-libressl" --pkgversion="$NGINX_VERSION" \
--provides="nginx" --requires="libc6, libpcre3, zlib1g" --strip=yes \
--stripso=yes --backup=yes -y --install=yes
 
echo "All done.";
echo "This build has not edited your existing /etc/nginx directory.";
echo "If things aren't working now you may need to refer to the";
echo "configuration files the new nginx ships with as defaults,";
echo "which are available at /etc/nginx-default";