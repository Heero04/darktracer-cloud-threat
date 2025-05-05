#!/bin/bash

# Update system packages
apt-get update
apt-get upgrade -y

# Install Python and required dependencies
apt-get install -y python3-pip python3-dev git libssl-dev libffi-dev

# Install OpenCanary and its dependencies
pip3 install opencanary
pip3 install scapy pcapy

# Create OpenCanary configuration directory
mkdir -p /etc/opencanary
cd /etc/opencanary

# Generate default config
opencanaryd --copyconfig

# Create a systemd service for OpenCanary
cat << EOF > /etc/systemd/system/opencanary.service
[Unit]
Description=OpenCanary honeypot
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/opencanaryd --dev
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chmod 644 /etc/systemd/system/opencanary.service

# Enable and start OpenCanary service
systemctl daemon-reload
systemctl enable opencanary
systemctl start opencanary
