// Backend/SNS.js
const AWS = require("aws-sdk");
const sns = new AWS.SNS();

const sendEmail = async (topicArn, message) => {
    return await sns.publish({
        TopicArn: topicArn,
        Message: message
    }).promise();
};

module.exports = { sendEmail };