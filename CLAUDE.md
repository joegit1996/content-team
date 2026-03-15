# Content Stock Team

An agent team that researches, structures, collects, and delivers content data at scale.

## Overview

This system takes a natural language prompt describing what content/data to collect, proposes a schema, collects the data using web research, validates it, and delivers it to the user's chosen destination (API, database, CSV).

## Team Roles

### Lead (Orchestrator)
- Receives user prompts and coordinates the pipeline
- Presents schemas for user approval
- Manages task assignment and progress
- Synthesizes final results

### Schema Architect
- Parses user prompts into structured JSON schemas
- Considers locales, nested structures, media fields
- Outputs schema files with types, validation rules, examples
- Manages reusable schema templates in `schemas/templates/`

### Researcher (1-N, scales with workload)
- Searches the web for data matching the approved schema
- Scrapes individual pages for detailed fields
- Uses Playwright for JS-rendered content when needed
- Writes batched results to `workspace/raw/batch-{n}.json`
- Checkpoints progress to allow resumption

### Data Validator
- Reads all raw batches from researchers
- Validates against the approved schema
- Normalizes formats (dates, times, URLs, locales)
- Deduplicates entries
- Flags missing required fields with gap reports
- Outputs `workspace/validated.json` and `workspace/gaps.json`

### API Integrator
- Accepts any API/database target — fully dynamic
- Reads user-provided API specs (URL, auth, endpoints, field mapping)
- Can read Swagger/OpenAPI docs if provided
- Maps schema fields to API fields
- Batch inserts with retry and error reporting
- Also supports CSV/JSON file export
- Outputs delivery report to `workspace/delivery-report.json`

## Agent Skills

Each agent has specific skills installed. Skills provide reusable capabilities and domain knowledge.

| Agent | Skill | Source | Purpose |
|---|---|---|---|
| Schema Architect | `schema-from-prompt` | Custom | NLP prompt → JSON schema parsing |
| Researcher | `web-scraping` | [jamditis/claude-skills-journalism](https://skills.sh/jamditis/claude-skills-journalism/web-scraping) | Cascade scraping with fallback chain |
| Researcher | `apify-lead-generation` | [apify/agent-skills](https://skills.sh/apify/agent-skills/apify-lead-generation) | Platform scraping via Apify Actors |
| Researcher | `batch-checkpoint` | Custom | Batch file management and checkpointing |
| Data Validator | `data-cleaning-pipeline` | [aj-geddes/useful-ai-prompts](https://skills.sh/aj-geddes/useful-ai-prompts/data-cleaning-pipeline) | Systematic data cleaning pipeline |
| Data Validator | `arabic-text-processing` | Custom | Arabic Unicode normalization and validation |
| API Integrator | `api-integration` | [autumnsgrove/groveengine](https://skills.sh/autumnsgrove/groveengine/api-integration) | REST API auth, retry, rate limiting |
| API Integrator | `data-export` | Custom | CSV/JSON export with nested flattening |
| Researcher | `paginated-scraping` | Custom | Handle paginated listings — URL params, offset, cursor, infinite scroll |
| Researcher, Integrator | `image-downloader` | Custom | Download images to local storage, manifest tracking, integrity validation |
| Schema Architect, Validator, Integrator | `multi-entity-schema` | Custom | Parent-child entity relationships, referential integrity, multi-entity export |

Skills are located in `.agents/skills/` and symlinked to `.claude/skills/`.

## Directory Structure

```
content-stock-team/
├── CLAUDE.md                    # This file
├── .agents/skills/              # All skills (registry + custom)
│   ├── web-scraping/            # Registry: cascade scraping
│   ├── apify-lead-generation/   # Registry: platform scraping
│   ├── data-cleaning-pipeline/  # Registry: data cleaning
│   ├── api-integration/         # Registry: API integration
│   ├── schema-from-prompt/      # Custom: NLP → schema
│   ├── data-export/             # Custom: CSV/JSON export
│   ├── arabic-text-processing/  # Custom: Arabic text handling
│   ├── batch-checkpoint/        # Custom: batch management
│   ├── paginated-scraping/      # Custom: paginated listing pages
│   ├── image-downloader/        # Custom: download images locally
│   └── multi-entity-schema/     # Custom: parent-child relationships
├── .claude/skills/              # Symlinks to .agents/skills/
├── schemas/
│   └── templates/               # Reusable schema templates
├── workspace/                   # Runtime data (per-job)
│   ├── schema.json              # Approved schema for current job
│   ├── raw/                     # Researcher output batches
│   │   ├── batch-001.json
│   │   └── ...
│   ├── validated.json           # Validator output
│   ├── gaps.json                # Missing/incomplete data report
│   ├── export/                  # CSV/JSON exports
│   └── delivery-report.json     # API integration results
├── prompts/                     # Agent role prompts
│   ├── lead-orchestrator.md
│   ├── schema-architect.md
│   ├── researcher.md
│   ├── data-validator.md
│   └── api-integrator.md
└── scripts/
    ├── validate-batch.sh        # Hook: validate researcher output
    └── merge-batches.sh         # Merge raw batches for validator
```

## Workflow

### Phase 1: Schema Generation
1. User provides a natural language prompt describing what to collect
2. Lead sends prompt to Schema Architect
3. Schema Architect outputs `workspace/schema.json`
4. Lead presents schema to user for review/editing
5. User approves (or edits and approves)

### Phase 2: Research & Collection
1. Lead calculates researcher count based on estimated volume
   - Up to 100 items: 1 researcher
   - 100-1000 items: 2-3 researchers
   - 1000-5000 items: 3-5 researchers
   - 5000-10000 items: 5-8 researchers
2. Lead assigns non-overlapping search scopes to each researcher
3. Researchers write batches to `workspace/raw/batch-{n}.json`
4. Each batch file contains an array of objects matching the schema
5. Researchers checkpoint progress (write partial batches on interruption)

### Phase 3: Validation
1. Data Validator reads all batches from `workspace/raw/`
2. Validates each entry against `workspace/schema.json`
3. Normalizes and deduplicates
4. Outputs `workspace/validated.json` (clean data)
5. Outputs `workspace/gaps.json` (entries with issues)
6. Lead presents summary to user: "Found X entries, Y complete, Z with gaps"

### Phase 4: Delivery
User chooses one of:
- **CSV Export**: API Integrator writes to `workspace/export/data.csv`
- **JSON Export**: API Integrator writes to `workspace/export/data.json`
- **API Push**: User provides API details, Integrator maps and pushes
- **Database Insert**: User provides connection details, Integrator inserts

## Schema Format

Schemas follow this structure:

```json
{
  "name": "template-name",
  "description": "What this schema collects",
  "version": "1.0",
  "fields": [
    {
      "key": "field_name",
      "type": "string|number|url|image_url|email|phone|time|date|boolean|array|object",
      "required": true,
      "description": "Human-readable description",
      "locale": "ar|en|null",
      "example": "example value",
      "children": []
    }
  ],
  "metadata": {
    "entity": "business|product|person|place|event",
    "region": "KW|SA|AE|...",
    "estimated_count": 500,
    "sources_hint": ["google maps", "instagram", "website directories"]
  }
}
```

## Batch File Format

Each researcher writes batches like:

```json
{
  "batch_id": "batch-001",
  "researcher": "researcher-1",
  "schema_version": "1.0",
  "collected_at": "2026-03-09T12:00:00Z",
  "items": [
    { ...schema-conforming object... }
  ],
  "progress": {
    "scope": "businesses A-F",
    "completed": 45,
    "estimated_total": 100,
    "status": "in_progress|complete"
  }
}
```

## Conventions

- All data files are JSON unless exporting to CSV
- UTF-8 encoding everywhere (critical for Arabic content)
- Image fields store URLs, not binary data
- Time fields use 24h format: "HH:MM"
- All timestamps are ISO 8601
- Researchers must not overlap scopes — lead assigns non-overlapping ranges
- Batch files are append-only; researchers never overwrite another's batch
- The `workspace/` directory is ephemeral per job; schemas in `schemas/templates/` persist

## Scaling Strategy

For large collections (1000+ items):
1. Researchers work in parallel on non-overlapping scopes
2. Each researcher writes batches of ~100 items max per file
3. Researchers checkpoint every 25 items (write partial batch)
4. Validator processes batches incrementally as they arrive
5. Lead monitors progress and can reassign stalled scopes

## Error Handling

- Researcher can't find data for a scope → writes empty batch with status note
- API push fails for some items → Integrator retries 3x, then logs to delivery report
- Schema mismatch → Validator flags and excludes from validated.json, includes in gaps.json
- Rate limiting → Researchers back off and note in progress field
