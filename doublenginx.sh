#!/bin/bash
set -e

#Create the following script (DoublePageNginx.sh) . 
#Give it execute access (chmod 755 DoublePageNginx.sh) and
#run (./DoublePageNginx.sh)


# Create self signed cert for HTTPS reverse proxy as Nginx
openssl genrsa -out /tmp/app.key 2048
openssl req -new -key /tmp/app.key -out /tmp/app.csr -subj "/C=CA/ST=ON/L=Toronto/O=Digital/OU=IT/CN=app.local.com"
openssl x509 -req -days 365 -in /tmp/app.csr -signkey /tmp/app.key -out /tmp/app.crt
chmod 644 /tmp/app.crt /tmp/app.key
echo "self signed cert done" >> /tmp/debug.log

yum -y install nginx
mkdir -p /etc/nginx/ssl
cp -f /tmp/app.key /etc/nginx/ssl/app.key
cp -f /tmp/app.crt /etc/nginx/ssl/app.crt
chmod 755 /etc/nginx/ssl && chmod -R 644 /etc/nginx/ssl/*
mv -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
echo "nginx installed" >> /tmp/debug.log

# 
cat > /etc/nginx/nginx.conf <<'EOF'  
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;
events {
    worker_connections 1024;
}
http {
  log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
  '$status $body_bytes_sent "$http_referer" '
  '"$http_user_agent" "$http_x_forwarded_for"';
  access_log  /var/log/nginx/access.log  main;
  sendfile            on;
  tcp_nopush          on;
  tcp_nodelay         on;
  keepalive_timeout   65;
  types_hash_max_size 2048;
  include /etc/nginx/mime.types;
  default_type        application/octet-stream;
  include /etc/nginx/conf.d/*.conf;
  server 
  {
          listen       443 ssl http2 default_server;
          listen       [::]:443 ssl http2 default_server;
          server_name  _;
          root         /etc/nginx/www;
          index index.html index.htm;
          ssl_certificate "/etc/nginx/ssl/app.crt";
          ssl_certificate_key "/etc/nginx/ssl/app.key";
          ssl_session_cache shared:SSL:1m;
          ssl_session_timeout  10m;
          ssl_ciphers HIGH:!aNULL:!MD5;
          ssl_prefer_server_ciphers on;
          # Load configuration files for the default server block.
          include /etc/nginx/default.d/*.conf;

          location / {
            # it picks up default root and checks for default index.html file at the path
            }

          location /bar {
            # it picks up default root, adds /bar to the root and looks for the default index.html file at the path
           }


          error_page 404 /404.html;
              location = /40x.html {
          }

          error_page 500 502 503 504 /50x.html;
              location = /50x.html {
          }
    }
}
EOF

## Create static webpages to serve
mkdir -p /etc/nginx/www
cat > /etc/nginx/www/index.html <<'EOF'  
<h1> Hello There</h1>
  <p>
    This webpage is serverd through nginx at default root path
  </p>
EOF
chmod 0755  /etc/nginx/www
chmod 644 /etc/nginx/www/index.html
echo "index webpage created "  >> /tmp/debug.log

mkdir -p /etc/nginx/www/bar
cat > /etc/nginx/www/bar/index.html <<'EOF'  
<h1> Hello There</h1>
  <p>
    This webpage is serverd through nginx at path /$root/bar
  </p>
EOF
chmod 0755  /etc/nginx/www/bar
chmod 644 /etc/nginx/www/bar/index.html
echo "index webpage created for /bar"  >> /tmp/debug.log

## firewalld
yum -y install firewalld
systemctl unmask firewalld
systemctl restart firewalld
firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --zone=public --permanent --add-service=https
firewall-cmd --reload
systemctl enable firewalld
systemctl restart firewalld

systemctl restart nginx
