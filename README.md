# Loki-Promtail-Setup

This repository automates the setup of **Loki** and **Promtail** for centralized logging with **Grafana**. The scripts in this repository streamline the installation process for Loki and Promtail, and automatically configure Grafana with data sources and dashboards.

---

## Features

- **Automated Loki & Promtail Setup**: One-click installation for Loki and Promtail.
- **Automated Grafana Data Source & Dashboard Configuration**: Automatically configure Grafana for Loki.
- **Middleware Integration**: Middleware for adding and configuring data sources and dashboards in Grafana.

---

## Prerequisites

- A Linux-based server (Ubuntu/Debian, CentOS/RHEL, Fedora).
- **Grafana** running and accessible (this setup assumes Grafana is already installed).
- **Python 3.x** for middleware (if using the middleware).
- **Sudo Privileges**: You should have sudo access to install and configure software.

---

## Table of Contents

1. [Installation](#installation)
   - [Install Loki & Promtail](#install-loki--promtail)
2. [Middleware Setup](#middleware-setup)
   - [Run Middleware Script](#run-middleware-script)
3. [Grafana Data Source & Dashboard Setup](#grafana-data-source--dashboard-setup)
   - [Run Data Source and Dashboard Script](#run-data-source-and-dashboard-script)
4. [Accessing Loki UI](#accessing-loki-ui)
5. [Troubleshooting](#troubleshooting)
6. [License](#license)

---

## Installation

### Install Loki & Promtail

To install **Loki** and **Promtail** with a single command, run the following:

```bash
curl -sSL https://raw.githubusercontent.com/abdulsaheel/Loki-Promtail-Setup/main/scripts/install_loki_promtail.sh | sudo bash
```

This will:
- Automatically detect your system architecture.
- Download and install **Loki** and **Promtail**.
- Set up **Promtail** to run as a service and start on boot.

---

## Middleware Setup

The **middleware** helps automatically configure **Grafana** data sources and dashboards for **Loki**.

### Run Middleware Script

Download and run the middleware script with the following single command:

```bash
curl -sSL https://raw.githubusercontent.com/abdulsaheel/Loki-Promtail-Setup/main/scripts/middleware.py | python3 -
```

This command:
- Downloads the **middleware.py** script.
- Runs it using Python (ensure you have Python 3.x installed).

The script will ask for the following inputs:
- **Grafana URL**
- **Grafana Bearer Token**
- **Loki Basic Auth Password**
- **Middleware URL** (for sending configuration data)

This will configure **Loki** as a data source and create a dashboard in **Grafana** automatically.

---

## Grafana Data Source & Dashboard Setup

To automatically add **Loki** as a data source and create a Grafana dashboard, you can use the following single command:

```bash
curl -sSL https://raw.githubusercontent.com/abdulsaheel/Loki-Promtail-Setup/main/scripts/create_grafana_dashboard.sh | sudo bash
```

This command:
- Downloads the **create_grafana_dashboard.sh** script.
- Runs the script to:
  - Configure **Loki** as a data source in **Grafana**.
  - Create a default dashboard for **Loki** logs.

It will prompt for the following inputs:
- **Grafana URL**
- **Bearer Token**
- **Loki Basic Auth Password**
- **Middleware URL**

---

## Accessing Loki UI

Once **Loki** and **Promtail** are installed and running, you can access the **Loki UI** at:

```bash
http://<your-server-ip>:3100
```

- **Username**: `admin` (default).
- **Password**: The password you configured during the installation process.

In the **Loki UI**, you can query logs and visualize them with your Grafana setup.

---

## Troubleshooting

### 1. **Loki and Promtail Not Starting**
Check the status of the services:

```bash
sudo systemctl status loki
sudo systemctl status promtail
```

If the services aren’t running, check the logs:

```bash
journalctl -u loki
journalctl -u promtail
```

### 2. **Grafana Data Source Not Created**
Ensure that the **Loki** URL and credentials in the middleware script are correct, and that the **Grafana Bearer Token** is valid and has the necessary permissions to create data sources.

### 3. **Logs Not Showing in Grafana**
Verify the data source in Grafana:
- Go to **Configuration → Data Sources → Loki**.
- Ensure the URL and credentials match the settings from the middleware script.

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---