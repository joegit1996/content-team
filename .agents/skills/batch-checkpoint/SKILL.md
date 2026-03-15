# Batch Checkpoint

Manage batch files for large-scale data collection with checkpointing, progress tracking, and fault-tolerant writes.

## When to Use

Use this skill when collecting data at scale and you need to:
- Write results in batches to avoid data loss
- Checkpoint progress for resumable collection
- Track progress across multiple researchers
- Merge batches for validation

## Batch File Format

Each batch file follows this structure:

```json
{
  "batch_id": "batch-R{researcher_number}-{sequence}",
  "researcher": "researcher-{number}",
  "schema_version": "1.0",
  "collected_at": "2026-03-15T12:00:00Z",
  "items": [],
  "progress": {
    "scope": "description of assigned scope",
    "completed": 25,
    "estimated_total": 100,
    "status": "in_progress|complete",
    "last_checkpoint": "2026-03-15T12:30:00Z"
  }
}
```

## Naming Convention

```
workspace/raw/batch-R{researcher}-{sequence}.json

Examples:
  batch-R1-001.json   # Researcher 1, first batch
  batch-R1-002.json   # Researcher 1, second batch
  batch-R3-001.json   # Researcher 3, first batch
```

## Checkpoint Strategy

### When to Checkpoint

| Collection Size | Checkpoint Every |
|---|---|
| ≤50 items | 10 items |
| 51-200 items | 25 items |
| 201-1000 items | 50 items |
| 1000+ items | 100 items |

### How to Checkpoint

1. Write the current batch with `status: "in_progress"` and the current item count
2. Continue collecting into the same batch object in memory
3. Overwrite the batch file at the next checkpoint
4. When the batch reaches max size (100 items), finalize it and start a new batch file

```python
import json
from datetime import datetime, timezone

class BatchWriter:
    def __init__(self, researcher_id, scope, output_dir="workspace/raw"):
        self.researcher_id = researcher_id
        self.scope = scope
        self.output_dir = output_dir
        self.sequence = 1
        self.items = []
        self.checkpoint_interval = 25
        self.max_batch_size = 100
        self.estimated_total = 0

    def add_item(self, item):
        self.items.append(item)

        if len(self.items) % self.checkpoint_interval == 0:
            self.checkpoint()

        if len(self.items) >= self.max_batch_size:
            self.finalize()

    def checkpoint(self):
        self._write_batch("in_progress")

    def finalize(self):
        self._write_batch("complete")
        self.sequence += 1
        self.items = []

    def _write_batch(self, status):
        batch = {
            "batch_id": f"batch-R{self.researcher_id}-{self.sequence:03d}",
            "researcher": f"researcher-{self.researcher_id}",
            "schema_version": "1.0",
            "collected_at": datetime.now(timezone.utc).isoformat(),
            "items": self.items,
            "progress": {
                "scope": self.scope,
                "completed": len(self.items),
                "estimated_total": self.estimated_total,
                "status": status,
                "last_checkpoint": datetime.now(timezone.utc).isoformat()
            }
        }

        filepath = f"{self.output_dir}/batch-R{self.researcher_id}-{self.sequence:03d}.json"
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(batch, f, ensure_ascii=False, indent=2)
```

## Merging Batches

To merge all batches for validation:

```python
import glob
import json

def merge_batches(raw_dir="workspace/raw"):
    all_items = []
    batch_sources = []

    for filepath in sorted(glob.glob(f"{raw_dir}/batch-*.json")):
        with open(filepath, encoding='utf-8') as f:
            batch = json.load(f)
            all_items.extend(batch.get('items', []))
            batch_sources.append({
                'file': filepath,
                'batch_id': batch['batch_id'],
                'researcher': batch['researcher'],
                'item_count': len(batch.get('items', [])),
                'status': batch['progress']['status']
            })

    return {
        'total_items': len(all_items),
        'batch_count': len(batch_sources),
        'batches': batch_sources,
        'items': all_items
    }
```

## Progress Tracking

To get overall collection progress:

```python
def get_collection_progress(raw_dir="workspace/raw"):
    batches = glob.glob(f"{raw_dir}/batch-*.json")
    total_items = 0
    total_estimated = 0
    researchers = {}

    for filepath in batches:
        with open(filepath, encoding='utf-8') as f:
            batch = json.load(f)
            items = len(batch.get('items', []))
            total_items += items
            progress = batch.get('progress', {})
            researcher = batch['researcher']

            if researcher not in researchers:
                researchers[researcher] = {
                    'scope': progress.get('scope'),
                    'completed': 0,
                    'estimated': progress.get('estimated_total', 0),
                    'status': progress.get('status')
                }
            researchers[researcher]['completed'] += items
            researchers[researcher]['status'] = progress.get('status')

    return {
        'total_collected': total_items,
        'researchers': researchers
    }
```

## Rules

1. **Never overwrite another researcher's batch** — each researcher writes only to their own `R{n}` prefix
2. **Always checkpoint** — partial data is better than lost data
3. **Max 100 items per batch file** — keeps files manageable and allows incremental validation
4. **UTF-8 encoding** with `ensure_ascii=False` for proper Arabic/Unicode support
5. **Atomic writes** — write to a temp file then rename, to prevent corruption on interruption
6. **Include progress metadata** — so the lead can monitor collection status
