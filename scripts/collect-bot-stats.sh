#!/usr/bin/env bash
# Collect bot network stats and write to JSON for rizz.dad/bots
set -euo pipefail

KEY="/var/lib/loom-server/secrets/contabo/mining-fleet"
OUTPUT="/root/journal/site/public/data/bot-stats.json"

NODES=(
  "1:95.111.227.14"
  "2:95.111.229.108"
  "3:95.111.239.142"
  "4:161.97.83.147"
  "5:161.97.97.83"
  "6:161.97.114.192"
  "7:161.97.117.0"
  "8:194.163.144.177"
  "9:185.218.126.23"
  "10:185.239.209.227"
)

# Get Botcoin stats from node 1
# NOTE: Do not rely on PATH or botcoin-cli on the remote host.
# Use cookie-authenticated JSON-RPC directly so this works even when PATH is minimal.
echo "Fetching Botcoin stats..."
BOT_RPCPORT=18433
BOT_DATADIR="/root/.botcoin-light"

BOT_JSON=$(ssh -i "$KEY" -o ConnectTimeout=8 -o StrictHostKeyChecking=no root@95.111.227.14 \
  "BOT_DATADIR='$BOT_DATADIR' BOT_RPCPORT='$BOT_RPCPORT' bash -s" <<'EOF' 2>/dev/null || echo '{}'
set -euo pipefail
COOKIE_FILE="${BOT_DATADIR}/.cookie"
if [ ! -f "$COOKIE_FILE" ]; then
  echo '{}'
  exit 0
fi
COOKIE=$(cat "$COOKIE_FILE")
U=${COOKIE%:*}
P=${COOKIE#*:}

curl -s --user "$U:$P" \
  --data-binary '{"jsonrpc":"1.0","id":"b","method":"getblockchaininfo","params":[]}' \
  -H 'content-type:text/plain;' \
  http://127.0.0.1:${BOT_RPCPORT}/
EOF
)

BOT_BLOCKS=$(echo "$BOT_JSON" | jq -r '.result.blocks // 0')
BOT_DIFF=$(echo "$BOT_JSON" | jq -r '.result.difficulty // 0')

BOT_PEERS=$(ssh -i "$KEY" -o ConnectTimeout=8 -o StrictHostKeyChecking=no root@95.111.227.14 \
  "BOT_DATADIR='$BOT_DATADIR' BOT_RPCPORT='$BOT_RPCPORT' bash -s" <<'EOF' 2>/dev/null || echo '0'
set -euo pipefail
COOKIE_FILE="${BOT_DATADIR}/.cookie"
if [ ! -f "$COOKIE_FILE" ]; then
  echo 0
  exit 0
fi
COOKIE=$(cat "$COOKIE_FILE")
U=${COOKIE%:*}
P=${COOKIE#*:}

curl -s --user "$U:$P" \
  --data-binary '{"jsonrpc":"1.0","id":"c","method":"getconnectioncount","params":[]}' \
  -H 'content-type:text/plain;' \
  http://127.0.0.1:${BOT_RPCPORT}/ \
  | jq -r '.result // 0'
EOF
)
# Get Bonero stats from node 10
echo "Fetching Bonero stats..."
BONER_JSON=$(ssh -i "$KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@185.239.209.227 \
  "curl -s http://127.0.0.1:18081/json_rpc -d '{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_info\"}' -H 'Content-Type: application/json'" 2>/dev/null || echo '{}')

BONER_HEIGHT=$(echo "$BONER_JSON" | jq -r '.result.height // 0')
BONER_DIFF=$(echo "$BONER_JSON" | jq -r '.result.difficulty // 0')
BONER_HASHRATE=$(echo "$BONER_JSON" | jq -r '.result.difficulty // 0')  # Approximate
BONER_IN=$(echo "$BONER_JSON" | jq -r '.result.incoming_connections_count // 0')
BONER_OUT=$(echo "$BONER_JSON" | jq -r '.result.outgoing_connections_count // 0')

# Check fleet status
echo "Checking fleet status..."
FLEET_JSON="["
NODES_ONLINE=0
for entry in "${NODES[@]}"; do
  ID="${entry%%:*}"
  IP="${entry#*:}"
  
  STATUS="offline"

  # SSH can occasionally reset; retry a few times before declaring offline.
  for _try in 1 2 3; do
    if ssh -i "$KEY" -o ConnectTimeout=8 -o StrictHostKeyChecking=no root@$IP \
      "(pgrep -x botcoind-v2.1 >/dev/null 2>&1) || (pgrep -x botcoind >/dev/null 2>&1)" \
      2>/dev/null; then
      STATUS="online"
      ((NODES_ONLINE++)) || true
      break
    fi
    sleep 1
  done
  
  [ "$FLEET_JSON" != "[" ] && FLEET_JSON+=","
  FLEET_JSON+="{\"id\":$ID,\"ip\":\"$IP\",\"status\":\"$STATUS\"}"
done
FLEET_JSON+="]"

# Build final JSON
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$OUTPUT" << EOF
{
  "timestamp": "$TIMESTAMP",
  "botcoin": {
    "blocks": $BOT_BLOCKS,
    "difficulty": $BOT_DIFF,
    "peers": $BOT_PEERS,
    "nodes_online": $NODES_ONLINE
  },
  "bonero": {
    "height": $BONER_HEIGHT,
    "difficulty": $BONER_DIFF,
    "hashrate": $BONER_HASHRATE,
    "incoming_connections": $BONER_IN,
    "outgoing_connections": $BONER_OUT
  },
  "fleet": $FLEET_JSON
}
EOF

echo "Stats written to $OUTPUT"
cat "$OUTPUT" | jq .
