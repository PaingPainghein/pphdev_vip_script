#!/bin/bash

# VPS VIP Management System Installer
# Version: 1.0
# Author: PaingPainghein

# Configuration
APP_NAME="vipmanager"
APP_PORT=8080
VPS_IP="45.154.26.195"
DB_NAME="vip_users"
DB_USER="vipadmin"
DB_PASS=$(openssl rand -hex 16)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Update system
echo -e "${YELLOW}[1/8] Updating system packages...${NC}"
apt update -y && apt upgrade -y

# Install dependencies
echo -e "${YELLOW}[2/8] Installing dependencies...${NC}"
apt install -y openjdk-17-jdk git maven nginx mariadb-server

# Setup MySQL/MariaDB
echo -e "${YELLOW}[3/8] Configuring database...${NC}"
mysql -e "CREATE DATABASE ${DB_NAME};"
mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Create application directory
echo -e "${YELLOW}[4/8] Creating application structure...${NC}"
mkdir -p /opt/${APP_NAME}/{config,logs}
cd /opt/${APP_NAME}

# Clone repository
echo -e "${YELLOW}[5/8] Downloading application...${NC}"
git clone https://github.com/PaingPainghein/pphdev_vip_script.git .

# Build application
echo -e "${YELLOW}[6/8] Building application...${NC}"
mvn clean package

# Configuration files
echo -e "${YELLOW}[7/8] Creating configuration files...${NC}"

# application.properties
cat > /opt/${APP_NAME}/config/application.properties <<EOL
server.port=${APP_PORT}
spring.datasource.url=jdbc:mysql://localhost:3306/${DB_NAME}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASS}
spring.jpa.hibernate.ddl-auto=update
vps.token.secret=$(openssl rand -hex 32)
EOL

# nginx configuration
cat > /etc/nginx/sites-available/${APP_NAME} <<EOL
server {
    listen 80;
    server_name ${VPS_IP};

    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log /var/log/nginx/${APP_NAME}_error.log;
}
EOL

# systemd service file
cat > /etc/systemd/system/${APP_NAME}.service <<EOL
[Unit]
Description=VIP Manager Service
After=syslog.target network.target

[Service]
User=root
WorkingDirectory=/opt/${APP_NAME}
ExecStart=/usr/bin/java -jar /opt/${APP_NAME}/target/${APP_NAME}-1.0.0.jar
Environment="SPRING_CONFIG_LOCATION=file:/opt/${APP_NAME}/config/application.properties"

SuccessExitStatus=143
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOL

# Enable services
echo -e "${YELLOW}[8/8] Enabling services...${NC}"
ln -s /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/
systemctl daemon-reload
systemctl enable ${APP_NAME}
systemctl start ${APP_NAME}
systemctl restart nginx

# Firewall configuration
ufw allow 80/tcp
ufw allow 22/tcp
ufw --force enable

echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "\n${YELLOW}Important Information:${NC}"
echo -e "Database Name: ${DB_NAME}"
echo -e "Database User: ${DB_USER}"
echo -e "Database Password: ${DB_PASS}"
echo -e "API Endpoint: http://${VPS_IP}/api/v1/users"
echo -e "Access Token: $(grep 'vps.token.secret' /opt/${APP_NAME}/config/application.properties | cut -d'=' -f2)"
