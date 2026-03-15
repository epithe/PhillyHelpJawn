# PhillyHelpJawn MVP Request Contract (Frontend -> Backend AI)

This document defines the proposed request payload that the iPhone frontend sends to the backend AI service after push-to-talk speech is converted to text on-device.

## Endpoint

- Method: `POST`
- Path: `/v1/assist/query`

## Request Body (Proposed JSON)

```json
{
  "requestId": "9e5d4f53-0db8-4f77-b4e8-e38f73b6b2cc",
  "timestamp": "2026-03-15T16:42:10Z",
  "inputModality": "voice_ptt",
  "queryText": "I need somewhere to get food tonight",
  "language": "en-US",
  "persona": "primary_low_literacy",
  "location": {
    "lat": 39.9526,
    "lng": -75.1652,
    "accuracyMeters": 40
  },
  "client": {
    "platform": "ios",
    "appVersion": "0.1.0",
    "buildNumber": "12"
  },
  "session": {
    "sessionId": "2f2d4f98-2f0c-4578-bf00-4a84a5e28f47",
    "turnIndex": 1
  }
}
```

## Required Fields (MVP)

- `requestId`: idempotency and tracing
- `timestamp`: UTC ISO-8601 timestamp
- `inputModality`: use `voice_ptt` for MVP
- `queryText`: final speech-to-text output from device
- `language`: `en-US` for MVP
- `client.platform`: `ios`

## Optional but Recommended

- `location`: improves ranking and route relevance
- `session`: enables multi-turn continuity later
- `persona`: allows downstream formatting/prompt behavior

## Backend Assumptions

- Frontend sends text only in MVP (no audio upload).
- `queryText` is already processed by on-device STT.
- Query text can be informal or noisy; backend should normalize and classify intent (`food` or `shelter`).
- If location is missing, backend should still return best available city-level result.

## Basic Validation Rules

- Reject empty `queryText`.
- Max `queryText` length: 500 characters.
- `language` must be supported (`en-US` in MVP).
- If `location` is provided, require both `lat` and `lng`.

## Ownership Note

Final API request and response contracts will be finalized with the backend team.
