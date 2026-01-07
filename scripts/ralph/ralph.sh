#!/bin/bash
set -e

# Usage: ralph.sh [iterations] [-v|--verbose]
MAX_ITERATIONS=10
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose) VERBOSE=true; shift ;;
    [0-9]*) MAX_ITERATIONS=$1; shift ;;
    *) shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
DIM='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Filter function to extract readable output from stream-json
filter_output() {
  while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Parse JSON and extract relevant info
    type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

    case "$type" in
      "assistant")
        # Show assistant text messages (trimmed)
        msg=$(echo "$line" | jq -r '.message.content[]? | select(.type=="text") | .text // empty' 2>/dev/null | head -c 200)
        [[ -n "$msg" ]] && echo -e "${CYAN}▸${NC} ${msg}"
        ;;
      "user")
        # Show todo updates
        todos=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_result") | .content // empty' 2>/dev/null)
        if [[ "$todos" == *"in_progress"* ]]; then
          task=$(echo "$todos" | jq -r '.[] | select(.status=="in_progress") | .content' 2>/dev/null | head -1)
          [[ -n "$task" ]] && echo -e "${YELLOW}⚡${NC} ${task}"
        fi
        ;;
      "result")
        # Show tool completions briefly
        tool=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)
        case "$tool" in
          "Write"|"Edit")
            file=$(echo "$line" | jq -r '.result // empty' 2>/dev/null | grep -o '[^/]*$' | head -1)
            [[ -n "$file" ]] && echo -e "${GREEN}✓${NC} ${DIM}wrote${NC} $file"
            ;;
          "Bash")
            echo -e "${DIM}…${NC} ${DIM}ran command${NC}"
            ;;
        esac
        ;;
    esac
  done
}

echo -e "${BOLD}🚀 Starting Ralph${NC}"
echo ""

RAWFILE=$(mktemp)
trap "rm -f $RAWFILE" EXIT

for i in $(seq 1 $MAX_ITERATIONS); do
  echo -e "${BOLD}═══ Iteration $i/$MAX_ITERATIONS ═══${NC}"

  if $VERBOSE; then
    # Verbose: show raw stream-json output
    claude --dangerously-skip-permissions --verbose \
      --output-format stream-json \
      -p "$(cat "$SCRIPT_DIR/prompt.md")" 2>&1 \
      | tee "$RAWFILE" || true
  else
    # Concise: filter to readable summaries
    claude --dangerously-skip-permissions \
      --output-format stream-json \
      -p "$(cat "$SCRIPT_DIR/prompt.md")" 2>&1 \
      | tee "$RAWFILE" \
      | filter_output || true
  fi

  echo ""

  if grep -q "<promise>COMPLETE</promise>" "$RAWFILE"; then
    echo -e "${GREEN}✅ Done!${NC}"
    exit 0
  fi

  sleep 2
done

echo -e "${YELLOW}⚠️ Max iterations reached${NC}"
exit 1
