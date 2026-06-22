"use strict";

const mongoose = require("mongoose");
const { Schema } = mongoose;

const UserSchema = new Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true },
    balance: { type: Number, default: 1000 },
    isAdmin: { type: Boolean, default: false },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

const User = mongoose.model("User", UserSchema);

const BetSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    matchId: { type: Schema.Types.ObjectId, ref: "Match", required: true },
    market: { type: String, enum: ["home", "draw", "away"], required: true },
    amount: { type: Number, required: true },
    odds: { type: Number, required: true },
    potentialReturn: { type: Number, required: true },
    status: { type: String, enum: ["pending", "won", "lost"], default: "pending" },
    actualReturn: { type: Number },
    settledAt: { type: Date },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

const Bet = mongoose.model("Bet", BetSchema);

const TransactionSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    type: { type: String, enum: ["bet", "deposit", "prize"], required: true },
    amount: { type: Number, required: true },
    description: { type: String, required: true },
    relatedBetId: { type: Schema.Types.ObjectId, ref: "Bet" },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

const Transaction = mongoose.model("Transaction", TransactionSchema);

const OddsSchema = new Schema(
  {
    home: { type: Number, required: true },
    draw: { type: Number, required: true },
    away: { type: Number, required: true },
  },
  { _id: false }
);

const MatchSchema = new Schema(
  {
    homeTeam: { type: String, required: true },
    awayTeam: { type: String, required: true },
    date: { type: Date, required: true },
    status: {
      type: String,
      enum: ["scheduled", "live", "finished"],
      default: "scheduled",
    },
    odds: { type: OddsSchema, required: true },
    result: {
      type: String,
      enum: ["home", "draw", "away"],
    },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

const Match = mongoose.model("Match", MatchSchema);

module.exports = {
  User,
  Bet,
  Transaction,
  Match,
};
