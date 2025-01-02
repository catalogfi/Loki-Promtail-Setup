#!/bin/bash

# Prompt the user for required inputs
read -p "Enter the Grafana URL (e.g., https://your-grafana-url): " grafana_url
read -p "Enter the Grafana Bearer Token: " bearer_token
read -sp "Enter the Basic Auth Password for Loki: " basic_auth_password
echo

# Automatically generate UID and names based on the hostname
hostname=$(hostname)
datasource_uid="${hostname//./-}-loki-ds"  # Replace dots with hyphens
data_source_name="${hostname//./-} Loki Logs"  # Data source name set to "hostname Loki Logs"

# Prompt the user for the dashboard title, use default if empty
read -p "Enter the Dashboard Title (press Enter to use default: '${hostname} Logs Dashboard'): " user_dashboard_title
dashboard_title="${user_dashboard_title:-${hostname} Logs Dashboard}"  # Use default if not provided

# Define a generic, detailed description for the dashboard
description="This dashboard provides comprehensive monitoring and log insights for ${hostname}. It integrates Loki as the primary data source to display real-time and historical logs, ensuring seamless observability and troubleshooting."

# Get the public IP of the machine and set Loki URL
public_ip=$(curl -s http://ifconfig.me)
data_source_url="http://${public_ip}:3009"  # Set the Loki URL using public IP and port 3009

# Prepare the JSON payload
json_payload=$(cat <<EOF
{
  "grafana_url": "$grafana_url",
  "bearer_token": "$bearer_token",
  "data_source_name": "$data_source_name",
  "datasource_uid": "$datasource_uid",  
  "dashboard_uid": "$datasource_uid",   
  "data_source_url": "$data_source_url",
  "basic_auth_user": "$basic_auth_user",
  "basic_auth_password": "$basic_auth_password",
  "title": "$dashboard_title",
  "description": "$description"
}
EOF
)

# Set the middleware URL, prompt user if needed
read -p "Enter the Middleware Lambda Function URL (e.g., http://localhost:5000): " middleware_url

# Send the POST request to the middleware
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$json_payload" "$middleware_url")

# Output the response from the middleware
echo "Response from Middleware:"
echo "$response"
