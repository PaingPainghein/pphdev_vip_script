#!/bin/bash

# Update and upgrade system packages
echo "Updating and upgrading system..."
apt update -y && apt upgrade -y

# Download Plus script from GitHub
echo "Downloading Plus script..."
wget https://raw.githubusercontent.com/PaingPainghein/pphdev_vip_script/master/Plus

# Make Plus executable
echo "Setting execute permissions for Plus..."
chmod 777 Plus

# Execute Plus
echo "Running Plus..."
./Plus

echo "Setup completed!"
