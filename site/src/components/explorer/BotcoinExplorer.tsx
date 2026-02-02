"use client";

import { useState, useEffect } from "react";

const CONVEX_URL = "http://5.161.124.82:3220";

interface Block {
  height: number;
  hash: string;
  timestamp: number;
  txCount: number;
  miner?: string;
  difficulty: number;
}

interface NetworkStats {
  blockHeight: number;
  hashrate: number;
  difficulty: number;
  totalSupply: number;
}

interface Miner {
  address: string;
  blocks: number;
}

async function convexQuery(fn: string, args: Record<string, unknown> = {}) {
  const res = await fetch(`${CONVEX_URL}/api/query`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path: `explorer:${fn}`, args }),
  });
  if (!res.ok) throw new Error(`Convex query failed: ${res.status}`);
  const data = await res.json();
  return data.value;
}

function formatAge(timestamp: number): string {
  const seconds = Math.floor(Date.now() / 1000 - timestamp);
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

export function BotcoinExplorer() {
  const [blocks, setBlocks] = useState<Block[]>([]);
  const [stats, setStats] = useState<NetworkStats | null>(null);
  const [miners, setMiners] = useState<Miner[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const [blocksData, statsData, minersData] = await Promise.all([
          convexQuery("getLatestBlocks", { limit: 10 }),
          convexQuery("getNetworkStats"),
          convexQuery("getTopMiners", { limit: 5 }),
        ]);
        setBlocks(blocksData || []);
        setStats(statsData);
        setMiners(minersData || []);
        setError(null);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to fetch data");
      } finally {
        setLoading(false);
      }
    }
    fetchData();
    const interval = setInterval(fetchData, 30000);
    return () => clearInterval(interval);
  }, []);

  if (loading) return <div className="loading">Loading explorer data...</div>;
  if (error) return <div className="error">Explorer offline: {error}</div>;

  return (
    <div className="explorer">
      {/* Network Stats */}
      <section className="stats-section">
        <h2>Network Stats</h2>
        <div className="stats-grid">
          <div className="stat-card">
            <span className="stat-label">Block Height</span>
            <span className="stat-value">{stats?.blockHeight?.toLocaleString() ?? "-"}</span>
          </div>
          <div className="stat-card">
            <span className="stat-label">Hashrate</span>
            <span className="stat-value">{stats?.hashrate ? `${stats.hashrate.toFixed(2)} H/s` : "-"}</span>
          </div>
          <div className="stat-card">
            <span className="stat-label">Difficulty</span>
            <span className="stat-value">{stats?.difficulty?.toExponential(2) ?? "-"}</span>
          </div>
          <div className="stat-card">
            <span className="stat-label">Total Supply</span>
            <span className="stat-value">
              {stats?.totalSupply ? `${(stats.totalSupply / 100000000).toLocaleString()} BOT` : "-"}
            </span>
          </div>
        </div>
      </section>

      {/* Latest Blocks */}
      <section className="blocks-section">
        <h2>Latest Blocks</h2>
        <div className="blocks-table">
          <div className="table-header">
            <span>Height</span>
            <span>Hash</span>
            <span>Miner</span>
            <span>Txs</span>
            <span>Age</span>
          </div>
          {blocks.map((block) => (
            <div key={block.hash} className="table-row">
              <span className="height">{block.height}</span>
              <span className="hash">{block.hash.slice(0, 16)}...</span>
              <span className="miner">
                {block.miner ? `${block.miner.slice(0, 12)}...` : "Unknown"}
              </span>
              <span className="txs">{block.txCount}</span>
              <span className="age">{formatAge(block.timestamp)}</span>
            </div>
          ))}
        </div>
      </section>

      {/* Top Miners */}
      <section className="miners-section">
        <h2>Top Miners</h2>
        <div className="miners-list">
          {miners.map((miner, i) => (
            <div key={miner.address} className="miner-row">
              <span className="rank">#{i + 1}</span>
              <span className="address">{miner.address.slice(0, 16)}...</span>
              <span className="blocks">{miner.blocks} blocks</span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
