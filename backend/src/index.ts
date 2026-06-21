import http from 'http';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mongoose from 'mongoose';
import pinoHttp from 'pino-http';

dotenv.config();

import { logger } from './logger';
import { connectRedis } from './services/redis';
import { initWebSocketServer } from './ws/server';
import { startBetsWorker } from './workers/betsWorker';

// Routes
import authRoutes from './routes/auth';
import matchRoutes from './routes/matches';
import betRoutes from './routes/bets';
import walletRoutes from './routes/wallet';
import adminRoutes from './routes/admin';
import healthRoutes from './routes/health';

const app = express();
const PORT = process.env.PORT ?? 3001;

// ── Middleware ────────────────────────────────────────────────────────────────

// Pino HTTP logger — must be first middleware
app.use(pinoHttp({ logger }));

app.use(cors({ origin: process.env.CORS_ORIGIN ?? 'http://localhost:3000' }));
app.use(express.json());

// ── Health routes (no auth) ───────────────────────────────────────────────────

app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.use('/ready', healthRoutes);

// ── API routes ────────────────────────────────────────────────────────────────

app.use('/api/auth', authRoutes);
app.use('/api/matches', matchRoutes);
app.use('/api/bets', betRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/admin', adminRoutes);

// ── 404 handler ──────────────────────────────────────────────────────────────

app.use((_req: Request, res: Response) => {
  res.status(404).json({ message: 'Rota não encontrada' });
});

// ── Global error handler ─────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err: Error, req: Request, res: Response, _next: NextFunction) => {
  const requestId = (req as Request & { id?: string }).id;
  logger.error({ err, requestId }, 'Unhandled error');

  res.status(500).json({
    message: 'Erro interno do servidor',
    ...(process.env.NODE_ENV !== 'production' && { error: err.message }),
  });
});

// ── Bootstrap ─────────────────────────────────────────────────────────────────

async function connectMongoWithRetry(maxAttempts = 10, delayMs = 3000): Promise<void> {
  const mongoUri = process.env.MONGO_URI ?? 'mongodb://localhost:27017/t28bet';

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await mongoose.connect(mongoUri);
      logger.info({ attempt }, 'MongoDB conectado');
      return;
    } catch (err) {
      logger.error({ err, attempt, maxAttempts }, 'Falha ao conectar ao MongoDB');
      if (attempt === maxAttempts) {
        throw err;
      }

      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

async function bootstrap(): Promise<void> {
  await connectMongoWithRetry();

  // Connect Redis
  await connectRedis();

  // Create HTTP server and attach WebSocket
  const server = http.createServer(app);
  const wsServer = initWebSocketServer();

  server.on('upgrade', (req, socket, head) => {
    wsServer.handleUpgrade(req, socket, head, (ws) => {
      wsServer.emit('connection', ws, req);
    });
  });

  // Start SQS workers in background
  startBetsWorker();

  // Start listening
  server.listen(PORT, () => {
    logger.info({ port: PORT }, `Servidor rodando na porta ${PORT}`);
  });

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    logger.info({ signal }, 'Encerrando servidor...');
    server.close(async () => {
      await mongoose.disconnect();
      logger.info('Servidor encerrado');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

bootstrap().catch((err) => {
  logger.error({ err }, 'Falha fatal ao iniciar servidor');
  process.exit(1);
});
