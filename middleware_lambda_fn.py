import json
import urllib3

# Create a global instance of urllib3.PoolManager
http = urllib3.PoolManager()

# Function to create a Loki data source in Grafana
def create_data_source(grafana_url, token, data_source_name, data_source_uid, data_source_url, basic_auth_user, basic_auth_password):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    # Payload for the Loki data source (UID is only specified once)
    data_source_payload = {
        "name": data_source_name,
        "type": "loki",
        "url": data_source_url,
        "access": "proxy",
        "basicAuth": True,
        "basicAuthUser": basic_auth_user,
        "secureJsonData": {
            "basicAuthPassword": basic_auth_password
        },
        "uid": data_source_uid  # Only specify the UID once
    }
    
    try:
        # Convert the payload to JSON and send the POST request using urllib3
        encoded_data = json.dumps(data_source_payload).encode('utf-8')
        response = http.request(
            "POST",
            f"{grafana_url}/api/datasources",
            body=encoded_data,
            headers=headers
        )

        if response.status == 200 or response.status == 201:
            return json.loads(response.data.decode('utf-8'))
        else:
            return {"error": f"Failed to create Loki data source. Status code: {response.status}, Response: {response.data.decode('utf-8')}"}
    except urllib3.exceptions.HTTPError as e:
        return {"error": f"Request error: {e}"}

# Function to prepare the dashboard by updating the datasource UID
def prepare_dashboard(dashboard_json, datasource_uid, dashboard_title, dashboard_description):
    # Replace the placeholder UID and update title/description
    old_value = "uid-value"  # Placeholder in the template JSON
    new_value = datasource_uid  # Replace it with the actual datasource UID

    def replace_recursive(data):
        if isinstance(data, dict):
            for key, value in data.items():
                if value == old_value:
                    data[key] = new_value
                elif isinstance(value, (dict, list)):
                    replace_recursive(value)
        elif isinstance(data, list):
            for item in data:
                replace_recursive(item)

    replace_recursive(dashboard_json)

    # Update title and description
    dashboard_json["dashboard"].update({
        "title": dashboard_title,
        "description": dashboard_description
    })

    return dashboard_json

# Function to create the dashboard
def create_dashboard(grafana_url, token, dashboard_data):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "X-Grafana-Org-Id": "1"  # Adjust based on your Grafana setup
    }

    try:
        # Convert the payload to JSON and send the POST request using urllib3
        encoded_data = json.dumps(dashboard_data).encode('utf-8')
        response = http.request(
            "POST",
            f"{grafana_url}/api/dashboards/import",
            body=encoded_data,
            headers=headers
        )
        
        return json.loads(response.data.decode('utf-8')), response.status
    except urllib3.exceptions.HTTPError as e:
        return {"error": f"Request error: {e}"}, 500

# Lambda handler function
def lambda_handler(event, context):
    # Parse incoming JSON event
    try:
        data = json.loads(event["body"])
    except KeyError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing body in the request"})
        }
    
    # Required fields (datasource_uid is only needed once)
    required_fields = [
        'grafana_url', 'bearer_token', 'data_source_name', 'datasource_uid',  # Only once
        'data_source_url', 'basic_auth_user', 'basic_auth_password',
        'dashboard_uid', 'title', 'description'
    ]
    
    # Check for missing fields
    for field in required_fields:
        if field not in data:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": f"Missing field: {field}"})
            }

    # Step 1: Create the Loki data source
    print(f"Creating data source with UID: {data['datasource_uid']}")
    data_source_response = create_data_source(
        data['grafana_url'],
        data['bearer_token'],
        data['data_source_name'],
        data['datasource_uid'],  # Only needed once
        data['data_source_url'],
        data['basic_auth_user'],
        data['basic_auth_password']
    )

    if "error" in data_source_response:
        return {
            "statusCode": 400,
            "body": json.dumps(data_source_response)
        }

    # Step 2: Prepare the dashboard using the new datasource UID
    print(f"Preparing dashboard with UID: {data['dashboard_uid']}")
    try:
        with open('loki-dashboard.json', 'r') as file:
            dashboard_json = json.load(file)
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Failed to load dashboard template: {e}"})
        }

    dashboard_data = prepare_dashboard(
        dashboard_json,
        data['datasource_uid'],  # The same UID used for data source and dashboard
        data['title'],  # Set the dashboard title
        data['description']  # Set the dashboard description
    )

    # Step 3: Create the dashboard in Grafana
    print(f"Creating dashboard with UID: {data['dashboard_uid']}")
    dashboard_response, status_code = create_dashboard(
        data['grafana_url'],
        data['bearer_token'],
        dashboard_data
    )

    return {
        "statusCode": status_code,
        "body": json.dumps(dashboard_response)
    }
