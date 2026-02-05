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
echo "Checking fleet status (parallel)..."
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

check_node() {
  local entry="$1"
  local id="${entry%%:*}"
  local ip="${entry#*:}"
  local status="offline"
  
  # Try SSH check (one attempt is usually enough if timeout works, but we can do a simple retry logic if needed)
  if ssh -i "$KEY" -o ConnectTimeout=8 -o StrictHostKeyChecking=no "root@$ip" \
    "(pgrep -x botcoind-v2.1 >/dev/null 2>&1) || (pgrep -x botcoind >/dev/null 2>&1)" \
    2>/dev/null; then
    status="online"
  fi
  
  echo "{\"id\":$id,\"ip\":\"$ip\",\"status\":\"$status\"}" > "$TMP_DIR/$id.json"
}

for entry in "${NODES[@]}"; do
  check_node "$entry" &
done

wait

# Assemble JSON from tmp files
# Sort by ID numerically to keep order stable
FLEET_JSON="["
FIRST=1
for i in {1..10}; do
  if [ -f "$TMP_DIR/$i.json" ]; then
    if [ "$FIRST" -eq 1 ]; then
      FIRST=0
    else
      FLEET_JSON+=","
    fi
    FLEET_JSON+=$(cat "$TMP_DIR/$i.json")
  fi
done
FLEET_JSON+="]"

# Count online nodes from the assembled JSON
NODES_ONLINE=$(echo "$FLEET_JSON" | jq '[.[] | select(.status=="online")] | length')

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
