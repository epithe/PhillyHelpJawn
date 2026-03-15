# PhillyHelpJawn

PhillyHelpJawn is an iPhone-first assistant that helps people in Philadelphia find basic-needs services such as food and shelter through a voice-forward and low-literacy-friendly interface.

## Purpose

Many people in Philadelphia need help accessing essential services. PhillyHelpJawn aims to provide a simple, factual, and accessible way to discover relevant local resources.

## Hackathon MVP Scope

This repository currently focuses on the frontend MVP for a hackathon build.

- Platform: native iPhone app frontend
- Primary journey: ask for help finding food or shelter
- Input: push-to-talk voice query
- Output: response shown visually and read aloud automatically
- Experience style: speech-heavy UX with icon-based interaction support
- Response behavior: factual information only (no nudging to follow-up actions)
- Language: English for MVP, multilingual support planned later
- Connectivity: online-first for MVP; intermittent/offline support later

## Default User Persona

The default user persona is someone who:

- may be functionally low literacy
- may use a low-powered/basic mobile device
- may have inconsistent connectivity (future phase support)

## Team

- Malcolm: native iPhone frontend development
- Em: backend platform development
- Georgette: initial resource list curation
- Karl: low-literacy UI design language

## Success Criteria (Current)

The MVP is successful when a user can complete a single end-to-end journey for food or shelter and receive an appropriate answer in a consumable form (voice and/or graphics).

## Default MVP User Flow

1. User presses a push-to-talk button and makes a spoken query.
2. Spoken query asks for food or shelter help based on backend data.
3. Query is sent to the backend through an API.
4. Backend uses AI over approved data to find an appropriate response.
5. Response is sent back to the iPhone device.
6. Response may include speech text, map coordinates or identifiers, and other metadata (for example open times).
7. Device automatically speaks response text and may display a map route and supporting metadata graphics.

## MVP Guardrails

- Keep interaction factual and informational; do not nudge users into follow-up actions.
- Ensure both food and shelter queries are supported in the MVP journey.
- Ensure response includes speech-ready text so voice output always works.
- Support optional map and metadata rendering when location and service details are available.
- Keep architecture ready for multilingual and intermittent-connectivity expansion later.
- API response shape will be finalized with the backend team; frontend should integrate against the agreed contract.

## Current Project Status

This repo is in early MVP setup. The product intent and implementation scope are defined, and frontend implementation is focused on the first food/shelter experience.

## Planned Next Steps

1. Implement iPhone push-to-talk flow.
2. Integrate speech-to-text and text-to-speech in the frontend.
3. Connect frontend query flow to approved resource data backend.
4. Ship a single polished food/shelter journey for demo.
5. Add multilingual and intermittent-connectivity support in later phases.

## Contributing (Hackathon)

- Keep changes focused on MVP scope.
- Prioritize accessibility and low-literacy usability.
- Avoid adding features outside the defined single-journey demo goal.
