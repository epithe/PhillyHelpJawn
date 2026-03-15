import "dotenv/config";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { serve } from "@hono/node-server";
import { handleQuery } from "./agent.js";
import { computeDistance } from "./geo.js";
import { AssistRequestSchema } from "./types.js";
import type {
  AssistResponse,
  ErrorResponse,
  ResourceWithDistance,
} from "./types.js";

function formatPhone(raw: string): string {
  // Handle comma-separated multiple numbers
  return raw
    .split(",")
    .map((num) => {
      const digits = num.trim().replace(/\D/g, "");
      if (digits.length === 10) {
        return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
      }
      if (digits.length === 11 && digits[0] === "1") {
        return `1-${digits.slice(1, 4)}-${digits.slice(4, 7)}-${digits.slice(7)}`;
      }
      return num.trim();
    })
    .join(", ");
}

const app = new Hono();
app.use("*", cors());

app.post("/v1/assist/query", async (c) => {
  const body = await c.req.json();

  const parsed = AssistRequestSchema.safeParse(body);
  if (!parsed.success) {
    const firstError = parsed.error.issues[0].message;
    const errResp: ErrorResponse = {
      requestId: body.requestId ?? "unknown",
      timestamp: new Date().toISOString(),
      error: firstError,
    };
    return c.json(errResp, 400);
  }

  const req = parsed.data;

  try {
    const { message, resources, crisis, actionPhone } = await handleQuery(req.queryText, {
      location: req.location,
    });

    const resourcesWithDistance: ResourceWithDistance[] = resources.map(
      (r) => ({
        ...r,
        phone: r.phone ? formatPhone(r.phone) : null,
        distanceKm: req.location
          ? Math.round(
              computeDistance(req.location.lat, req.location.lng, r.lat, r.lng) *
                10
            ) / 10
          : null,
      })
    );

    if (req.location) {
      resourcesWithDistance.sort(
        (a, b) => (a.distanceKm ?? Infinity) - (b.distanceKm ?? Infinity)
      );
    }

    const response: AssistResponse = {
      requestId: req.requestId,
      timestamp: new Date().toISOString(),
      message,
      resources: resourcesWithDistance,
      crisis,
      actionPhone,
    };

    return c.json(response);
  } catch (err) {
    console.error("Agent error:", err);
    const response: AssistResponse = {
      requestId: req.requestId,
      timestamp: new Date().toISOString(),
      message: "Sorry, I'm having trouble right now. Please try again.",
      resources: [],
      crisis: null,
      actionPhone: null,
    };
    return c.json(response);
  }
});

const port = Number(process.env.PORT) || 3000;
serve({ fetch: app.fetch, port }, () => {
  console.log(`PhillyHelpJawn backend running on http://localhost:${port}`);
});
