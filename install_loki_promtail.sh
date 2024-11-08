#!/bin/bash

# Define the Loki and Promtail versions
LOKI_VERSION="latest"
PROMTAIL_VERSION="latest"

# Helper function to handle errors
error_exit() {
    echo "$1"
    exit 1
}

# Install dependencies based on the distribution
install_dependencies() {
    echo "Detecting package manager..."

    if command -v apt-get &>/dev/null; then
        # For Debian/Ubuntu-based systems
        echo "Detected Debian/Ubuntu-based system."
        sudo apt-get update || error_exit "Failed to update package list"
        sudo apt-get install -y wget unzip nginx apache2-utils || error_exit "Failed to install required packages"
    
    elif command -v yum &>/dev/null; then
        # For CentOS/RHEL 7 and older systems
        echo "Detected CentOS/RHEL-based system (YUM)."
        sudo yum install -y wget unzip nginx httpd-tools || error_exit "Failed to install required packages"
    
    elif command -v dnf &>/dev/null; then
        # For CentOS/RHEL 8+ and Fedora systems
        echo "Detected CentOS/RHEL 8+/Fedora-based system (DNF)."
        sudo dnf install -y wget unzip nginx httpd-tools || error_exit "Failed to install required packages"
    
    else
        error_exit "Unsupported package manager. Please install wget, unzip, nginx, and apache2-utils manually."
    fi
}
#!/bin/bash

# Helper function to handle errors
error_exit() {
    echo "$1"
    exit 1
}

# Get the system architecture dynamically
get_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        armv7l) ARCH="armv7" ;;
        aarch64) ARCH="arm64" ;;
        *) error_exit "Unsupported architecture: $ARCH" ;;
    esac
    echo "Detected architecture: $ARCH"
}

# Fetch the latest version of Loki or Promtail dynamically from GitHub
get_latest_version() {
    REPO="$1"
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/grafana/$REPO/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")')
    if [ -z "$LATEST_VERSION" ]; then
        error_exit "Failed to fetch the latest version for $REPO"
    fi
    echo "$LATEST_VERSION"
}

# Install Loki with dynamically detected architecture and latest version
install_loki() {
    echo "Installing Loki..."

    # Detect architecture and latest version
    get_architecture
    LOKI_VERSION=$(get_latest_version "loki")

    # Construct the download URL based on architecture and version
    LOKI_URL="https://github.com/grafana/loki/releases/download/${LOKI_VERSION}/loki-linux-${ARCH}.zip"
    wget "$LOKI_URL" -O /tmp/loki.zip || error_exit "Failed to download Loki"
    unzip /tmp/loki.zip -d /tmp || error_exit "Failed to unzip Loki"
    sudo mv /tmp/loki-linux-${ARCH} /usr/local/bin/loki || error_exit "Failed to move Loki binary"
    sudo chmod +x /usr/local/bin/loki || error_exit "Failed to make Loki executable"
    rm /tmp/loki.zip

    echo "Creating Loki configuration..."
    sudo mkdir -p /etc/loki || error_exit "Failed to create Loki config directory"

    cat <<EOL | sudo tee /etc/loki/loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100
  http_listen_address: 0.0.0.0
  grpc_listen_port: 9096
  log_level: debug

common:
  instance_addr: 0.0.0.0
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

pattern_ingester:
  enabled: true

ruler:
  alertmanager_url: http://localhost:9093
EOL

    cat <<EOL | sudo tee /etc/systemd/system/loki.service
[Unit]
Description=Loki: A log aggregation system
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yaml
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload || error_exit "Failed to reload systemd daemon"
    sudo systemctl start loki || error_exit "Failed to start Loki"
    sudo systemctl enable loki || error_exit "Failed to enable Loki on boot"
}

# Install Promtail with dynamically detected architecture and latest version
install_promtail() {
    echo "Installing Promtail..."

    # Detect architecture and latest version
    get_architecture
    PROMTAIL_VERSION=$(get_latest_version "loki")

    # Construct the download URL based on architecture and version
    PROMTAIL_URL="https://github.com/grafana/loki/releases/download/${PROMTAIL_VERSION}/promtail-linux-${ARCH}.zip"
    wget "$PROMTAIL_URL" -O /tmp/promtail.zip || error_exit "Failed to download Promtail"
    unzip /tmp/promtail.zip -d /tmp || error_exit "Failed to unzip Promtail"
    sudo mv /tmp/promtail-linux-${ARCH} /usr/local/bin/promtail || error_exit "Failed to move Promtail binary"
    sudo chmod +x /usr/local/bin/promtail || error_exit "Failed to make Promtail executable"
    rm /tmp/promtail.zip

    echo "Creating Promtail configuration..."
    sudo mkdir -p /etc/promtail || error_exit "Failed to create Promtail config directory"

    cat <<EOL | sudo tee /etc/promtail/promtail-config.yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    pipeline_stages:
      - docker: {}
      - regex:
          expression: '(?P<log_level>ERROR|DEBUG|INFO|TRACE|WARN)'  # Extracts log level
      - labels:
          log_level:  # Adds log_level as a label
      - timestamp:
          source: timestamp
          format: "2006-01-02T15:04:05Z07:00"
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*-json.log

  - job_name: system
    pipeline_stages:
      - regex:
          expression: '(?P<log_level>ERROR|DEBUG|INFO|TRACE|WARN)'  # Extracts log level from system logs
      - labels:
          log_level:  # Adds log_level as a label for system logs
      - timestamp:
          source: timestamp
          format: "2006-01-02T15:04:05Z07:00"
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          __path__: /var/log/*.log
EOL

    cat <<EOL | sudo tee /etc/systemd/system/promtail.service
[Unit]
Description=Promtail: A log shipping agent for Loki
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/promtail-config.yaml
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload || error_exit "Failed to reload systemd daemon"
    sudo systemctl start promtail || error_exit "Failed to start Promtail"
    sudo systemctl enable promtail || error_exit "Failed to enable Promtail on boot"
}


# Check if Docker is installed
check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Docker not found. Please install it."
    fi
}

# Configure Docker if installed
configure_docker() {
    if [ "$skip_docker_config" == "false" ]; then
        echo "Configuring Docker log driver..."
        sudo mkdir -p /etc/docker || error_exit "Failed to create Docker config directory"
        cat <<EOL | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOL
        sudo systemctl restart docker || error_exit "Failed to restart Docker"
    fi
}
# Configure Nginx with basic authentication for Loki
configure_nginx() {
    echo "Checking if Nginx is installed..."

    # Detect the system type and set configuration paths accordingly
    if [ -d "/etc/nginx/sites-available" ]; then
        # Debian/Ubuntu style
        NGINX_CONF_DIR="/etc/nginx/sites-available"
        USE_SITES_ENABLED=true
        MAIN_CONF_PATH="/etc/nginx/nginx.conf"
    else
        # RHEL/CentOS/Amazon Linux style
        NGINX_CONF_DIR="/etc/nginx/conf.d"
        USE_SITES_ENABLED=false
        MAIN_CONF_PATH="/etc/nginx/nginx.conf"
    fi

    # Create password file for basic authentication
    if command -v htpasswd &>/dev/null; then
        # Secure password prompt for Nginx authentication
        read -sp "Enter the password for Loki Nginx access (you won’t see the password as you type): " nginx_password
        echo
        sudo htpasswd -cb /etc/nginx/.htpasswd admin "$nginx_password" || error_exit "Failed to create password file for Nginx"
    else
        error_exit "htpasswd command not found. Please install apache2-utils or httpd-tools"
    fi

    # Create Nginx config for Loki with basic auth
    if [ "$USE_SITES_ENABLED" = true ]; then
        # Debian/Ubuntu style configuration
        CONFIG_PATH="${NGINX_CONF_DIR}/loki"
        
        # Create the configuration
        cat <<EOL | sudo tee "$CONFIG_PATH"
server {
    listen 3009;
    listen [::]:3009;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3100;
        auth_basic "Protected";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOL

        # Enable the site by creating a symbolic link
        sudo ln -sf "$CONFIG_PATH" "/etc/nginx/sites-enabled/loki"
        
        # Ensure sites-enabled is included in main nginx.conf
        if ! grep -q "sites-enabled" "$MAIN_CONF_PATH"; then
            # Backup the original config
            sudo cp "$MAIN_CONF_PATH" "${MAIN_CONF_PATH}.bak"
            
            # Add include directive inside http block if not present
            sudo sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' "$MAIN_CONF_PATH"
        fi
    else
        # RHEL/CentOS/Amazon Linux style configuration
        CONFIG_PATH="${NGINX_CONF_DIR}/loki.conf"
        
        # Create the configuration
        cat <<EOL | sudo tee "$CONFIG_PATH"
server {
    listen 3009;
    listen [::]:3009;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3100;
        auth_basic "Protected";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOL
    fi

    # Test Nginx configuration
    sudo nginx -t || error_exit "Nginx configuration test failed"

    # Restart Nginx to apply the configuration
    if command -v systemctl &>/dev/null; then
        sudo systemctl restart nginx || error_exit "Failed to restart Nginx"
    else
        sudo service nginx restart || error_exit "Failed to restart Nginx"
    fi

    echo "Nginx configuration completed successfully"
    echo "Access Loki at http://<your-server-ip>:3009 with username 'admin' and password 'strongpassword'"
}

# Fix permissions for Loki and Promtail configuration files
fix_permissions() {
    echo "Setting permissions for configuration files..."
    sudo chown root:root /etc/promtail/promtail-config.yaml || error_exit "Failed to set ownership for Promtail config file"
    sudo chmod 644 /etc/promtail/promtail-config.yaml || error_exit "Failed to set permissions for Promtail config file"
    sudo chown root:root /etc/loki/loki-config.yaml || error_exit "Failed to set ownership for Loki config file"
    sudo chmod 644 /etc/loki/loki-config.yaml || error_exit "Failed to set permissions for Loki config file"
}

# Main execution
install_dependencies
get_architecture
install_loki
install_promtail
check_docker
configure_docker
configure_nginx
fix_permissions

echo "Installation and configuration completed!"