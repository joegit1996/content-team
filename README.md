# Content Stock Team

An AI agent team that collects structured content data at scale. Describe what you want in plain language, review the proposed schema, and get your data delivered as CSV, JSON, or pushed to any API/database.

Built with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) Agent Teams.

## What It Does

```
You: "Find me 10 online restaurants in Kuwait — name in Arabic and English, logo, and working hours per day"

Schema Architect  →  proposes a data schema  →  you review/edit  →  approve
Researchers       →  collect data from the web in parallel batches
Validator         →  cleans, normalizes Arabic text, deduplicates, flags gaps
Integrator        →  exports to CSV / JSON / pushes to any API or database
```

## Getting Started

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- Agent teams enabled — add this to `~/.claude/settings.json`:
  ```json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```
- tmux or iTerm2 (optional, for split-pane view of teammates)

### Install

```bash
git clone https://github.com/joegit1996/content-team.git
cd content-team
claude
```

### Run

Once Claude Code is open, start the team:

```
Create a content stock team. Read prompts/lead-orchestrator.md for your coordination instructions.
```

Then give it your content prompt:

```
Find me online businesses in Kuwait — get the name in Arabic and English,
the logo, a cover image, and the working hours start and end per day.
```

The team handles the rest. You'll be asked to:
1. **Review the schema** — add, remove, or modify fields
2. **Wait for collection** — researchers work in parallel
3. **Review validation** — see how many items are valid vs have gaps
4. **Choose delivery** — CSV, JSON, API push, or database insert

## Team Architecture

| Agent | Role | Skills |
|-------|------|--------|
| **Lead** | Orchestrates the pipeline, manages tasks, presents results | — |
| **Schema Architect** | Parses your prompt into a structured JSON schema | `schema-from-prompt` |
| **Researcher** (1-8) | Collects data from the web, scales with volume | `web-scraping`, `apify-lead-generation`, `batch-checkpoint` |
| **Data Validator** | Cleans, normalizes, deduplicates collected data | `data-cleaning-pipeline`, `arabic-text-processing` |
| **API Integrator** | Delivers data to any destination | `api-integration`, `data-export` |

Researchers auto-scale based on estimated volume:

| Items | Researchers |
|-------|-------------|
| Up to 100 | 1 |
| 101 — 1,000 | 2–3 |
| 1,001 — 5,000 | 3–5 |
| 5,001 — 10,000 | 5–8 |

## Delivery Options

| Format | Command | Output |
|--------|---------|--------|
| **CSV** | "Export to CSV" | `workspace/export/data.csv` (UTF-8 BOM for Excel) |
| **JSON** | "Export to JSON" | `workspace/export/data.json` |
| **REST API** | Provide URL, auth, method | Batch push with retry |
| **GraphQL** | Provide endpoint + mutation | Mapped variable push |
| **Database** | Provide host, table, credentials | Batch insert/upsert |

## Example Prompts

```
Find me all coffee shops in Riyadh. Get the name in Arabic and English,
Instagram handle, phone number, location coordinates, and menu photos.
```

```
Get me a list of SaaS companies in the UAE. I need the company name,
website URL, founding year, number of employees, and a short description.
```

```
Find restaurants in Kuwait City that deliver on Talabat. Get the name
in AR/EN, cuisine type, rating, logo, and delivery hours per day.
```

## Project Structure

```
content-team/
├── CLAUDE.md                    # Team spec, workflow, conventions
├── USAGE.md                     # Detailed usage guide
├── README.md                    # This file
├── .agents/skills/              # Agent skills (registry + custom)
│   ├── web-scraping/            # Cascade scraping strategy
│   ├── apify-lead-generation/   # Platform scraping via Apify
│   ├── data-cleaning-pipeline/  # Systematic data cleaning
│   ├── api-integration/         # REST API handling
│   ├── schema-from-prompt/      # NLP → JSON schema (custom)
│   ├── data-export/             # CSV/JSON export (custom)
│   ├── arabic-text-processing/  # Arabic Unicode handling (custom)
│   └── batch-checkpoint/        # Batch file management (custom)
├── prompts/                     # Agent role definitions
│   ├── lead-orchestrator.md
│   ├── schema-architect.md
│   ├── researcher.md
│   ├── data-validator.md
│   └── api-integrator.md
├── schemas/templates/           # Reusable schema templates
├── scripts/                     # Validation & merge scripts
└── workspace/                   # Runtime data (per job)
    ├── raw/                     # Researcher batch files
    ├── export/                  # CSV/JSON exports
    └── media/                   # Downloaded images
```

## Skills

8 skills power the agents — 4 from the [Vercel skills registry](https://skills.sh), 4 custom-built:

| Skill | Source | Used By |
|-------|--------|---------|
| `web-scraping` | [jamditis/claude-skills-journalism](https://skills.sh/jamditis/claude-skills-journalism/web-scraping) | Researcher |
| `apify-lead-generation` | [apify/agent-skills](https://skills.sh/apify/agent-skills/apify-lead-generation) | Researcher |
| `data-cleaning-pipeline` | [aj-geddes/useful-ai-prompts](https://skills.sh/aj-geddes/useful-ai-prompts/data-cleaning-pipeline) | Validator |
| `api-integration` | [autumnsgrove/groveengine](https://skills.sh/autumnsgrove/groveengine/api-integration) | Integrator |
| `schema-from-prompt` | Custom | Schema Architect |
| `batch-checkpoint` | Custom | Researcher |
| `arabic-text-processing` | Custom | Validator |
| `data-export` | Custom | Integrator |

## Advanced Usage

- **Reuse schemas**: "Use the same fields as my Kuwait businesses schema"
- **Mid-job changes**: "Add a website_url field and have researchers collect it"
- **Partial exports**: "Export what we have so far to CSV"
- **Scale up**: "Add 2 more researchers, this is going slow"
- **Gap handling**: "Have the researchers fill in the missing data"

See [USAGE.md](USAGE.md) for the full detailed guide.

## License

MIT
