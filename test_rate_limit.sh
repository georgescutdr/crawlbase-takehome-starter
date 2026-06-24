#!/bin/bash

set -e

URL="http://localhost:8080/track"
TOKEN="test123"

SUCCESS=0
BLOCKED=0

echo "Testing rate limit (65 requests)..."
echo "-----------------------------------"

for i in {1..65}; do
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$URL" \
    -H "X-Api-Token: $TOKEN")

  echo "$i -> $status"

  if [ "$status" -eq 200 ]; then
    SUCCESS=$((SUCCESS+1))
  else
    BLOCKED=$((BLOCKED+1))
  fi
done

echo "-----------------------------------"
echo "Success: $SUCCESS"
echo "Blocked: $BLOCKED"