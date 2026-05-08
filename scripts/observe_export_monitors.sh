#!/usr/bin/env bash
# Usage: ./observe_export_monitors.sh <customer_id> <token> [domain]
# Example (no domain): ./observe_export_monitors.sh 154507918603 mytoken123
# Example (with domain): ./observe_export_monitors.sh 154507918603 mytoken123 eu-1
# Requires: curl, jq

CUSTOMER_ID="${1}"
TOKEN="${2}"
DOMAIN="${3}"
OUTPUT="observe_monitors_$(date +%Y-%m-%d).json"

if [[ -z "$CUSTOMER_ID" || -z "$TOKEN" ]]; then
  echo "Usage: $0 <customer_id> <token> [domain]" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install via: brew install jq" >&2
  exit 1
fi

if [[ -n "$DOMAIN" ]]; then
  HOST="${CUSTOMER_ID}.${DOMAIN}.observeinc.com"
else
  HOST="${CUSTOMER_ID}.observeinc.com"
fi

AUTH="Bearer ${CUSTOMER_ID} ${TOKEN}"
BASE_URL="https://${HOST}/v1/monitors"

echo "Fetching monitor list from ${BASE_URL} ..."

LIST_JSON=$(curl -sf "${BASE_URL}" \
  -H "Authorization: ${AUTH}" \
  -H "Content-Type: application/json")

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to fetch monitor list." >&2
  exit 1
fi

TOTAL=$(echo "${LIST_JSON}" | jq 'length')
if [[ "$TOTAL" -eq 0 ]]; then
  echo "No monitors found."
  echo "[]" > "${OUTPUT}"
  exit 0
fi

echo "Found ${TOTAL} monitors. Fetching details..."

MONITOR_IDS=$(echo "${LIST_JSON}" | jq -r '.[].id')
FETCHED=0
ERRORS=0
TMPDIR_WORK=$(mktemp -d)

while IFS= read -r ID; do
  [[ -z "$ID" ]] && continue
  DETAIL=$(curl -sf "${BASE_URL}/${ID}" \
    -H "Authorization: ${AUTH}" \
    -H "Content-Type: application/json")
  if [[ $? -eq 0 ]]; then
    echo "${DETAIL}" > "${TMPDIR_WORK}/${ID}.json"
    FETCHED=$((FETCHED + 1))
  else
    echo "  Warning: failed to fetch monitor ${ID}" >&2
    ERRORS=$((ERRORS + 1))
  fi
  echo "  [${FETCHED}/${TOTAL}] ${ID}"
done <<< "${MONITOR_IDS}"

jq -s '.' "${TMPDIR_WORK}"/*.json > "${OUTPUT}"

rm -rf "${TMPDIR_WORK}"

echo ""
echo "Done. ${FETCHED} monitors exported to ${OUTPUT} (${ERRORS} errors)"
