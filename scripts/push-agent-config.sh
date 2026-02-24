#!/bin/bash
# Push current agent defaults as a versioned snapshot
# Usage: ./scripts/push-agent-config.sh "Added diverse search queries"
# Requires the dev server running locally (or set BASE_URL for deployed)

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000}"
AGENT_ID="${AGENT_ID:-sdk-tutor}"
NOTE="${1:-}"

if [ -z "$NOTE" ]; then
  echo "Usage: $0 \"description of what changed\""
  exit 1
fi

echo "Fetching current config for $AGENT_ID..."
CONFIG=$(curl -s "$BASE_URL/api/agents/config/$AGENT_ID")

SYSTEM_PROMPT=$(echo "$CONFIG" | jq -r '.systemPrompt')
ALLOWED_TOOLS=$(echo "$CONFIG" | jq -c '.allowedTools')

if [ "$SYSTEM_PROMPT" = "null" ] || [ -z "$SYSTEM_PROMPT" ]; then
  echo "Error: Could not fetch config. Is the dev server running at $BASE_URL?"
  exit 1
fi

echo "Creating version snapshot (source: code)..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/agents/config/$AGENT_ID/versions" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg prompt "$SYSTEM_PROMPT" \
    --argjson tools "$ALLOWED_TOOLS" \
    --arg note "$NOTE" \
    '{systemPrompt: $prompt, allowedTools: $tools, source: "code", note: $note}'
  )")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "201" ]; then
  VERSION_ID=$(echo "$BODY" | jq -r '.id')
  echo "Version created: $VERSION_ID"
  echo "Note: $NOTE"
else
  echo "Error ($HTTP_CODE): $BODY"
  exit 1
fi
