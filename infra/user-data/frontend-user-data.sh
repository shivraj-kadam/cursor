#!/bin/bash
set -euxo pipefail
exec > >(tee -a /var/log/cloudshop-frontend-bootstrap.log | logger -t cloudshop-frontend -s 2>/dev/console) 2>&1
apt-get update -y
apt-get upgrade -y
apt-get install -y git curl nginx
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
mkdir -p /opt/cloudshop
if [ ! -d /opt/cloudshop/app ]; then git clone https://github.com/shivraj-kadam/cursor.git /opt/cloudshop/app; fi
cd /opt/cloudshop/app/frontend
npm install
npm run build
rm -rf /var/www/cloudshop
mkdir -p /var/www/cloudshop
cp -r dist/* /var/www/cloudshop/
BACKEND_ALB_DNS="REPLACE_BACKEND_ALB_DNS"
sed "s|BACKEND_ALB_DNS|$BACKEND_ALB_DNS|g" /opt/cloudshop/app/infra/nginx/cloudshop.conf > /etc/nginx/sites-available/cloudshop
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/cloudshop /etc/nginx/sites-enabled/cloudshop
nginx -t
systemctl enable nginx
systemctl restart nginx
curl -f http://127.0.0.1/health