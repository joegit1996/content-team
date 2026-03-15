# Data Export

Export structured data to CSV, JSON, or other flat file formats with support for nested data flattening, multi-locale content, and Excel-compatible encoding.

## When to Use

Use this skill when you need to export collected and validated data to a file format for delivery or analysis.

## Supported Formats

### CSV Export

1. **UTF-8 BOM**: Always prepend `\xEF\xBB\xBF` for Excel compatibility with Arabic/Unicode text
2. **Flatten nested structures**: Convert arrays and objects into flat columns

#### Flattening Rules

**Arrays of objects** (e.g., `working_hours`):
```
working_hours: [{day: "Sunday", start: "09:00", end: "22:00"}, ...]
→ hours_sunday_start, hours_sunday_end, hours_monday_start, hours_monday_end, ...
```

Pattern: `{parent}_{child_key_value}_{sibling_key}`

**Nested objects** (e.g., `address`):
```
address: {street: "123 Main", city: "Kuwait City", zip: "12345"}
→ address_street, address_city, address_zip
```

Pattern: `{parent}_{child_key}`

**Arrays of primitives** (e.g., `tags`):
```
tags: ["restaurant", "delivery", "kuwaiti"]
→ tags (joined with semicolons: "restaurant;delivery;kuwaiti")
```

3. **Quote all fields** containing commas, newlines, or double quotes
4. **Escape double quotes** by doubling them: `"` → `""`
5. **Column order**: id first, then user-defined fields alphabetically, then system fields (source_url, collected_at) last

### JSON Export

1. Pretty-print with 2-space indent
2. Ensure `ensure_ascii=False` for proper Unicode output
3. Structure as an array of objects (not wrapped in a container)

### JSONL Export (Line-delimited JSON)

1. One JSON object per line
2. No trailing comma or newline at end
3. Useful for streaming large datasets

## Implementation

### Python CSV Export

```python
import csv
import json
import io

def export_csv(items, schema, output_path):
    """Export items to CSV with nested flattening and UTF-8 BOM."""

    # Flatten items
    flat_items = [flatten_item(item, schema) for item in items]

    # Get all columns from first item (or union of all items)
    columns = get_ordered_columns(flat_items)

    with open(output_path, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=columns, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        writer.writerows(flat_items)

def flatten_item(item, schema):
    """Flatten nested structures into dot-free column names."""
    flat = {}
    for key, value in item.items():
        if isinstance(value, list) and value and isinstance(value[0], dict):
            # Array of objects — e.g., working_hours
            for obj in value:
                identifier = obj.get('day', obj.get('name', '')).lower()
                for sub_key, sub_val in obj.items():
                    if sub_key != 'day' and sub_key != 'name':
                        flat[f"{key}_{identifier}_{sub_key}"] = sub_val
        elif isinstance(value, dict):
            # Nested object — e.g., address
            for sub_key, sub_val in value.items():
                flat[f"{key}_{sub_key}"] = sub_val
        elif isinstance(value, list):
            # Array of primitives — join with semicolons
            flat[key] = ';'.join(str(v) for v in value)
        else:
            flat[key] = value
    return flat
```

### Column Ordering

```python
def get_ordered_columns(flat_items):
    """Order: id first, user fields alpha, system fields last."""
    all_cols = set()
    for item in flat_items:
        all_cols.update(item.keys())

    system_fields = {'id', 'source_url', 'collected_at'}
    user_fields = sorted(all_cols - system_fields)

    ordered = ['id'] + user_fields
    for sf in ['source_url', 'collected_at']:
        if sf in all_cols:
            ordered.append(sf)
    return ordered
```

## Rules

1. Always use `utf-8-sig` encoding (includes BOM) for CSV files
2. Never truncate data — export all items
3. Flatten all nested structures — CSVs must be fully flat
4. Preserve Arabic/Unicode text exactly as-is
5. Use semicolons (not commas) to join array values within a CSV cell
6. Include a companion JSON export alongside CSV for lossless data access
7. Report row count and column count after export
