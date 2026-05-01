const express = require("express");
const AWS = require("aws-sdk");
const crypto = require("crypto");
const path = require("path");
const lambda = new AWS.Lambda();

const app = express();
// CHÚ Ý: Đổi thành false khi deploy lên AWS
const isLocal = false;

app.use(express.json());
app.use(express.static(path.join(__dirname, "Frontend")));
app.use("/img", express.static(path.join(__dirname, "img")));

let dynamodb;
let sns;
let iam;

if (!isLocal) {
    AWS.config.update({ region: "ap-southeast-1" });
    dynamodb = new AWS.DynamoDB.DocumentClient();
    sns = new AWS.SNS();
    iam = new AWS.IAM(); // 👉 chuyển vào đây
}

app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, "Frontend", "RegisterAppScreen.html"));
});

async function createIamUser(username) {
    // 1. tạo IAM user
    await iam.createUser({
        UserName: username
    }).promise();

    // 2. attach policy CloudWatch
    await iam.attachUserPolicy({
        UserName: username,
        PolicyArn: "arn:aws:iam::101968408100:policy/CloudWatchLogsAccess"
    }).promise();

    // 3. tạo access key
    const key = await iam.createAccessKey({
        UserName: username
    }).promise();

    return {
        accessKey: key.AccessKey.AccessKeyId,
        secretKey: key.AccessKey.SecretAccessKey
    };
}

app.post("/register-app", async (req, res) => {
    const { email, appName } = req.body;
    const appId = crypto.randomUUID();

    try {
        if (isLocal) {
            return res.json({ appId, message: "LOCAL MODE (no AWS)" });
        }

        // 1. Lưu vào DynamoDB
        await dynamodb.put({
            TableName: "AppRegister",
            Item: {
                appId,
                owner: appName,
                ownerEmail: email,
            }
        }).promise();

        await lambda.invoke({
            FunctionName: "sns-subscribe-lambda",
            InvocationType: "RequestResponse",
            Payload: JSON.stringify({
                body: JSON.stringify({
                    appId: appId,
                    email: email
                })
            })
        }).promise();
        // 2. Gửi thông báo qua SNS
        // THAY "your-topic-arn" bằng mã ARN thật từ SNS Console của bạn
        await sns.publish({
            TopicArn: process.env.SNS_TOPIC_ARN,
            Message: `Your AppId is ${appId}. Please verify your application.`
        }).promise();

        // 🔥 tạo IAM user (dùng appId làm username)
        const iamUser = await createIamUser(appId + "-" + Date.now());

        res.json({
            appId,
            accessKey: iamUser.accessKey,
            secretKey: iamUser.secretKey
        });

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

app.listen(3000, "0.0.0.0", () => {
    console.log("Server running");
});
