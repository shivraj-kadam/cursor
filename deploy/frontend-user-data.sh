#!/bin/bash
set -euxo pipefail

apt-get update -y
apt-get install -y git nginx nodejs npm

APP_DIR=/opt/studentapp
rm -rf "$APP_DIR"
git clone https://github.com/shivraj-kadam/cursor.git "$APP_DIR"

cd "$APP_DIR/frontend"
npm install
npm run build

rm -rf /var/www/studentapp
mkdir -p /var/www/studentapp
cp -r dist/* /var/www/studentapp/

cat >/etc/nginx/sites-available/studentapp <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/studentapp;
    index index.html;

    location = /health {
        default_type text/plain;
        return 200 'frontend-ok';
    }

    location /api/ {
        proxy_pass http://BACKEND_ALB_DNS:8080/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

sed -i 's|BACKEND_ALB_DNS|REPLACE_WITH_INTERNAL_BACKEND_ALB_DNS|' /etc/nginx/sites-available/studentapp

rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/studentapp /etc/nginx/sites-enabled/studentapp
nginx -t
systemctl enable nginx
systemctl restart nginx
