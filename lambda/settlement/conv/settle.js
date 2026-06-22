"use strict";

const mongoose = require("mongoose");
const { Bet, Match, Transaction, User } = require("./models");

let isConnected = false;

async function connectMongo() {
  if (isConnected) return;

  const mongoUri = process.env.MONGO_URI;
  if (!mongoUri) {
    throw new Error("MONGO_URI environment variable is not set");
  }

  await mongoose.connect(mongoUri);
  isConnected = true;
  console.log("[settle] MongoDB connected");
}

async function settleMatch(matchId, winner) {
  await connectMongo();

  await Match.findByIdAndUpdate(matchId, {
    $set: { status: "finished", result: winner },
  });

  const pendingBets = await Bet.find({ matchId, status: "pending" });

  let settled = 0;
  let totalPrizePaid = 0;

  for (const bet of pendingBets) {
    if (bet.status !== "pending") continue;

    const isWinner = bet.market === winner;

    if (isWinner) {
      const actualReturn = parseFloat((bet.amount * bet.odds).toFixed(2));

      bet.status = "won";
      bet.actualReturn = actualReturn;
      bet.settledAt = new Date();
      await bet.save();

      await User.findByIdAndUpdate(bet.userId, {
        $inc: { balance: actualReturn },
      });

      await Transaction.create({
        userId: bet.userId,
        type: "prize",
        amount: actualReturn,
        description: `Prêmio de aposta - Retorno de R$ ${actualReturn.toFixed(2)}`,
        relatedBetId: bet._id,
      });

      totalPrizePaid += actualReturn;
    } else {
      bet.status = "lost";
      bet.settledAt = new Date();
      await bet.save();
    }

    settled += 1;
  }

  console.log(
    `[settle] matchId=${matchId} winner=${winner} settled=${settled} totalPrizePaid=${totalPrizePaid}`
  );

  return { settled, totalPrizePaid };
}

module.exports = {
  settleMatch,
};
