const express = require("express");
const AWS = require("aws-sdk");
const crypto = require("crypto");
const path = require("path");

const app = express();
const isLocal = false; // Đổi thành false khi deploy
const TOPIC_ARN = "arn:aws:sns:ap-southeast-1:101968408100:AppRegistrationTopic";

// Trong route /register-app
await sns.publish({
    TopicArn: TOPIC_ARN, // Sử dụng ARN thật
    Message: `Your AppId is ${appId}`
}).promise();

app.use(express.json());
app.use(express.static(path.join(__dirname, "Frontend")));
app.use("/img", express.static(path.join(__dirname, "img")));

let dynamodb;
let sns;

// 👉 chỉ khởi tạo khi dùng AWS
if (!isLocal) {
    AWS.config.update({ region: "ap-southeast-1" });

    dynamodb = new AWS.DynamoDB.DocumentClient();
    sns = new AWS.SNS();
}

// API
app.post("/register-app", async (req, res) => {
    const { email, appName } = req.body;

    const appId = crypto.randomUUID();
    const prefix = appName.substring(0, 3).toLowerCase();

    try {
        // ✅ LOCAL MODE
        if (isLocal) {
            return res.json({
                appId,
                prefix,
                message: "LOCAL MODE"
            });
        }

        // ✅ AWS MODE
        await dynamodb.put({
            TableName: "AppRegistry",
            Item: {
                appId,
                owner: appName,
                ownerEmail: email,
                prefix
            }
        }).promise();

        await sns.publish({
            TopicArn: "your-topic-arn",
            Message: `Your AppId is ${appId}`
        }).promise();

        res.json({ appId, prefix });

    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// route trang chủ
app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, "Frontend", "RegisterAppScreen.html"));
});

app.listen(3000, () => {
    console.log("Server running at http://localhost:3000");
});