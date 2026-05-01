import boto3
import os
import json

sns = boto3.client('sns')
TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    appId = body.get('appId')
    email = body.get('email')
    
    if not appId or not email:
        return {"statusCode": 400, "body": "Missing AppId or Email"}
    
    filter_policy = {
        "appId": [appId]
    }
    
    response = sns.subscribe(
        TopicArn=TOPIC_ARN,
        Protocol='email',
        Endpoint=email,
        Attributes={
            'FilterPolicy': json.dumps(filter_policy)
        }
    )
    
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": f"App {appId} has been registered for {email}. Please confirm your email.",
            "subscription_arn": response['SubscriptionArn']
        })
    }