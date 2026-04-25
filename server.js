const express = require("express");
const AWS = require("aws-sdk");
const crypto = require("crypto");
const path = require("path");

const app = express();
// CHÚ Ý: Đổi thành false khi deploy lên AWS
const isLocal = false;

app.use(express.json());
app.use(express.static(path.join(__dirname, "Frontend")));
app.use("/img", express.static(path.join(__dirname, "img")));

let dynamodb;
let sns;

if (!isLocal) {
    AWS.config.update({ region: "ap-southeast-1" }); // Đảm bảo đúng region bạn tạo SNS/DynamoDB
    dynamodb = new AWS.DynamoDB.DocumentClient();
    sns = new AWS.SNS();
}

app.post("/register-app", async (req, res) => {
    const { email, appName } = req.body;
    const appId = crypto.randomUUID();
    const prefix = appName.substring(0, 3).toLowerCase();

    try {
        if (isLocal) {
            return res.json({ appId, prefix, message: "LOCAL MODE (no AWS)" });
        }

        // 1. Lưu vào DynamoDB
        await dynamodb.put({
            TableName: "AppRegistry",
            Item: {
                appId,
                owner: appName,
                ownerEmail: email,
                prefix
            }
        }).promise();

        // 2. Gửi thông báo qua SNS
        // THAY "your-topic-arn" bằng mã ARN thật từ SNS Console của bạn
        await sns.publish({
            TopicArn: "arn:aws:sns:ap-southeast-1:123456789012:MyTopic",
            Message: `Your AppId is ${appId}. Please verify your application.`
        }).promise();

        res.json({ appId, prefix });

    } catch (err) {
        console.error("Error:", err);
        res.status(500).json({ message: err.message });
    }
});

// XÓA HOẶC COMMENT ĐOẠN NÀY - Đây là nguyên nhân gây lỗi build
/*
const sns_test = new AWS.SNS();
await sns_test.publish({ ... }).promise(); 
*/

app.listen(3000, () => {
    console.log("Server running at http://localhost:3000");
});