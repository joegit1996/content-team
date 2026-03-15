# Multi-Entity Schema

Define and collect data with parent-child entity relationships — e.g., a restaurant (parent) has many menu items (children), a company has many job listings, a hotel has many rooms.

## When to Use

Use this skill when the user's prompt implies related entities:
- "Get restaurants **and their menu items**"
- "Find companies **and their job listings**"
- "List hotels **and their room types with prices**"
- "Get universities **and their programs**"

## Schema Extension

Multi-entity schemas extend the standard schema with a `relations` section:

```json
{
  "name": "kuwait-restaurants-with-menus",
  "description": "Restaurants in Kuwait with their full menu",
  "version": "1.0",
  "entities": {
    "restaurant": {
      "is_root": true,
      "fields": [
        { "key": "id", "type": "string", "required": true },
        { "key": "name_en", "type": "string", "required": true },
        { "key": "name_ar", "type": "string", "required": true },
        { "key": "logo_url", "type": "image_url", "required": true }
      ]
    },
    "menu_item": {
      "is_root": false,
      "fields": [
        { "key": "id", "type": "string", "required": true },
        { "key": "parent_id", "type": "string", "required": true },
        { "key": "name_en", "type": "string", "required": true },
        { "key": "name_ar", "type": "string", "required": true },
        { "key": "price", "type": "number", "required": true },
        { "key": "category", "type": "string", "required": true },
        { "key": "image_url", "type": "image_url", "required": false }
      ]
    }
  },
  "relations": [
    {
      "parent": "restaurant",
      "child": "menu_item",
      "type": "one_to_many",
      "foreign_key": "parent_id",
      "description": "A restaurant has many menu items"
    }
  ],
  "metadata": {
    "entity": "restaurant",
    "region": "KW",
    "estimated_count": {
      "restaurant": 50,
      "menu_item": 2500
    }
  }
}
```

## Key Concepts

### Entity Types

- **Root entity**: The primary thing being collected (restaurant, company, hotel). Collected first.
- **Child entity**: Related data belonging to a root entity (menu items, jobs, rooms). Collected after the root entity, using `parent_id` to link back.

### Relationship Types

| Type | Meaning | Example |
|---|---|---|
| `one_to_many` | One parent has many children | Restaurant → Menu Items |
| `one_to_one` | One parent has one child | Company → Contact Info |
| `many_to_many` | Many-to-many through a join | Products ↔ Categories |

Most content collection scenarios are `one_to_many`.

### ID Linking

Children reference their parent via `parent_id`:

```json
// Parent
{ "id": "kw-rest-001", "name_en": "Mais Alghanim", ... }

// Children
{ "id": "kw-menu-001", "parent_id": "kw-rest-001", "name_en": "Machboos Chicken", "price": 3.5 }
{ "id": "kw-menu-002", "parent_id": "kw-rest-001", "name_en": "Grilled Hammour", "price": 5.0 }
```

### ID Convention

```
{region}-{entity_type_short}-{number}

Parents:  kw-rest-001, kw-rest-002
Children: kw-menu-001, kw-menu-002, ... kw-menu-150
```

## Collection Strategy

### Two-Phase Collection

**Phase A: Collect root entities**
1. Researchers collect all parent entities first
2. Validate parents
3. Approved parents become the input for Phase B

**Phase B: Collect child entities**
1. For each parent, researchers collect its children
2. Scope assignment is per-parent: "Researcher 1 gets restaurants 1-10, Researcher 2 gets 11-20"
3. Children reference their parent via `parent_id`

### Batch File Format for Multi-Entity

```json
{
  "batch_id": "batch-R1-001",
  "researcher": "researcher-1",
  "entity_type": "menu_item",
  "schema_version": "1.0",
  "collected_at": "2026-03-15T12:00:00Z",
  "items": [
    {
      "id": "kw-menu-001",
      "parent_id": "kw-rest-001",
      "name_en": "Machboos Chicken",
      "name_ar": "مجبوس دجاج",
      "price": 3.500,
      "category": "Main Course",
      "image_url": "https://..."
    }
  ],
  "progress": {
    "scope": "menu items for kw-rest-001 through kw-rest-005",
    "completed": 87,
    "estimated_total": 250,
    "status": "in_progress"
  }
}
```

## Validation

### Referential Integrity

The validator must check:

```python
def validate_references(parents: list, children: list) -> list:
    """Ensure every child references a valid parent."""
    parent_ids = {p["id"] for p in parents}
    orphans = []

    for child in children:
        parent_id = child.get("parent_id")
        if parent_id not in parent_ids:
            orphans.append({
                "child_id": child["id"],
                "parent_id": parent_id,
                "issue": "parent not found"
            })

    return orphans
```

### Count Validation

Check that each parent has at least one child (unless optional):

```python
def validate_coverage(parents: list, children: list,
                      min_children: int = 1) -> list:
    """Check that each parent has children."""
    parent_ids = {p["id"] for p in parents}
    children_by_parent = {}

    for child in children:
        pid = child.get("parent_id")
        children_by_parent.setdefault(pid, []).append(child)

    gaps = []
    for pid in parent_ids:
        count = len(children_by_parent.get(pid, []))
        if count < min_children:
            gaps.append({
                "parent_id": pid,
                "child_count": count,
                "issue": f"fewer than {min_children} children"
            })

    return gaps
```

## Output Structure

### Validated Output

For multi-entity schemas, `validated.json` is structured by entity type:

```json
{
  "schema": "kuwait-restaurants-with-menus v1.0",
  "validated_at": "2026-03-15T12:00:00Z",
  "entities": {
    "restaurant": {
      "total": 50,
      "items": [ ... ]
    },
    "menu_item": {
      "total": 2500,
      "items": [ ... ]
    }
  },
  "relations_valid": true,
  "orphaned_children": 0,
  "parents_without_children": 2,
  "stats": {
    "restaurant": { "valid": 50, "gaps": 0 },
    "menu_item": { "valid": 2480, "gaps": 20 }
  }
}
```

### CSV Export

For multi-entity data, export **one CSV per entity type**:

```
workspace/export/restaurants.csv    # Parent entities
workspace/export/menu_items.csv     # Child entities (with parent_id column)
```

Or a **denormalized single CSV** if the user prefers:

```
workspace/export/data_denormalized.csv
# Each row = one child, with parent fields repeated
# restaurant_id, restaurant_name_en, menu_item_id, menu_item_name_en, price, ...
```

Ask the user which format they prefer.

### API Push

When pushing multi-entity data to an API:

1. **Push parents first** — create all restaurants
2. **Map returned IDs** — if the API assigns its own IDs, map them to parent_ids
3. **Push children second** — create menu items with the API's parent IDs
4. **Report per-entity** — show success/failure counts for each entity type

## Detection: Is This a Multi-Entity Request?

Look for these signals in the user's prompt:

| Signal | Interpretation |
|---|---|
| "and their menu items" | Parent: restaurant, Child: menu_item |
| "with all products" | Parent: store/brand, Child: product |
| "including job listings" | Parent: company, Child: job |
| "and room types" | Parent: hotel, Child: room |
| "with their branches" | Parent: company, Child: branch |
| "and reviews" | Parent: business, Child: review |
| "get the full menu" | Parent: restaurant, Child: menu_item |

If detected, create a multi-entity schema instead of a single-entity one.

## Rules

1. **Always collect parents first, then children** — never collect orphaned children
2. **Every child must have a `parent_id`** — referential integrity is mandatory
3. **Scope child collection per-parent** — assign researchers groups of parents, not random children
4. **Separate batch files by entity type** — don't mix parents and children in the same batch
5. **Export one file per entity** for CSV — or offer denormalized option
6. **Push parents before children** to APIs — order matters for foreign keys
7. **Validate referential integrity** — flag orphans and parents without children
