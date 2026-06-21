import { Router, Request, Response } from 'express';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { Bet } from '../models/Bet';
import { Transaction } from '../models/Transaction';
import { Match } from '../models/Match';
import { User } from '../models/User';
import { authMiddleware } from '../middlewares/auth';
import { redisClient } from '../services/redis';
import { sendMessage } from '../services/sqs';
import { logger } from '../logger';

const router = Router();

async function createBetSynchronously(params: {
  userId: string;
  matchId: string;
  market: 'home' | 'draw' | 'away';
  amount: number;
  oddsSnapshot: number;
  potentialReturn: number;
}): Promise<void> {
  const { userId, matchId, market, amount, oddsSnapshot, potentialReturn } = params;

  const match = await Match.findById(matchId);
  if (!match) {
    throw new Error('Partida não encontrada');
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
}

// Rate limiter for bet creation
const betLimiter = rateLimit({
  windowMs: 1000, // 1 second
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id ?? ipKeyGenerator(req.ip ?? 'unknown'),
  message: { message: 'Muitas apostas em sequência. Aguarde um momento.' },
  store: new RedisStore({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    sendCommand: (...args: string[]) => (redisClient as any).call(...args),
  }),
});

// POST /api/bets — place a bet
router.post('/', authMiddleware, betLimiter, async (req: Request, res: Response) => {
  try {
    const { matchId, market, amount } = req.body;
    const userId = req.user!.id;

    // Validate inputs
    if (!matchId || !market || !amount) {
      res.status(400).json({ message: 'matchId, market e amount são obrigatórios' });
      return;
    }

    if (!['home', 'draw', 'away'].includes(market)) {
      res.status(400).json({ message: 'market deve ser "home", "draw" ou "away"' });
      return;
    }

    const numAmount = Number(amount);
    if (isNaN(numAmount) || numAmount <= 0) {
      res.status(400).json({ message: 'amount deve ser um número positivo' });
      return;
    }

    // Verify match exists and is scheduled
    const match = await Match.findById(matchId);
    if (!match) {
      res.status(404).json({ message: 'Partida não encontrada' });
      return;
    }

    if (match.status !== 'scheduled') {
      res.status(409).json({ message: 'Partida não está disponível para apostas' });
      return;
    }

    // Get odds for the market
    const oddsMap = { home: match.odds.home, draw: match.odds.draw, away: match.odds.away };
    const oddsSnapshot = oddsMap[market as keyof typeof oddsMap];
    const potentialReturn = parseFloat((numAmount * oddsSnapshot).toFixed(2));

    // Atomically verify balance and debit
    const updatedUser = await User.findOneAndUpdate(
      { _id: userId, balance: { $gte: numAmount } },
      { $inc: { balance: -numAmount } },
      { new: true }
    );

    if (!updatedUser) {
      res.status(400).json({ message: 'Saldo insuficiente' });
      return;
    }

    // Publish to SQS queue (async processing)
    const sqsQueueUrl = process.env.SQS_BETS_QUEUE_URL;
    if (sqsQueueUrl) {
      try {
        await sendMessage(sqsQueueUrl, {
          userId,
          matchId,
          market,
          amount: numAmount,
          oddsSnapshot,
          potentialReturn,
        });

        // Publish balance update via Redis WebSocket
        try {
          await redisClient.publish(
            `balance:${userId}`,
            JSON.stringify({ balance: updatedUser.balance })
          );
        } catch (redisErr) {
          logger.error({ err: redisErr }, 'Erro ao publicar balance_update no Redis');
        }

        res.status(202).json({ message: 'Aposta recebida' });
        return;
      } catch (sqsErr) {
        // SQS failed — keep the bet by falling back to synchronous processing.
        logger.error({ err: sqsErr }, 'Erro ao enviar aposta para SQS — usando fallback síncrono');
      }
    }

    // Fallback: create bet synchronously (when SQS is not configured or unavailable).
    await createBetSynchronously({
      userId,
      matchId,
      market,
      amount: numAmount,
      oddsSnapshot,
      potentialReturn,
    });

    // Publish balance update via Redis WebSocket
    try {
      await redisClient.publish(
        `balance:${userId}`,
        JSON.stringify({ balance: updatedUser.balance })
      );
    } catch (redisErr) {
      logger.error({ err: redisErr }, 'Erro ao publicar balance_update no Redis');
    }

    res.status(201).json({ message: 'Aposta registrada com sucesso' });
  } catch (err) {
    logger.error({ err }, 'Erro ao realizar aposta');
    res.status(500).json({ message: 'Erro interno do servidor' });
  }
});

// GET /api/bets — list user's bets
router.get('/', authMiddleware, async (req: Request, res: Response) => {
  try {
    const bets = await Bet.find({ userId: req.user!.id })
      .populate('matchId', 'homeTeam awayTeam date odds status result')
      .sort({ createdAt: -1 });

    res.json(bets);
  } catch (err) {
    logger.error({ err }, 'Erro ao listar apostas');
    throw err;
  }
});

// GET /api/bets/:id — get single bet
router.get('/:id', authMiddleware, async (req: Request, res: Response) => {
  try {
    const bet = await Bet.findById(req.params.id).populate(
      'matchId',
      'homeTeam awayTeam date odds status result'
    );

    if (!bet) {
      res.status(404).json({ message: 'Aposta não encontrada' });
      return;
    }

    if (bet.userId.toString() !== req.user!.id) {
      res.status(403).json({ message: 'Acesso negado' });
      return;
    }

    res.json(bet);
  } catch (err) {
    logger.error({ err }, 'Erro ao buscar aposta');
    throw err;
  }
});

export default router;
