import mongoose from 'mongoose';
import { Bet, Match, Transaction, User } from './models';
import { publishRedisMessage } from './redis';

export type SettlementWinner = 'home' | 'draw' | 'away';

export interface SettlementResult {
  settled: number;
  totalPrizePaid: number;
}

let isConnected = false;

async function connectMongo(): Promise<void> {
  if (isConnected) return;

  const mongoUri = process.env.MONGO_URI;
  if (!mongoUri) {
    throw new Error('MONGO_URI environment variable is not set');
  }

  await mongoose.connect(mongoUri);
  isConnected = true;
  console.log('[settle] MongoDB connected');
}

export async function settleMatch(
  matchId: string,
  winner: SettlementWinner
): Promise<SettlementResult> {
  await connectMongo();

  // Update match to finished with the given result (idempotent via $set)
  await Match.findByIdAndUpdate(matchId, {
    $set: { status: 'finished', result: winner },
  });

  // Only process bets that are still pending — idempotent by design
  const pendingBets = await Bet.find({ matchId, status: 'pending' });

  let settled = 0;
  let totalPrizePaid = 0;

  for (const bet of pendingBets) {
    // Re-check status inside loop to guard against concurrent executions
    if (bet.status !== 'pending') continue;

    const isWinner = bet.market === winner;

    if (isWinner) {
      const actualReturn = parseFloat((bet.amount * bet.odds).toFixed(2));

      // Mark bet as won
      bet.status = 'won';
      bet.actualReturn = actualReturn;
      bet.settledAt = new Date();
      await bet.save();

      // Credit user balance atomically
      const updatedUser = await User.findByIdAndUpdate(
        bet.userId,
        {
          $inc: { balance: actualReturn },
        },
        { returnDocument: 'after' }
      );

      if (updatedUser && process.env.REDIS_URL) {
        try {
          await publishRedisMessage(process.env.REDIS_URL, `balance:${bet.userId.toString()}`, {
            balance: updatedUser.balance,
          });
        } catch (err) {
          console.error('[settle] Erro ao publicar balance_update no Redis', err);
        }
      }

      // Create prize transaction
      await Transaction.create({
        userId: bet.userId,
        type: 'prize',
        amount: actualReturn,
        description: `Prêmio de aposta - Retorno de R$ ${actualReturn.toFixed(2)}`,
        relatedBetId: bet._id,
      });

      totalPrizePaid += actualReturn;
    } else {
      // Mark bet as lost
      bet.status = 'lost';
      bet.settledAt = new Date();
      await bet.save();
    }

    settled++;
  }

  console.log(
    `[settle] matchId=${matchId} winner=${winner} settled=${settled} totalPrizePaid=${totalPrizePaid}`
  );

  return { settled, totalPrizePaid };
}
