#!/bin/bash

# VPS VIP Management System Installer
# Creates API endpoint that handles {"vip_users":[{"Name":"","id":"","month":"","Valid":"","start_date":"","Expiration":""}]} format

# Update system
apt update -y && apt upgrade -y

# Install dependencies
apt install -y openjdk-17-jdk git maven nginx

# Create application directory
mkdir -p /opt/vipmanager
cd /opt/vipmanager

# Create Spring Boot application
cat > src/main/java/com/pphdev/vipmanager/VipManagerApplication.java <<'EOL'
package com.pphdev.vipmanager;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import java.util.concurrent.ConcurrentHashMap;

@SpringBootApplication
@RestController
@RequestMapping("/api/v1")
public class VipManagerApplication {

    private ConcurrentHashMap<String, String> userData = new ConcurrentHashMap<>();

    public static void main(String[] args) {
        SpringApplication.run(VipManagerApplication.class, args);
    }

    @GetMapping("/users")
    public ResponseEntity<String> getUsers() {
        String data = userData.getOrDefault("vip_data", "{\"vip_users\":[]}");
        return ResponseEntity.ok(data);
    }

    @PostMapping("/users")
    public ResponseEntity<String> updateUsers(@RequestBody String payload) {
        userData.put("vip_data", payload);
        return ResponseEntity.ok("{\"status\":\"success\"}");
    }
}
EOL

# Create application properties
mkdir -p src/main/resources
cat > src/main/resources/application.properties <<EOL
server.port=8080
spring.jackson.serialization.indent_output=true
EOL

# Create pom.xml
cat > pom.xml <<'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.7.0</version>
        <relativePath/>
    </parent>
    
    <groupId>com.pphdev</groupId>
    <artifactId>vipmanager</artifactId>
    <version>1.0.0</version>
    <name>vipmanager</name>
    
    <properties>
        <java.version>17</java.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOL

# Build the application
mvn clean package

# Create systemd service
cat > /etc/systemd/system/vipmanager.service <<EOL
[Unit]
Description=VIP Manager Service
After=syslog.target

[Service]
User=root
WorkingDirectory=/opt/vipmanager
ExecStart=/usr/bin/java -jar /opt/vipmanager/target/vipmanager-1.0.0.jar
SuccessExitStatus=143
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOL

# Configure Nginx
cat > /etc/nginx/sites-available/vipmanager <<EOL
server {
    listen 80;
    server_name 45.154.26.195;

    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOL

# Enable services
ln -s /etc/nginx/sites-available/vipmanager /etc/nginx/sites-enabled/
systemctl daemon-reload
systemctl enable vipmanager
systemctl start vipmanager
systemctl restart nginx

# Initialize with empty VIP data
curl -X POST http://localhost:8080/api/v1/users \
     -H "Content-Type: application/json" \
     -d '{"vip_users":[]}'

echo "Installation complete!"
echo "VIP Manager is running on: http://45.154.26.195/api/v1/users"
echo "Initialized with empty VIP users array"
