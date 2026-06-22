import { SQSClient, SendMessageCommand, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';
import { logger } from '../logger';

export const sqsClient = new SQSClient({
  region: process.env.AWS_REGION ?? 'us-east-1',
  ...(process.env.SQS_ENDPOINT ? { endpoint: process.env.SQS_ENDPOINT } : {}),
});

export async function sendMessage(queueUrl: string, body: object): Promise<void> {
  const command = new SendMessageCommand({
    QueueUrl: queueUrl,
    MessageBody: JSON.stringify(body),
  });

  try {
    await sqsClient.send(command);
    logger.info({ queueUrl }, 'Mensagem SQS enviada');
  } catch (err) {
    logger.error({ err, queueUrl }, 'Erro ao enviar mensagem SQS');
    throw err;
  }
}

export async function receiveMessages(queueUrl: string, maxMessages = 10) {
  const command = new ReceiveMessageCommand({
    QueueUrl: queueUrl,
    MaxNumberOfMessages: maxMessages,
    WaitTimeSeconds: 20, // Long polling
  });

  const result = await sqsClient.send(command);
  return result.Messages ?? [];
}

export async function deleteMessage(queueUrl: string, receiptHandle: string): Promise<void> {
  const command = new DeleteMessageCommand({
    QueueUrl: queueUrl,
    ReceiptHandle: receiptHandle,
  });

  await sqsClient.send(command);
}
