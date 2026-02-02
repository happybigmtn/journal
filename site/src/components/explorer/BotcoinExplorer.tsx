"use client";

import { useState, useEffect } from "react";

interface Block {
  height: number;
  hash: string;
  time: number;
  txCount: number;
}

interface Stats {
  blocks: number;
  difficulty: number;
  peers: number;
  miners: number;
  timestamp: number;
  latestBlocks: Block[];
}

function formatAge(timestamp: number): string {
  const seconds = Math.floor(Date.now() / 1000 - timestamp);
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

export function BotcoinExplorer() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const res = await fetch("/data/bot-stats.json");
        if (!res.ok) throw new Error("Stats not available");
        const data = await res.json();
        setStats(data);
        setError(null);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to fetch");
      } finally {
        setLoading(false);
      }
    }
    fetchData();
    const interval = setInterval(fetchData, 60000);
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
            <span className="stat-value">{stats?.blocks?.toLocaleString() ?? "-"}</span>
          </div>
          <div className="stat-card">
            <span className="stat-label">Difficulty</span>
            <span className="stat-value">{stats?.difficulty?.toExponential(2) ?? "-"}</span>
          </div>
          <div className="stat-card">
            <span className="stat-label">Connected Peers</span>
            <span className="stat-value">{stats?.peers ?? "-"}</span>
          </div>
          <div className="stat-card">
            <span className="stat-label">Active Miners</span>
            <span className="stat-value">{stats?.miners ?? "-"}</span>
          </div>
        </div>
        {stats?.timestamp && (
          <p className="last-updated">Updated: {formatAge(stats.timestamp)}</p>
        )}
      </section>

      {/* Latest Blocks */}
      {stats?.latestBlocks && stats.latestBlocks.length > 0 && (
        <section className="blocks-section">
          <h2>Latest Blocks</h2>
          <div className="blocks-table">
            <div className="table-header">
              <span>Height</span>
              <span>Hash</span>
              <span>Txs</span>
              <span>Age</span>
            </div>
            {stats.latestBlocks.map((block) => (
              <div key={block.hash} className="table-row">
                <span className="height">{block.height}</span>
                <span className="hash">{block.hash.slice(0, 16)}...</span>
                <span className="txs">{block.txCount}</span>
                <span className="age">{formatAge(block.time)}</span>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
