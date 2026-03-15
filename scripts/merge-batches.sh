#!/usr/bin/env bash
# Merge all raw batch files into a single array for the validator
# Output: workspace/raw/merged.json

set -euo pipefail

WORKSPACE="$(dirname "$0")/../workspace"
RAW_DIR="$WORKSPACE/raw"
OUTPUT="$RAW_DIR/merged.json"

if [ ! -d "$RAW_DIR" ]; then
  echo "ERROR: No raw directory found"
  exit 1
fi

BATCH_FILES=$(find "$RAW_DIR" -name "batch-*.json" -type f | sort)
BATCH_COUNT=$(echo "$BATCH_FILES" | grep -c . || true)

if [ "$BATCH_COUNT" -eq 0 ]; then
  echo "No batch files to merge"
  exit 0
fi

python3 -c "
import json, glob, os

raw_dir = '$RAW_DIR'
all_items = []
batch_sources = []

for filepath in sorted(glob.glob(os.path.join(raw_dir, 'batch-*.json'))):
    with open(filepath) as f:
        batch = json.load(f)
        items = batch.get('items', [])
        all_items.extend(items)
        batch_sources.append({
            'file': os.path.basename(filepath),
            'batch_id': batch.get('batch_id'),
            'researcher': batch.get('researcher'),
            'item_count': len(items),
            'status': batch.get('progress', {}).get('status', 'unknown')
        })

merged = {
    'total_items': len(all_items),
    'batch_count': len(batch_sources),
    'batches': batch_sources,
    'items': all_items
}

with open('$OUTPUT', 'w', encoding='utf-8') as f:
    json.dump(merged, f, ensure_ascii=False, indent=2)

print(f'Merged {len(all_items)} items from {len(batch_sources)} batches into {os.path.basename(\"$OUTPUT\")}')
"
