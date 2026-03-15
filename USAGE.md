# Content Stock Team — Usage Guide

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- Agent teams enabled in your Claude Code settings:
  ```json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```
- tmux or iTerm2 installed (for split-pane view of teammates)

## Quick Start

1. Open a terminal and navigate to the project directory:
   ```bash
   cd content-stock-team
   ```

2. Launch Claude Code:
   ```bash
   claude
   ```

3. Start the team:
   ```
   Create a content stock team. Read prompts/lead-orchestrator.md for your coordination instructions.
   ```

4. Give your content collection prompt:
   ```
   Find me online businesses in Kuwait — get the name in Arabic and English,
   the logo, a cover image, and the working hours start and end per day.
   ```

5. The team takes it from there. You'll be asked to review the schema, then sit back while data is collected.

## Step-by-Step Walkthrough

### Step 1: Describe What You Want

Write a natural language prompt describing:
- **What** to collect (businesses, restaurants, products, people, events)
- **Where** (country, city, region)
- **Which fields** (name, logo, hours, phone, email, social links)
- **Any locale requirements** (Arabic, English, both)
- **Approximate quantity** if you know it

Examples:

```
Find me all coffee shops in Riyadh. Get the name in Arabic and English,
Instagram handle, phone number, location coordinates, and menu photos.
```

```
Get me a list of SaaS companies in the UAE. I need the company name,
website URL, founding year, number of employees, and a short description
in English.
```

```
Find restaurants in Kuwait City that deliver on Talabat. Get the name
in AR/EN, cuisine type, rating, logo, and delivery hours per day.
```

### Step 2: Review the Schema

The Schema Architect will propose a data structure based on your prompt. You'll see something like:

| Field | Type | Required | Example |
|-------|------|----------|---------|
| id | string | yes | kw-biz-001 |
| name_en | string | yes | Talabat |
| name_ar | string | yes | طلبات |
| logo_url | image_url | yes | https://... |
| cover_image_url | image_url | no | https://... |
| working_hours | array | yes | [{day, start, end}] |
| source_url | url | yes | https://... |
| collected_at | date | yes | 2026-03-09T12:00:00Z |

You can:
- **Approve as-is**: "Looks good, proceed"
- **Add fields**: "Add a phone_number field and an instagram_handle field"
- **Remove fields**: "Drop the cover_image_url, I don't need it"
- **Change types**: "Make rating a number, not a string"
- **Mark optional**: "Make working_hours optional"

### Step 3: Wait for Collection

Researchers are automatically spawned based on the estimated volume:

| Estimated Items | Researchers |
|-----------------|-------------|
| Up to 100 | 1 |
| 101 — 1,000 | 2–3 |
| 1,001 — 5,000 | 3–5 |
| 5,001 — 10,000 | 5–8 |

Each researcher gets a non-overlapping scope (by alphabet, category, geography, or source) and writes results to batch files in `workspace/raw/`.

You can check progress at any time:
```
How's the collection going?
```

### Step 4: Review Validation Results

Once collection is complete, the Data Validator runs automatically and reports:

```
Collection complete:
- Total raw items: 523
- Valid: 490
- Gaps (missing data): 25
- Duplicates merged: 8
```

You can:
- **Review gaps**: "Show me the items with missing data"
- **Accept as-is**: "That's fine, proceed to delivery"
- **Re-collect**: "Have the researchers fill in the gaps"

### Step 5: Choose Delivery

Tell the team where you want the data:

#### CSV Export
```
Export to CSV
```
Output: `workspace/export/data.csv` (UTF-8 with BOM for Excel compatibility)

#### JSON Export
```
Export to JSON
```
Output: `workspace/export/data.json`

#### REST API
```
Push this to my API at https://api.example.com/businesses
- Auth: Bearer token xyz123
- Method: POST
- Endpoint: /api/v1/businesses
```

#### GraphQL
```
Push to my GraphQL endpoint at https://api.example.com/graphql
Here's the mutation: mutation CreateBusiness($input: BusinessInput!) { ... }
```

#### Database
```
Insert into my PostgreSQL database:
- Host: db.example.com
- Database: content_db
- Table: businesses
- User: admin
```

The API Integrator handles field mapping, batching, retries, and gives you a delivery report with success/failure counts.

## Advanced Usage

### Reusing Schemas

When you start a new job, the team checks `schemas/templates/` for similar schemas:

```
Find me restaurants in Bahrain with the same fields as my Kuwait businesses schema.
```

The team will load the existing template and adapt it.

### Modifying a Job Mid-Collection

You can intervene at any point:

- **Add a field**: "Add a 'website_url' field to the schema and have researchers collect it"
- **Expand scope**: "Also include businesses in Bahrain"
- **Narrow scope**: "Only focus on restaurants, skip other categories"
- **Add researchers**: "This is going slow, add 2 more researchers"

### Handling Large Collections (5,000+)

For large jobs:
- Researchers checkpoint every 25 items so no work is lost
- Batch files cap at 100 items each
- The validator processes incrementally
- You can ask for partial exports while collection is still running:
  ```
  Export what we have so far to CSV
  ```

### Custom Field Types

The schema supports these field types:

| Type | Description | Example |
|------|-------------|---------|
| string | Plain text | "Talabat" |
| number | Numeric value | 4.5 |
| url | Web URL | https://example.com |
| image_url | Direct image URL | https://example.com/logo.png |
| email | Email address | info@example.com |
| phone | Phone number | +965-1234-5678 |
| time | 24h time | 09:00 |
| date | ISO 8601 date | 2026-03-09 |
| boolean | True/false | true |
| array | List of objects | [{day, start, end}] |
| object | Nested structure | {street, city, zip} |

## File Locations

| Path | Purpose |
|------|---------|
| `workspace/schema.json` | Current job's approved schema |
| `workspace/raw/batch-*.json` | Raw researcher output |
| `workspace/validated.json` | Cleaned, validated data |
| `workspace/gaps.json` | Items with missing/invalid fields |
| `workspace/export/` | CSV and JSON exports |
| `workspace/delivery-report.json` | API push results |
| `schemas/templates/` | Saved schemas for reuse |

## Troubleshooting

### Researchers are slow
- Check if they're hitting rate limits: "What's the status of researcher-1?"
- Add more researchers: "Spawn 2 more researchers to help"
- Try different sources: "Use Instagram instead of Google Maps for logos"

### Too many gaps in validation
- Review the gap report: "Show me the gaps"
- Common causes: fields that don't exist publicly, sites blocking scraping
- Consider making hard-to-find fields optional in the schema

### API push failing
- Check the delivery report: "Show me the delivery report"
- Common causes: auth expired, rate limits, field mapping mismatch
- The Integrator retries 3 times with backoff before logging a failure

### Schema doesn't match what I need
- Edit it directly: "Change the schema — rename 'name_en' to 'title' and add a 'category' field"
- Start fresh: "Discard this schema and propose a new one"
