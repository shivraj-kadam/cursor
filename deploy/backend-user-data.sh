#!/bin/bash
set -euxo pipefail

apt-get update -y
apt-get install -y git openjdk-17-jdk maven

APP_DIR=/opt/studentapp
rm -rf "$APP_DIR"
git clone https://github.com/shivraj-kadam/cursor.git "$APP_DIR"

# Set these values in the Launch Template User Data before launch.
export DB_URL='jdbc:mysql://REPLACE_WITH_RDS_ENDPOINT:3306/studentdb?useSSL=false&serverTimezone=UTC'
export DB_USERNAME='REPLACE_WITH_RDS_USERNAME'
export DB_PASSWORD='REPLACE_WITH_RDS_PASSWORD'

cd "$APP_DIR/backend"
mvn clean package -DskipTests

install -d /opt/studentapp/backend
cat >/etc/studentapp.env <<EOF
DB_URL=$DB_URL
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
EOF
chmod 600 /etc/studentapp.env

cat >/etc/systemd/system/studentapp.service <<'UNIT'
[Unit]
Description=Student Spring Boot Application
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/studentapp/backend
EnvironmentFile=/etc/studentapp.env
ExecStart=/usr/bin/java -jar /opt/studentapp/backend/target/student-app-1.0.0.jar
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable studentapp
systemctl restart studentapp
