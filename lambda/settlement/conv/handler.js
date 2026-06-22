"use strict";

const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");
const { settleMatch } = require("./settle");

const snsClient = new SNSClient({
  region: process.env.AWS_REGION ?? "us-east-1",
  ...(process.env.SNS_ENDPOINT ? { endpoint: process.env.SNS_ENDPOINT } : {}),
});

async function processRecord(record) {
  const message = JSON.parse(record.body);
  const { matchId, winner } = message;

  console.log(`[handler] Processing settlement: matchId=${matchId} winner=${winner}`);

  const result = await settleMatch(matchId, winner);
  const snsPayload = {
    matchId,
    winner,
    settled: result.settled,
    totalPrizePaid: result.totalPrizePaid,
  };

  const topicArn = process.env.SNS_RESULTS_TOPIC_ARN;
  if (!topicArn) {
    console.warn("[handler] SNS_RESULTS_TOPIC_ARN not set — skipping SNS publish");
    return;
  }

  await snsClient.send(
    new PublishCommand({
      TopicArn: topicArn,
      Message: JSON.stringify(snsPayload),
      Subject: `Settlement completed: ${matchId}`,
    })
  );

  console.log(`[handler] SNS published: ${JSON.stringify(snsPayload)}`);
}

async function handler(event) {
  console.log(`[handler] Received ${event.Records.length} record(s)`);

  for (const record of event.Records) {
    await processRecord(record);
  }
}

module.exports = {
  handler,
};
