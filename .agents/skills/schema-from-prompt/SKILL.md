# Schema From Prompt

Parse natural language content collection prompts into structured JSON schemas.

## When to Use

Use this skill when a user describes what data they want to collect in plain language and you need to produce a formal schema definition.

## How It Works

### Step 1: Entity Extraction

Identify from the prompt:
- **Entity type**: What is being collected? (business, restaurant, product, person, event, place)
- **Region/scope**: Geographic or categorical bounds (Kuwait, UAE, "tech companies")
- **Quantity**: How many items (explicit number or estimate)

### Step 2: Field Detection

Scan for field indicators:

| Prompt Pattern | Field Type | Example |
|---|---|---|
| "name" / "title" | `string` | "business name" → `name` |
| "in Arabic and English" / "in ar and en" | Two `string` fields with locale | → `name_ar`, `name_en` |
| "logo" / "image" / "photo" / "picture" | `image_url` | "logo" → `logo_url` |
| "cover" / "banner" / "thumbnail" | `image_url` | "cover image" → `cover_image_url` |
| "hours" / "schedule" / "timing" | `array` of `{day, start, end}` | "working hours per day" → `working_hours[]` |
| "phone" / "contact number" / "mobile" | `phone` | → `phone_number` |
| "email" / "mail" | `email` | → `email` |
| "website" / "site" / "url" / "link" | `url` | → `website_url` |
| "address" / "location" | `object` with address fields | → `address{}` |
| "rating" / "score" / "stars" | `number` | → `rating` |
| "price" / "cost" | `number` | → `price` |
| "description" / "about" / "bio" | `string` | → `description` |
| "category" / "type" / "cuisine" | `string` | → `category` |
| "social" / "instagram" / "twitter" | `url` | → `instagram_url`, `twitter_url` |
| "coordinates" / "lat" / "lng" | `object` with `lat`, `lng` | → `coordinates{}` |

### Step 3: Locale Handling

When the user mentions multiple languages:
- "in Arabic and English" → create `{field}_ar` and `{field}_en`
- "in ar, en, fr" → create `{field}_ar`, `{field}_en`, `{field}_fr`
- If no locale specified, create a single field with `locale: null`

### Step 4: Auto-Add System Fields

Always include these fields (user doesn't need to ask for them):
- `id` (string, required) — unique identifier, pattern: `{region}-{entity}-{number}`
- `source_url` (url, required) — where the data was found
- `collected_at` (date, required) — ISO 8601 timestamp

### Step 5: Structure Detection

Detect nested structures:
- "per day" / "for each day" → array of objects with `day` field
- "per category" / "by type" → array of objects with `category` field
- "address with street, city" → object with sub-fields
- "list of" / "multiple" → array type

### Step 6: Source Estimation

Based on entity + region, suggest data sources:
- Businesses in Middle East → Google Maps, Talabat, Deliveroo, Carriage, Instagram
- Restaurants → Google Maps, food delivery apps, Zomato, TripAdvisor
- Products → Amazon, Noon, company websites
- People → LinkedIn, company about pages
- Events → Eventbrite, local event sites, social media

### Step 7: Count Estimation

If the user specifies a count, use it. Otherwise estimate:
- "restaurants in a city" → 200-500
- "businesses in a country" → 1000-5000
- "top 10" / "best 20" → use the exact number
- "all" → estimate based on region + category

## Output Format

```json
{
  "name": "kebab-case-descriptive-name",
  "description": "Clear one-line description",
  "version": "1.0",
  "fields": [
    {
      "key": "field_name",
      "type": "string|number|url|image_url|email|phone|time|date|boolean|array|object",
      "required": true|false,
      "description": "What this field contains",
      "locale": "ar|en|fr|null",
      "example": "realistic example value",
      "children": []
    }
  ],
  "metadata": {
    "entity": "business|restaurant|product|person|event|place",
    "region": "ISO country code or description",
    "estimated_count": 500,
    "sources_hint": ["source1", "source2"]
  }
}
```

## Rules

1. Required vs optional: Fields the user explicitly mentioned are required. System fields are required. Everything else is optional.
2. Be specific with types: Use `image_url` not `string` for images, `phone` not `string` for phone numbers.
3. Use snake_case for all field keys.
4. Provide realistic examples in the target locale/region.
5. If the prompt is ambiguous, list your assumptions.
