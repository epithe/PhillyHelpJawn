# PhillyHelpJawn Backend Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a TypeScript backend that receives speech-to-text transcripts and returns plain-language social service recommendations using Claude + Supabase.

**Architecture:** Hono HTTP server → Claude API with tool use → Supabase query → structured response. Single endpoint, single turn.

**Tech Stack:** TypeScript, Hono, @anthropic-ai/sdk, @supabase/supabase-js, csv-parse, tsx

---

## File Map

| File | Responsibility |
|------|---------------|
| `backend/package.json` | Dependencies and scripts |
| `backend/tsconfig.json` | TypeScript config |
| `backend/.env` | API keys (ANTHROPIC_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY) |
| `.gitignore` | Ignore node_modules, .env, dist (root level) |
| `backend/src/types.ts` | Request, response, and resource types |
| `backend/src/db.ts` | Supabase client, `searchResources()` query |
| `backend/src/agent.ts` | Claude system prompt, tool definition, `handleQuery()` |
| `backend/src/validation.ts` | `validateRequest()` — pure function, no side effects |
| `backend/src/index.ts` | Hono server, `/v1/assist/query` endpoint |
| `backend/src/seed.ts` | CSV → geocode → insert into Supabase |
| `backend/src/geo.ts` | `computeDistance()` haversine helper |
| `backend/data/resources.csv` | Sample resource data for seeding |
| `backend/tests/validation.test.ts` | Request validation tests |

All commands below should be run from the `backend/` directory.

---

## Chunk 1: Scaffolding + Types

### Task 1: Project scaffolding

**Files:**
- Create: `package.json`, `tsconfig.json`, `.gitignore`, `.env.example`

- [ ] **Step 1: Initialize package.json**

```bash
cd /Users/emilypodhorcer/projects/active/PhillyHelpJawn
npm init -y
```

- [ ] **Step 2: Install dependencies**

```bash
npm install hono @hono/node-server @anthropic-ai/sdk @supabase/supabase-js csv-parse dotenv
npm install -D typescript @types/node tsx vitest
```

- [ ] **Step 3: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "strict": true,
    "outDir": "dist",
    "rootDir": "src",
    "skipLibCheck": true
  },
  "include": ["src/**/*", "tests/**/*"]
}
```

- [ ] **Step 4: Create .gitignore**

```
node_modules/
dist/
.env
```

- [ ] **Step 5: Create .env.example**

```
ANTHROPIC_API_KEY=
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

- [ ] **Step 6: Add scripts to package.json**

Add to `package.json`:
```json
{
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "start": "tsx src/index.ts",
    "seed": "tsx src/seed.ts",
    "test": "vitest run"
  }
}
```

- [ ] **Step 7: Commit**

```bash
git add package.json tsconfig.json .gitignore .env.example package-lock.json
git commit -m "chore: scaffold project with dependencies"
```

---

### Task 2: Shared types

**Files:**
- Create: `src/types.ts`

- [ ] **Step 1: Write types**

```typescript
// src/types.ts

export interface Resource {
  id: string;
  name: string;
  category: string;
  eligibility: string | null;
  address: string;
  lat: number;
  lng: number;
  hours: string | null;
  phone: string | null;
  description: string | null;
}

export interface ResourceWithDistance extends Resource {
  distanceKm: number | null;
}

export interface AssistRequest {
  requestId: string;
  timestamp: string;
  inputModality: string;
  queryText: string;
  language: string;
  persona?: string;
  location?: {
    lat: number;
    lng: number;
    accuracyMeters?: number;
  };
  client: {
    platform: string;
    appVersion?: string;
    buildNumber?: string;
  };
  session?: {
    sessionId: string;
    turnIndex: number;
  };
}

export interface AssistResponse {
  requestId: string;
  timestamp: string;
  message: string;
  resources: ResourceWithDistance[];
}

export interface ErrorResponse {
  requestId: string;
  timestamp: string;
  error: string;
}
```

- [ ] **Step 2: Commit**

```bash
git add src/types.ts
git commit -m "feat: add shared types for request, response, and resources"
```

---

## Chunk 2: Database + Geo

### Task 3: Geo helper

**Files:**
- Create: `src/geo.ts`, `tests/geo.test.ts`

- [ ] **Step 1: Write the failing test**

```typescript
// tests/geo.test.ts
import { describe, it, expect } from "vitest";
import { computeDistance } from "../src/geo.js";

describe("computeDistance", () => {
  it("computes distance between two Philly points", () => {
    // City Hall to Temple University ≈ 2.8 km
    const d = computeDistance(39.9526, -75.1652, 39.9812, -75.1495);
    expect(d).toBeGreaterThan(2.5);
    expect(d).toBeLessThan(3.5);
  });

  it("returns 0 for same point", () => {
    const d = computeDistance(39.9526, -75.1652, 39.9526, -75.1652);
    expect(d).toBe(0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npx vitest run tests/geo.test.ts
```
Expected: FAIL — module not found

- [ ] **Step 3: Write implementation**

```typescript
// src/geo.ts

export function computeDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npx vitest run tests/geo.test.ts
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/geo.ts tests/geo.test.ts
git commit -m "feat: add haversine distance helper"
```

---

### Task 4: Database layer

**Files:**
- Create: `src/db.ts`

- [ ] **Step 1: Write Supabase client and search function**

```typescript
// src/db.ts
import { createClient } from "@supabase/supabase-js";
import type { Resource } from "./types.js";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

export async function searchResources(params: {
  category?: string;
  eligibility?: string;
}): Promise<Resource[]> {
  let query = supabase.from("resources").select("*");

  if (params.category) {
    // ilike for case-insensitive match (Claude may send "shelter" vs "Shelter")
    query = query.ilike("category", params.category);
  }
  if (params.eligibility) {
    query = query.ilike("eligibility", `%${params.eligibility}%`);
  }

  const { data, error } = await query;

  if (error) {
    console.error("Supabase query error:", error);
    return [];
  }

  return data as Resource[];
}
```

- [ ] **Step 2: Commit**

```bash
git add src/db.ts
git commit -m "feat: add Supabase client and searchResources query"
```

---

## Chunk 3: Agent

### Task 5: Claude agent with tool use

**Files:**
- Create: `src/agent.ts`

- [ ] **Step 1: Write agent module**

```typescript
// src/agent.ts
import Anthropic from "@anthropic-ai/sdk";
import { searchResources } from "./db.js";
import type { Resource } from "./types.js";

const client = new Anthropic();

const SYSTEM_PROMPT = `You are a friendly helper for people in Philadelphia who need social services like food and shelter.

IMPORTANT RULES:
- Use very simple words and short sentences. Write at a 4th-grade reading level.
- Be warm and kind. These people may be in a tough spot.
- Always mention the name, address, and hours of each place you recommend.
- If someone sounds scared or urgent, respond with extra care and prioritize immediate help.
- If you're not sure what they need, make your best guess from what they said. Do not ask follow-up questions.
- Only recommend places from the search results. Never make up places.
- If no results match, say so kindly and suggest they call 211 for help.`;

const SEARCH_TOOL: Anthropic.Tool = {
  name: "search_resources",
  description:
    "Search for social service resources in Philadelphia. Use this to find shelters, food banks, and other services.",
  input_schema: {
    type: "object" as const,
    properties: {
      category: {
        type: "string",
        description:
          'The type of resource: "Shelter", "Food", etc. Leave empty to search all categories.',
      },
      eligibility: {
        type: "string",
        description:
          'Filter by who can use it, e.g. "family", "youth", "male", "female". Leave empty for no filter.',
      },
    },
    required: [],
  },
};

export async function handleQuery(queryText: string): Promise<{
  message: string;
  resources: Resource[];
}> {
  let collectedResources: Resource[] = [];

  const messages: Anthropic.MessageParam[] = [
    { role: "user", content: queryText },
  ];

  // Initial call — Claude may request tool use
  let response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    tools: [SEARCH_TOOL],
    messages,
  });

  // Tool use loop
  while (response.stop_reason === "tool_use") {
    const toolBlock = response.content.find(
      (block): block is Anthropic.ContentBlock & { type: "tool_use" } =>
        block.type === "tool_use"
    );

    if (!toolBlock) break;

    const input = toolBlock.input as {
      category?: string;
      eligibility?: string;
    };
    const results = await searchResources(input);
    collectedResources = [...collectedResources, ...results];

    messages.push({ role: "assistant", content: response.content });
    messages.push({
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: toolBlock.id,
          content: JSON.stringify(results),
        },
      ],
    });

    response = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      tools: [SEARCH_TOOL],
      messages,
    });
  }

  // Extract text response
  const textBlock = response.content.find(
    (block): block is Anthropic.TextBlock => block.type === "text"
  );

  return {
    message: textBlock?.text ?? "Sorry, I could not find an answer right now.",
    resources: collectedResources,
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add src/agent.ts
git commit -m "feat: add Claude agent with tool use for resource search"
```

---

## Chunk 4: HTTP Server

### Task 6: Validation (pure function, testable independently)

**Files:**
- Create: `src/validation.ts`, `tests/validation.test.ts`

Note: `validateRequest` is in its own module so tests can import it without starting the server.

- [ ] **Step 1: Write validation tests**

```typescript
// tests/validation.test.ts
import { describe, it, expect } from "vitest";
import { validateRequest } from "../src/validation.js";

describe("validateRequest", () => {
  const validBody = {
    requestId: "abc-123",
    timestamp: "2026-03-15T16:42:10Z",
    inputModality: "voice_ptt",
    queryText: "I need food",
    language: "en-US",
    client: { platform: "ios" },
  };

  it("accepts a valid request", () => {
    expect(validateRequest(validBody)).toBeNull();
  });

  it("rejects missing requestId", () => {
    const { requestId, ...noId } = validBody;
    expect(validateRequest(noId)).toBe("requestId is required");
  });

  it("rejects empty queryText", () => {
    expect(validateRequest({ ...validBody, queryText: "" })).toBe(
      "queryText is required"
    );
  });

  it("rejects queryText over 500 chars", () => {
    expect(
      validateRequest({ ...validBody, queryText: "a".repeat(501) })
    ).toBe("queryText must be 500 characters or fewer");
  });

  it("rejects unsupported language", () => {
    expect(validateRequest({ ...validBody, language: "fr-FR" })).toBe(
      "Only en-US is supported"
    );
  });

  it("rejects location with missing lng", () => {
    expect(
      validateRequest({
        ...validBody,
        location: { lat: 39.95 },
      })
    ).toBe("location requires both lat and lng");
  });

  it("accepts request with valid location", () => {
    expect(
      validateRequest({
        ...validBody,
        location: { lat: 39.95, lng: -75.16 },
      })
    ).toBeNull();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
npx vitest run tests/validation.test.ts
```
Expected: FAIL — module not found

- [ ] **Step 3: Write validation module**

```typescript
// src/validation.ts

export function validateRequest(body: any): string | null {
  if (!body.requestId) {
    return "requestId is required";
  }
  if (!body.queryText || body.queryText.trim() === "") {
    return "queryText is required";
  }
  if (body.queryText.length > 500) {
    return "queryText must be 500 characters or fewer";
  }
  if (body.language && body.language !== "en-US") {
    return "Only en-US is supported";
  }
  if (body.location) {
    if (body.location.lat == null || body.location.lng == null) {
      return "location requires both lat and lng";
    }
  }
  return null;
}
```

- [ ] **Step 4: Run validation tests**

```bash
npx vitest run tests/validation.test.ts
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/validation.ts tests/validation.test.ts
git commit -m "feat: add request validation with tests"
```

---

### Task 7: Hono server endpoint

**Files:**
- Create: `src/index.ts`

- [ ] **Step 1: Write server**

```typescript
// src/index.ts
import "dotenv/config";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { serve } from "@hono/node-server";
import { handleQuery } from "./agent.js";
import { computeDistance } from "./geo.js";
import { validateRequest } from "./validation.js";
import type {
  AssistRequest,
  AssistResponse,
  ErrorResponse,
  ResourceWithDistance,
} from "./types.js";

const app = new Hono();
app.use("*", cors());

app.post("/v1/assist/query", async (c) => {
  const body = await c.req.json<AssistRequest>();

  const error = validateRequest(body);
  if (error) {
    const errResp: ErrorResponse = {
      requestId: body.requestId ?? "unknown",
      timestamp: new Date().toISOString(),
      error,
    };
    return c.json(errResp, 400);
  }

  try {
    const { message, resources } = await handleQuery(body.queryText);

    const resourcesWithDistance: ResourceWithDistance[] = resources.map((r) => ({
      ...r,
      distanceKm: body.location
        ? Math.round(
            computeDistance(body.location.lat, body.location.lng, r.lat, r.lng) *
              10
          ) / 10
        : null,
    }));

    if (body.location) {
      resourcesWithDistance.sort(
        (a, b) => (a.distanceKm ?? Infinity) - (b.distanceKm ?? Infinity)
      );
    }

    const response: AssistResponse = {
      requestId: body.requestId,
      timestamp: new Date().toISOString(),
      message,
      resources: resourcesWithDistance,
    };

    return c.json(response);
  } catch (err) {
    console.error("Agent error:", err);
    const response: AssistResponse = {
      requestId: body.requestId,
      timestamp: new Date().toISOString(),
      message: "Sorry, I'm having trouble right now. Please try again.",
      resources: [],
    };
    return c.json(response);
  }
});

const port = Number(process.env.PORT) || 3000;
serve({ fetch: app.fetch, port }, () => {
  console.log(`PhillyHelpJawn backend running on http://localhost:${port}`);
});
```

- [ ] **Step 2: Commit**

```bash
git add src/index.ts
git commit -m "feat: add Hono server with /v1/assist/query endpoint"
```

---

## Chunk 5: Seed Script + Manual Test

### Task 8: Seed script

**Files:**
- Create: `src/seed.ts`, `data/resources.csv`

- [ ] **Step 1: Create sample CSV**

Create `data/resources.csv` with a few rows from the spreadsheet (teammate will provide the full file):

```csv
category,name,address,eligibility,hours,phone,description
Shelter,Appletree Family Center,1430 Cherry St.,Daytime center,"Mon.–Fri. 7 a.m.–5 p.m.",,
Shelter,Roosevelt Darby Center,804 N. Broad St.,Daytime center,"Mon.–Fri. 7 a.m.–5 p.m.",,
Shelter,Red Shield Family Residence,715 N. Broad St.,After hours - family,"5 p.m.–7 a.m.",,
Food,Mount Tabor CEED Corporation,961-971 N 7th St,Food cupboard,Monday,,
Food,Drueding Center,1321 N Lawrence St,Food cupboard,Tuesday,,
```

- [ ] **Step 2: Write seed script**

```typescript
// src/seed.ts
import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import { parse } from "csv-parse/sync";
import { readFileSync } from "fs";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

// Simple geocoding using OpenStreetMap Nominatim (free, no API key)
async function geocode(
  address: string
): Promise<{ lat: number; lng: number } | null> {
  const query = encodeURIComponent(`${address}, Philadelphia, PA`);
  const res = await fetch(
    `https://nominatim.openstreetmap.org/search?q=${query}&format=json&limit=1`,
    { headers: { "User-Agent": "PhillyHelpJawn-Hackathon/0.1" } }
  );
  const data = await res.json();
  if (data.length === 0) return null;
  return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) };
}

async function main() {
  const csv = readFileSync("data/resources.csv", "utf-8");
  const records = parse(csv, { columns: true, skip_empty_lines: true });

  console.log(`Seeding ${records.length} resources...`);

  for (const row of records) {
    // Rate limit: Nominatim asks for 1 req/sec
    await new Promise((r) => setTimeout(r, 1100));

    const coords = await geocode(row.address);
    if (!coords) {
      console.warn(`  Could not geocode: ${row.address}`);
    }

    const { error } = await supabase.from("resources").insert({
      category: row.category,
      name: row.name,
      address: row.address,
      lat: coords?.lat ?? null,
      lng: coords?.lng ?? null,
      eligibility: row.eligibility || null,
      hours: row.hours || null,
      phone: row.phone || null,
      description: row.description || null,
    });

    if (error) {
      console.error(`  Error inserting ${row.name}:`, error.message);
    } else {
      console.log(
        `  ✓ ${row.name}${coords ? ` (${coords.lat}, ${coords.lng})` : " (no coords)"}`
      );
    }
  }

  console.log("Done.");
}

main();
```

- [ ] **Step 3: Commit**

```bash
git add src/seed.ts data/resources.csv
git commit -m "feat: add seed script with Nominatim geocoding"
```

---

### Task 9: Create Supabase table + seed

This task requires your Supabase project credentials.

- [ ] **Step 1: Create the `resources` table in Supabase**

Run this SQL in the Supabase SQL editor:

```sql
CREATE TABLE resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL,
  name text NOT NULL,
  address text NOT NULL,
  lat float,
  lng float,
  phone text,
  eligibility text,
  hours text,
  description text
);

-- Enable read access for anon key
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read" ON resources FOR SELECT USING (true);
```

- [ ] **Step 2: Add your keys to .env**

```
ANTHROPIC_API_KEY=sk-ant-...
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

- [ ] **Step 3: Run seed**

```bash
npm run seed
```
Expected: Each resource logs with coordinates.

- [ ] **Step 4: Commit .env.example update if needed**

---

### Task 10: End-to-end manual test

- [ ] **Step 1: Start the server**

```bash
npm run dev
```

- [ ] **Step 2: Test with curl**

```bash
curl -X POST http://localhost:3000/v1/assist/query \
  -H "Content-Type: application/json" \
  -d '{
    "requestId": "test-1",
    "timestamp": "2026-03-15T17:00:00Z",
    "inputModality": "voice_ptt",
    "queryText": "I need somewhere to sleep tonight",
    "language": "en-US",
    "client": {"platform": "ios"},
    "location": {"lat": 39.9526, "lng": -75.1652}
  }'
```

Expected: JSON response with `message` in simple language and `resources` array with shelter results sorted by distance.

- [ ] **Step 3: Test validation**

```bash
curl -X POST http://localhost:3000/v1/assist/query \
  -H "Content-Type: application/json" \
  -d '{"requestId":"test-2","timestamp":"2026-03-15T17:00:00Z","inputModality":"voice_ptt","queryText":"","language":"en-US","client":{"platform":"ios"}}'
```

Expected: HTTP 400, `{"error": "queryText is required"}`

- [ ] **Step 4: Start ngrok and share URL with iOS dev**

```bash
ngrok http 3000
```

Share the ngrok URL with the iOS teammate.
