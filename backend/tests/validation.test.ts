import { describe, it, expect } from "vitest";
import { AssistRequestSchema } from "../src/types.js";

describe("AssistRequestSchema", () => {
  const validBody = {
    requestId: "abc-123",
    timestamp: "2026-03-15T16:42:10Z",
    inputModality: "voice_ptt",
    queryText: "I need food",
    language: "en-US" as const,
    client: { platform: "ios" },
  };

  it("accepts a valid request", () => {
    const result = AssistRequestSchema.safeParse(validBody);
    expect(result.success).toBe(true);
  });

  it("rejects missing requestId", () => {
    const { requestId, ...noId } = validBody;
    const result = AssistRequestSchema.safeParse(noId);
    expect(result.success).toBe(false);
  });

  it("rejects empty queryText", () => {
    const result = AssistRequestSchema.safeParse({
      ...validBody,
      queryText: "",
    });
    expect(result.success).toBe(false);
    expect(result.error!.issues[0].message).toBe("queryText is required");
  });

  it("rejects queryText over 500 chars", () => {
    const result = AssistRequestSchema.safeParse({
      ...validBody,
      queryText: "a".repeat(501),
    });
    expect(result.success).toBe(false);
    expect(result.error!.issues[0].message).toBe(
      "queryText must be 500 characters or fewer"
    );
  });

  it("accepts any language", () => {
    const result = AssistRequestSchema.safeParse({
      ...validBody,
      language: "es",
    });
    expect(result.success).toBe(true);
  });

  it("rejects location with missing lng", () => {
    const result = AssistRequestSchema.safeParse({
      ...validBody,
      location: { lat: 39.95 },
    });
    expect(result.success).toBe(false);
  });

  it("accepts request with valid location", () => {
    const result = AssistRequestSchema.safeParse({
      ...validBody,
      location: { lat: 39.95, lng: -75.16 },
    });
    expect(result.success).toBe(true);
  });

  it("accepts optional fields when omitted", () => {
    const result = AssistRequestSchema.safeParse(validBody);
    expect(result.success).toBe(true);
    expect(result.data!.persona).toBeUndefined();
    expect(result.data!.location).toBeUndefined();
    expect(result.data!.session).toBeUndefined();
  });

  it("accepts request with all optional fields", () => {
    const result = AssistRequestSchema.safeParse({
      ...validBody,
      persona: "primary_low_literacy",
      location: { lat: 39.95, lng: -75.16, accuracyMeters: 40 },
      session: { sessionId: "sess-1", turnIndex: 1 },
    });
    expect(result.success).toBe(true);
  });
});
