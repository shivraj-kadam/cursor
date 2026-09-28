#!/bin/bash
set -euxo pipefail
exec > >(tee -a /var/log/cloudshop-backend-bootstrap.log | logger -t cloudshop-bootstrap -s 2>/dev/console) 2>&1
apt-get update -y
apt-get upgrade -y
apt-get install -y git curl unzip openjdk-21-jdk maven
mkdir -p /opt/cloudshop
if [ ! -d /opt/cloudshop/app ]; then git clone https://github.com/shivraj-kadam/cursor.git /opt/cloudshop/app; fi
cat > /etc/cloudshop-backend.env <<'ENV'
SERVER_PORT=8080
DB_URL=jdbc:postgresql://REPLACE_RDS_ENDPOINT:5432/cloudshop
DB_USERNAME=REPLACE_DB_USERNAME
DB_PASSWORD=REPLACE_DB_PASSWORD
ENV
chmod 600 /etc/cloudshop-backend.env
cd /opt/cloudshop/app/backend
mvn -B clean package -DskipTests
cat > /etc/systemd/system/cloudshop-backend.service <<'SERVICE'
[Unit]
Description=CloudShop Spring Boot Backend
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/cloudshop/app/backend
EnvironmentFile=/etc/cloudshop-backend.env
ExecStart=/usr/bin/java -jar /opt/cloudshop/app/backend/target/cloudshop-backend-1.0.0.jar
Restart=always
RestartSec=5
SuccessExitStatus=143
[Install]
WantedBy=multi-user.target
SERVICE
chown -R ubuntu:ubuntu /opt/cloudshop
systemctl daemon-reload
systemctl enable cloudshop-backend
systemctl restart cloudshop-backend
sleep 10
curl -f http://127.0.0.1:8080/api/health