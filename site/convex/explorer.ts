import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

// === QUERIES ===

export const getLatestBlocks = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 10;
    return await ctx.db
      .query("blocks")
      .withIndex("by_height")
      .order("desc")
      .take(limit);
  },
});

export const getBlockByHeight = query({
  args: { height: v.number() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("blocks")
      .withIndex("by_height", (q) => q.eq("height", args.height))
      .first();
  },
});

export const getBlockByHash = query({
  args: { hash: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("blocks")
      .withIndex("by_hash", (q) => q.eq("hash", args.hash))
      .first();
  },
});

export const getTransaction = query({
  args: { txid: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("transactions")
      .withIndex("by_txid", (q) => q.eq("txid", args.txid))
      .first();
  },
});

export const getBlockTransactions = query({
  args: { blockHeight: v.number(), limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 100;
    return await ctx.db
      .query("transactions")
      .withIndex("by_block", (q) => q.eq("blockHeight", args.blockHeight))
      .take(limit);
  },
});

export const getAddress = query({
  args: { address: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("addresses")
      .withIndex("by_address", (q) => q.eq("address", args.address))
      .first();
  },
});

export const getNetworkStats = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("networkStats")
      .withIndex("by_height")
      .order("desc")
      .first();
  },
});

export const getTopMiners = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 10;
    const blocks = await ctx.db.query("blocks").collect();
    
    // Count blocks per miner
    const minerCounts: Record<string, number> = {};
    for (const block of blocks) {
      if (block.miner) {
        minerCounts[block.miner] = (minerCounts[block.miner] || 0) + 1;
      }
    }
    
    // Sort and return top miners
    return Object.entries(minerCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([address, blocks]) => ({ address, blocks }));
  },
});

// === MUTATIONS (for indexer) ===

export const upsertBlock = mutation({
  args: {
    height: v.number(),
    hash: v.string(),
    previousHash: v.string(),
    timestamp: v.number(),
    difficulty: v.number(),
    nonce: v.number(),
    size: v.number(),
    weight: v.number(),
    txCount: v.number(),
    totalValue: v.number(),
    miner: v.optional(v.string()),
    version: v.number(),
  },
  handler: async (ctx, args) => {
    // Check if block exists
    const existing = await ctx.db
      .query("blocks")
      .withIndex("by_height", (q) => q.eq("height", args.height))
      .first();
    
    if (existing) {
      await ctx.db.patch(existing._id, args);
      return existing._id;
    }
    
    return await ctx.db.insert("blocks", args);
  },
});

export const upsertTransaction = mutation({
  args: {
    txid: v.string(),
    blockHeight: v.number(),
    blockHash: v.string(),
    timestamp: v.number(),
    size: v.number(),
    vsize: v.number(),
    fee: v.number(),
    inputCount: v.number(),
    outputCount: v.number(),
    totalInput: v.number(),
    totalOutput: v.number(),
    isCoinbase: v.boolean(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("transactions")
      .withIndex("by_txid", (q) => q.eq("txid", args.txid))
      .first();
    
    if (existing) {
      await ctx.db.patch(existing._id, args);
      return existing._id;
    }
    
    return await ctx.db.insert("transactions", args);
  },
});

export const upsertAddress = mutation({
  args: {
    address: v.string(),
    totalReceived: v.number(),
    totalSent: v.number(),
    txCount: v.number(),
    firstSeen: v.number(),
    lastSeen: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("addresses")
      .withIndex("by_address", (q) => q.eq("address", args.address))
      .first();
    
    if (existing) {
      await ctx.db.patch(existing._id, {
        totalReceived: args.totalReceived,
        totalSent: args.totalSent,
        txCount: args.txCount,
        lastSeen: args.lastSeen,
      });
      return existing._id;
    }
    
    return await ctx.db.insert("addresses", args);
  },
});

export const updateNetworkStats = mutation({
  args: {
    blockHeight: v.number(),
    difficulty: v.number(),
    hashrate: v.number(),
    totalSupply: v.number(),
    totalTransactions: v.number(),
    totalAddresses: v.number(),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("networkStats", {
      ...args,
      updatedAt: Date.now(),
    });
  },
});

export const updateIndexerState = mutation({
  args: {
    lastIndexedHeight: v.number(),
    lastIndexedHash: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("indexerState")
      .withIndex("by_key", (q) => q.eq("key", "main"))
      .first();
    
    const data = {
      key: "main",
      lastIndexedHeight: args.lastIndexedHeight,
      lastIndexedHash: args.lastIndexedHash,
      updatedAt: Date.now(),
    };
    
    if (existing) {
      await ctx.db.patch(existing._id, data);
      return existing._id;
    }
    
    return await ctx.db.insert("indexerState", data);
  },
});

export const getIndexerState = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("indexerState")
      .withIndex("by_key", (q) => q.eq("key", "main"))
      .first();
  },
});
