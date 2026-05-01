app.post("/register-app", async (req, res) => {
    const { email, appName } = req.body;

    const appId = crypto.randomUUID();

    try {
        if (isLocal) {
            // 👉 fake dữ liệu (demo local)
            return res.json({
                appId,
                message: "LOCAL MODE (no AWS)"
            });
        }

        // 👉 AWS MODE (dùng thật)
        await dynamodb.put({
            TableName: "AppRegistry",
            Item: {
                appId,
                owner: appName,
                ownerEmail: email,
            }
        }).promise();

        await sns.publish({
            TopicArn: "your-topic-arn",
            Message: `Your AppId is ${appId}`
        }).promise();

        res.json({ appId });

    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});