import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Blocks table
  blocks: defineTable({
    height: v.number(),
    hash: v.string(),
    previousHash: v.string(),
    timestamp: v.number(),
    difficulty: v.number(),
    nonce: v.number(),
    size: v.number(),
    weight: v.number(),
    txCount: v.number(),
    totalValue: v.number(), // satoshis
    miner: v.optional(v.string()), // coinbase recipient address
    version: v.number(),
  })
    .index("by_height", ["height"])
    .index("by_hash", ["hash"])
    .index("by_miner", ["miner"]),

  // Transactions table
  transactions: defineTable({
    txid: v.string(),
    blockHeight: v.number(),
    blockHash: v.string(),
    timestamp: v.number(),
    size: v.number(),
    vsize: v.number(),
    fee: v.number(), // satoshis
    inputCount: v.number(),
    outputCount: v.number(),
    totalInput: v.number(), // satoshis
    totalOutput: v.number(), // satoshis
    isCoinbase: v.boolean(),
  })
    .index("by_txid", ["txid"])
    .index("by_block", ["blockHeight"])
    .index("by_timestamp", ["timestamp"]),

  // Address balances (UTXO-based would be complex, this is simplified)
  addresses: defineTable({
    address: v.string(),
    totalReceived: v.number(), // satoshis
    totalSent: v.number(), // satoshis
    txCount: v.number(),
    firstSeen: v.number(), // block height
    lastSeen: v.number(), // block height
  })
    .index("by_address", ["address"])
    .index("by_balance", ["totalReceived"]),

  // Network stats (singleton-ish, latest stats)
  networkStats: defineTable({
    blockHeight: v.number(),
    difficulty: v.number(),
    hashrate: v.number(),
    totalSupply: v.number(), // satoshis
    totalTransactions: v.number(),
    totalAddresses: v.number(),
    updatedAt: v.number(),
  })
    .index("by_height", ["blockHeight"]),

  // Indexer state
  indexerState: defineTable({
    key: v.string(),
    lastIndexedHeight: v.number(),
    lastIndexedHash: v.string(),
    updatedAt: v.number(),
  })
    .index("by_key", ["key"]),
});
