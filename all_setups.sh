#!/bin/bash

# Define Versions
PROMETHEUS_VERSION="2.43.0"
NODE_EXPORTER_VERSION="1.5.0"
GRAFANA_REPO="https://rpm.grafana.com"

# Update System
sudo yum update -y

# Install Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar -xf prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
sudo mv prometheus-$PROMETHEUS_VERSION.linux-amd64/prometheus prometheus-$PROMETHEUS_VERSION.linux-amd64/promtool /usr/local/bin

# Create directories
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo mv prometheus-$PROMETHEUS_VERSION.linux-amd64/console_libraries /etc/prometheus
rm -rf prometheus-$PROMETHEUS_VERSION.linux-amd64*

# Create Prometheus configuration
cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: 'prometheus_metrics'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node_exporter_metrics'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9100','worker-1:9100','worker-2:9100']
EOF

# Setup Prometheus User and Permissions
sudo useradd -rs /bin/false prometheus
sudo chown -R prometheus: /etc/prometheus /var/lib/prometheus

# Create Prometheus Systemd Service
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

# Start and Enable Prometheus
sudo systemctl daemon-reload && sudo systemctl enable prometheus
sudo systemctl start prometheus && sudo systemctl status prometheus --no-pager

# Install Grafana
wget -q -O gpg.key $GRAFANA_REPO/gpg.key
sudo rpm --import gpg.key
cat <<EOF | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=$GRAFANA_REPO
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=$GRAFANA_REPO/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

sudo yum install grafana -y
sudo systemctl enable --now grafana-server.service
sudo systemctl status grafana-server.service --no-pager

# Install Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar -xf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
sudo mv node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/local/bin
rm -rf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64*

# Setup Node Exporter User
sudo useradd -rs /bin/false node_exporter

# Create Node Exporter Systemd Service
cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Start and Enable Node Exporter
sudo systemctl daemon-reload && sudo systemctl enable node_exporter
sudo systemctl start node_exporter.service && sudo systemctl status node_exporter.service --no-pager

# Cleanup
echo "Installation Complete. Access Prometheus at http://<server-ip>:9090 and Grafana at http://<server-ip>:3000"
