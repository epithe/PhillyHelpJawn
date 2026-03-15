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
