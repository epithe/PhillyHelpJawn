# PhillyHelpJawn MVP Response Contract (Backend AI -> Frontend)

This document defines the response payload that the backend returns for assist queries.

## Endpoint

- Method: `POST`
- Path: `/v1/assist/query`

## Success Response (HTTP 200)

```json
{
  "requestId": "9e5d4f53-0db8-4f77-b4e8-e38f73b6b2cc",
  "timestamp": "2026-03-15T16:42:12Z",
  "message": "Here are some places where you can get food tonight. Mount Tabor CEED Corporation is at 961 North 7th Street. They have a food cupboard open on Mondays. Breaking Bread on Broad is at 615 North Broad Street.",
  "resources": [
    {
      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "name": "Mount Tabor CEED Corporation",
      "category": "Food",
      "eligibility": "Food cupboard",
      "address": "961-971 N 7th St",
      "lat": 39.9678,
      "lng": -75.1485,
      "distanceKm": 1.2,
      "hours": "Monday",
      "phone": null,
      "description": null
    },
    {
      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "name": "Breaking Bread on Broad",
      "category": "Food",
      "eligibility": null,
      "address": "615 N Broad St",
      "lat": 39.9631,
      "lng": -75.1596,
      "distanceKm": 0.8,
      "hours": null,
      "phone": "215-555-0100",
      "description": null
    }
  ]
}
```

## Response Fields

### Top-Level

| Field        | Type   | Required | Description                                                  |
|--------------|--------|----------|--------------------------------------------------------------|
| `requestId`  | string | Yes      | Echoed from request for tracing/idempotency                  |
| `timestamp`  | string | Yes      | UTC ISO-8601, when the response was generated                |
| `message`    | string | Yes      | Plain-language text for text-to-speech. Short, simple sentences at ~4th-grade reading level. |
| `resources`  | array  | Yes      | Matching resources. May be empty if none found.              |

### Resource Object

| Field          | Type         | Required | Description                                                    |
|----------------|--------------|----------|----------------------------------------------------------------|
| `id`           | string (uuid)| Yes      | Unique resource identifier                                     |
| `name`         | string       | Yes      | Organization name                                              |
| `category`     | string       | Yes      | Resource type: "Shelter", "Food", etc.                         |
| `eligibility`  | string       | No       | Who can use it: "After hours - family", "18 - 24 years old", etc. |
| `address`      | string       | Yes      | Street address                                                 |
| `lat`          | number       | Yes      | Latitude                                                       |
| `lng`          | number       | Yes      | Longitude                                                      |
| `distanceKm`   | number       | No       | Distance from user's location in km. `null` if location not provided in request. |
| `hours`        | string       | No       | Days/times of operation as free text                           |
| `phone`        | string       | No       | Phone number for call button. `null` if unavailable.           |
| `description`  | string       | No       | Additional notes. `null` if none.                              |

## Error Response (HTTP 400)

Returned for validation failures.

```json
{
  "requestId": "9e5d4f53-0db8-4f77-b4e8-e38f73b6b2cc",
  "timestamp": "2026-03-15T16:42:10Z",
  "error": "queryText is required"
}
```

### Validation Rules

- Empty `queryText` → 400
- `queryText` longer than 500 characters → 400
- `language` not `en-US` → 400
- `location` provided with missing `lat` or `lng` → 400

## Graceful Degradation (HTTP 200)

When the backend encounters an internal error (e.g., LLM service unavailable), it returns HTTP 200 with a user-friendly message and empty resources:

```json
{
  "requestId": "9e5d4f53-0db8-4f77-b4e8-e38f73b6b2cc",
  "timestamp": "2026-03-15T16:42:12Z",
  "message": "Sorry, I'm having trouble right now. Please try again.",
  "resources": []
}
```

The frontend should always read `message` aloud regardless of whether `resources` is empty.

## Frontend Usage Notes

- **Text-to-speech:** Read `message` aloud. It is written in simple, clear language.
- **Resource cards:** Render each item in `resources` as a card with name, address, and hours.
- **Call button:** Show a call button if `phone` is not null.
- **Map/directions:** Use `lat`/`lng` to open Apple Maps or show distance. `distanceKm` can be displayed as "X km away".
- **Empty state:** If `resources` is empty, still read `message` aloud — it will explain the situation.

## Ownership Note

This contract is maintained by the backend team. Changes will be communicated before implementation.
