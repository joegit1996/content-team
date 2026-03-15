#!/usr/bin/env bash
# Hook script: validates a researcher's batch file on TaskCompleted
# Exit 0 = pass, Exit 2 = fail with feedback

set -euo pipefail

WORKSPACE="$(dirname "$0")/../workspace"
SCHEMA="$WORKSPACE/schema.json"

# Check if schema exists
if [ ! -f "$SCHEMA" ]; then
  echo "ERROR: No schema found at $SCHEMA"
  exit 2
fi

# Check if any batch files exist
BATCH_COUNT=$(find "$WORKSPACE/raw" -name "batch-*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "$BATCH_COUNT" -eq 0 ]; then
  echo "WARNING: No batch files found in $WORKSPACE/raw/"
  exit 0
fi

# Validate latest batch file has required structure
LATEST_BATCH=$(ls -t "$WORKSPACE/raw"/batch-*.json 2>/dev/null | head -1)

if [ -z "$LATEST_BATCH" ]; then
  exit 0
fi

# Check JSON is valid
if ! python3 -c "import json; json.load(open('$LATEST_BATCH'))" 2>/dev/null; then
  echo "ERROR: Invalid JSON in $LATEST_BATCH"
  exit 2
fi

# Check required fields exist in batch
python3 -c "
import json, sys

with open('$LATEST_BATCH') as f:
    batch = json.load(f)

required = ['batch_id', 'researcher', 'items', 'progress']
missing = [k for k in required if k not in batch]

if missing:
    print(f'ERROR: Batch missing required fields: {missing}')
    sys.exit(2)

if not isinstance(batch['items'], list):
    print('ERROR: items must be an array')
    sys.exit(2)

print(f'OK: Batch {batch[\"batch_id\"]} has {len(batch[\"items\"])} items, status: {batch[\"progress\"].get(\"status\", \"unknown\")}')
"
