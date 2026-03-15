# PhillyHelpJawn Backend Design

## Overview

Backend server for PhillyHelpJawn, a hackathon project that helps illiterate and low-literacy individuals access social services in Philadelphia via voice interaction. The server receives speech-to-text transcripts from an iOS app, uses Claude as an agent to match users with relevant community resources stored in Supabase, and returns plain-language text (plus structured data) for the client to convert to speech.

## Tech Stack

- **Runtime:** Node.js + TypeScript
- **Framework:** Hono
- **LLM:** Claude (Anthropic SDK, tool use)
- **Database:** Supabase (PostgreSQL)
- **Local dev:** `npx tsx`, ngrok for iOS app access

## API Surface

Single endpoint, no auth (ngrok URL is the secret for hackathon).

```
POST /ask
Content-Type: application/json

Request:
{
  "transcript": "I need somewhere to sleep tonight"
}

Response:
{
  "message": "There are a few places that can help you tonight...",
  "resources": [
    {
      "id": "uuid",
      "name": "Red Shield Family Residence",
      "category": "Shelter",
      "eligibility": "After hours - family",
      "address": "715 N. Broad St.",
      "lat": 39.9654,
      "lng": -75.1596,
      "hours": "5 p.m.–7 a.m.",
      "phone": "215-787-2887",
      "description": null
    }
  ]
}
```

- `message`: Plain-language text read aloud by the iOS app.
- `resources`: Structured data for UI rendering (call buttons, map links, etc.).

## Supabase Schema

One table: `resources`

| Column        | Type  | Notes                                          |
|---------------|-------|------------------------------------------------|
| `id`          | uuid  | PK, default `gen_random_uuid()`                |
| `category`    | text  | "Shelter", "Food", etc.                        |
| `name`        | text  | Organization name                              |
| `address`     | text  | Street address                                 |
| `lat`         | float | Geocoded from address                          |
| `lng`         | float | Geocoded from address                          |
| `phone`       | text  | Nullable                                       |
| `eligibility` | text  | Free text: type, demographics, constraints     |
| `hours`       | text  | Days/times as free text                        |
| `description` | text  | Nullable, additional notes                     |

Data loaded via seed script from teammate's CSV spreadsheet. Addresses geocoded at seed time.

## Claude Agent Design

### System Prompt

Constraints for Claude's persona and output:
- Helps people find social services in Philadelphia
- Short, simple sentences (4th-grade reading level)
- Warm and direct — no jargon, no filler
- Always includes name, address, and hours of recommended resources
- Detects urgency/tone and responds accordingly
- Single-turn: picks the most likely interpretation rather than asking follow-ups

### Tool Definition

```
search_resources({
  category?: string,     // "Shelter", "Food", etc.
  eligibility?: string   // free-text filter, e.g. "family", "youth"
})
```

Executes a Supabase query: filters by `category` (exact match) if provided, `ilike` on `eligibility` if provided. Returns all matching rows. Tool parameters are extensible for future search options.

### Flow

1. iOS app POSTs transcript to `/ask`
2. Server sends transcript to Claude with system prompt + tool definition
3. Claude calls `search_resources` with extracted filters
4. Server executes Supabase query, returns results to Claude as tool_result
5. Claude generates plain-language `message` and indicates which resources it's recommending
6. Server returns `{ message, resources }` where `resources` is all rows returned by the query (Claude's `message` highlights the most relevant ones; the iOS app gets the full set for UI rendering)

## Project Structure

```
PhillyHelpJawn/
├── src/
│   ├── index.ts          # Hono server, /ask endpoint
│   ├── agent.ts          # Claude call: system prompt, tool def, message handling
│   ├── db.ts             # Supabase client + search_resources query
│   ├── types.ts          # Shared types (Resource, ApiResponse, etc.)
│   └── seed.ts           # CSV → geocode → insert into Supabase
├── data/
│   └── resources.csv     # Spreadsheet export
├── .env                  # ANTHROPIC_API_KEY, SUPABASE_URL, SUPABASE_KEY
├── package.json
└── tsconfig.json
```

## Error Handling

Hackathon-minimal:
- Claude API failure → `{ message: "Sorry, I'm having trouble right now. Please try again.", resources: [] }`
- No matching resources → Claude says so in plain language, `resources` is empty
- Invalid/empty transcript → `{ message: "I didn't catch that. Could you say that again?", resources: [] }`

## Latency

~2-4 seconds total. Claude API call with tool use is the bottleneck. Acceptable for demo.

## Out of Scope (for now)

- Authentication / rate limiting
- Multi-turn conversation (depends on S2T/T2S latency)
- Vector/semantic search (dataset is small enough for filtered queries)
- Deployment to hosted infrastructure (local + ngrok for hackathon)
