import json

def handler(event, context):
    # Sample response data
    response_data = {
        "message": "Hello from Lambda!"
    }
    
    # Construct HTTP response
    response = {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(response_data)
    }
    
    return response
