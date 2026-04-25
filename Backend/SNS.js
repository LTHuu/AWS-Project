const sns = new AWS.SNS();

await sns.publish({
    TopicArn: "your-topic-arn",
    Message: "Please verify your email"
}).promise();