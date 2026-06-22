import dotenv from 'dotenv';
dotenv.config();

import { Bet } from '../models/Bet';
import { Transaction } from '../models/Transaction';
import { Match } from '../models/Match';
import { receiveMessages, deleteMessage } from '../services/sqs';
import { logger } from '../logger';
import mongoose from 'mongoose';

interface BetMessage {
  userId: string;
  matchId: string;
  market: 'home' | 'draw' | 'away';
  amount: number;
  oddsSnapshot: number;
  potentialReturn: number;
}

async function processBetMessage(body: BetMessage): Promise<void> {
  const { userId, matchId, market, amount, oddsSnapshot, potentialReturn } = body;

  const match = await Match.findById(matchId);
  if (!match) {
    logger.error({ matchId }, 'Worker: Partida não encontrada para bet message');
    return;
  }

  const bet = await Bet.create({
    userId,
    matchId,
    market,
    amount,
    odds: oddsSnapshot,
    potentialReturn,
    status: 'pending',
  });

  await Transaction.create({
    userId,
    type: 'bet',
    amount,
    description: `Aposta em ${match.homeTeam} vs ${match.awayTeam} — mercado ${market}`,
    relatedBetId: bet._id,
  });

  logger.info({ betId: bet._id, userId, matchId }, 'Worker: Aposta processada com sucesso');
}

async function pollBetsQueue(): Promise<void> {
  const betsQueueUrl = process.env.SQS_BETS_QUEUE_URL;
  if (!betsQueueUrl) {
    logger.warn('SQS_BETS_QUEUE_URL não configurada — worker de apostas inativo');
    return;
  }

  logger.info({ queueUrl: betsQueueUrl }, 'Worker de apostas iniciado');

  // eslint-disable-next-line no-constant-condition
  while (true) {
    try {
      const messages = await receiveMessages(betsQueueUrl);

      for (const msg of messages) {
        if (!msg.Body || !msg.ReceiptHandle) continue;

        try {
          const body = JSON.parse(msg.Body) as BetMessage;
          await processBetMessage(body);
          await deleteMessage(betsQueueUrl, msg.ReceiptHandle);
        } catch (err) {
          logger.error({ err, messageId: msg.MessageId }, 'Erro ao processar mensagem de aposta');
          // Don't delete — allow reprocessing
        }
      }
    } catch (err) {
      logger.error({ err }, 'Erro ao receber mensagens SQS de apostas');
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
  }
}

export function startBetsWorker(): void {
  pollBetsQueue().catch((err) => {
    logger.error({ err }, 'Worker de apostas encerrou com erro');
  });
}

// If run directly (not imported)
if (require.main === module) {
  mongoose
    .connect(process.env.MONGO_URI ?? 'mongodb://localhost:27017/t28bet')
    .then(() => {
      logger.info('Worker: MongoDB conectado');
      startBetsWorker();
    })
    .catch((err) => {
      logger.error({ err }, 'Worker: Falha ao conectar MongoDB');
      process.exit(1);
    });
}
