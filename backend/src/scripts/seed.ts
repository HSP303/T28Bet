import dotenv from 'dotenv';
dotenv.config();

import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { User } from '../models/User';
import { Match } from '../models/Match';

const MATCHES = [
  {
    homeTeam: 'Brasil',
    awayTeam: 'Argentina',
    date: new Date('2026-06-15T18:00:00Z'),
    status: 'scheduled',
    odds: { home: 2.1, draw: 3.2, away: 3.5 },
  },
  {
    homeTeam: 'França',
    awayTeam: 'Alemanha',
    date: new Date('2026-06-16T15:00:00Z'),
    status: 'scheduled',
    odds: { home: 2.3, draw: 3.1, away: 3.0 },
  },
  {
    homeTeam: 'Espanha',
    awayTeam: 'Portugal',
    date: new Date('2026-06-17T20:00:00Z'),
    status: 'scheduled',
    odds: { home: 2.5, draw: 3.3, away: 2.8 },
  },
  {
    homeTeam: 'Inglaterra',
    awayTeam: 'Itália',
    date: new Date('2026-06-18T17:00:00Z'),
    status: 'scheduled',
    odds: { home: 2.2, draw: 3.0, away: 3.2 },
  },
  {
    homeTeam: 'Holanda',
    awayTeam: 'Bélgica',
    date: new Date('2026-06-19T14:00:00Z'),
    status: 'scheduled',
    odds: { home: 2.0, draw: 3.1, away: 3.6 },
  },
  {
    homeTeam: 'Uruguai',
    awayTeam: 'México',
    date: new Date('2026-06-20T21:00:00Z'),
    status: 'scheduled',
    odds: { home: 1.9, draw: 3.2, away: 4.0 },
  },
  {
    homeTeam: 'Japão',
    awayTeam: 'Coreia do Sul',
    date: new Date('2026-06-21T10:00:00Z'),
    status: 'scheduled',
    odds: { home: 2.6, draw: 3.0, away: 2.7 },
  },
  {
    homeTeam: 'Senegal',
    awayTeam: 'Marrocos',
    date: new Date('2026-06-22T16:00:00Z'),
    status: 'scheduled',
    odds: { home: 2.4, draw: 3.2, away: 2.9 },
  },
];

async function seed(): Promise<void> {
  const mongoUri = process.env.MONGO_URI ?? 'mongodb://localhost:27017/t28bet';

  console.log('Conectando ao MongoDB...');
  for (let attempt = 1; attempt <= 10; attempt += 1) {
    try {
      await mongoose.connect(mongoUri);
      console.log('MongoDB conectado');
      break;
    } catch (err) {
      console.error(`Falha ao conectar ao MongoDB (tentativa ${attempt}/10)`);
      if (attempt === 10) {
        throw err;
      }

      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }

  // Create admin user if not exists
  const adminEmail = 'admin@t28bet.com';
  const existingAdmin = await User.findOne({ email: adminEmail });

  if (!existingAdmin) {
    const hashedPassword = await bcrypt.hash('admin123', 12);
    await User.create({
      name: 'Administrador',
      email: adminEmail,
      password: hashedPassword,
      balance: 100000,
      isAdmin: true,
    });
    console.log('Admin criado: admin@t28bet.com / admin123');
  } else {
    console.log('Admin já existe, pulando...');
  }

  // Seed matches
  const existingCount = await Match.countDocuments();
  if (existingCount === 0) {
    await Match.insertMany(MATCHES);
    console.log(`${MATCHES.length} partidas inseridas com sucesso`);
  } else {
    console.log(`${existingCount} partidas já existem, pulando seed de partidas...`);
  }

  console.log('Seed concluído!');
  await mongoose.disconnect();
}

seed().catch((err) => {
  console.error('Erro no seed:', err);
  process.exit(1);
});
