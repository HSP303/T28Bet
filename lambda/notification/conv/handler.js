"use strict";

function processMessage(snsMessage) {
  const payload = JSON.parse(snsMessage.Message);
  const { matchId, winner, settled, totalPrizePaid } = payload;

  console.log(
    `[NOTIF] Resultado registrado: matchId=${matchId}, winner=${winner}, ` +
      `${settled} apostas liquidadas, R$ ${totalPrizePaid.toFixed(2)} distribuídos`
  );
}

async function handler(event) {
  console.log(`[NOTIF] Received ${event.Records.length} SNS record(s)`);

  for (const record of event.Records) {
    processMessage(record.Sns);
  }
}

module.exports = {
  handler,
};
