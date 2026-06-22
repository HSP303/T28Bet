import net from 'node:net';
import { URL } from 'node:url';

function encodeRedisCommand(parts: string[]): string {
  return `*${parts.length}\r\n${parts
    .map((part) => `$${Buffer.byteLength(part)}\r\n${part}\r\n`)
    .join('')}`;
}

export async function publishRedisMessage(
  redisUrl: string,
  channel: string,
  message: unknown
): Promise<void> {
  const url = new URL(redisUrl);
  const payload = typeof message === 'string' ? message : JSON.stringify(message);
  const command = encodeRedisCommand(['PUBLISH', channel, payload]);

  await new Promise<void>((resolve, reject) => {
    let settled = false;
    const socket = net.createConnection(
      {
        host: url.hostname,
        port: Number(url.port || '6379'),
      },
      () => {
        socket.end(command);
      }
    );

    socket.setTimeout(5000, () => {
      socket.destroy(new Error('Redis publish timeout'));
    });

    socket.once('data', (chunk) => {
      const response = chunk.toString('utf8');
      if (response.startsWith('-')) {
        settled = true;
        socket.destroy();
        reject(new Error(`Redis publish failed: ${response.trim()}`));
        return;
      }

      settled = true;
      socket.destroy();
      resolve();
    });

    socket.once('error', (err) => {
      if (!settled) reject(err);
    });

    socket.once('close', () => {
      if (!settled) resolve();
    });
  });
}
