import { z } from "zod";

// --- Resource (DB row) ---

export const ResourceSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  category: z.string(),
  eligibility: z.string().nullable(),
  address: z.string(),
  lat: z.number(),
  lng: z.number(),
  hours: z.string().nullable(),
  phone: z.string().nullable(),
  description: z.string().nullable(),
});

export type Resource = z.infer<typeof ResourceSchema>;

export const ResourceWithDistanceSchema = ResourceSchema.extend({
  distanceKm: z.number().nullable(),
});

export type ResourceWithDistance = z.infer<typeof ResourceWithDistanceSchema>;

// --- Request validation ---

export const AssistRequestSchema = z.object({
  requestId: z.string().min(1, "requestId is required"),
  timestamp: z.string(),
  inputModality: z.string(),
  queryText: z
    .string()
    .min(1, "queryText is required")
    .max(500, "queryText must be 500 characters or fewer"),
  language: z.literal("en-US", { error: "Only en-US is supported" }),
  persona: z.string().optional(),
  location: z
    .object({
      lat: z.number(),
      lng: z.number(),
      accuracyMeters: z.number().optional(),
    })
    .optional(),
  client: z.object({
    platform: z.string(),
    appVersion: z.string().optional(),
    buildNumber: z.string().optional(),
  }),
  session: z
    .object({
      sessionId: z.string(),
      turnIndex: z.number(),
    })
    .optional(),
});

export type AssistRequest = z.infer<typeof AssistRequestSchema>;

// --- Response types (not validated, we produce these) ---

export interface AssistResponse {
  requestId: string;
  timestamp: string;
  message: string;
  resources: ResourceWithDistance[];
  crisis: "suicide" | "emergency" | "child_safety" | null;
  actionPhone: string | null;
}

export interface ErrorResponse {
  requestId: string;
  timestamp: string;
  error: string;
}

// --- Tool input schema ---

export const SearchResourcesInputSchema = z.object({
  category: z
    .string()
    .describe(
      'The type of resource: "Shelter", "Food", etc. Leave empty to search all categories.'
    )
    .optional(),
  eligibility: z
    .string()
    .describe(
      'Filter by who can use it, e.g. "family", "youth", "male", "female". Leave empty for no filter.'
    )
    .optional(),
  targetDay: z
    .string()
    .describe(
      'Day to search for, e.g. "monday", "tuesday". Defaults to today. Use when the user asks about a future day.'
    )
    .optional(),
  targetTime: z
    .string()
    .describe(
      'Time to search for in HH:MM 24hr format, e.g. "14:00". Defaults to right now. Use when the user asks about a specific time.'
    )
    .optional(),
});

export type SearchResourcesInput = z.infer<typeof SearchResourcesInputSchema>;
