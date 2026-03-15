import { describe, it, expect } from "vitest";
import { isOpenNow } from "../src/schedule.js";
import type { TimeWindow } from "../src/schedule.js";

// Helper to create a Date in ET for testing
function etDate(
  day: string,
  hour: number,
  minute: number = 0
): Date {
  // 2026-03-16 is a Monday
  const dayOffsets: Record<string, number> = {
    monday: 0,
    tuesday: 1,
    wednesday: 2,
    thursday: 3,
    friday: 4,
    saturday: 5,
    sunday: 6,
  };
  const base = new Date("2026-03-16T00:00:00-04:00"); // Monday ET
  base.setDate(base.getDate() + dayOffsets[day]);
  base.setHours(hour, minute, 0, 0);
  return base;
}

describe("isOpenNow", () => {
  const mondayLunch: TimeWindow[] = [
    { day: "monday", open: "11:00", close: "14:00" },
  ];

  const multiDay: TimeWindow[] = [
    { day: "tuesday", open: "09:00", close: "12:00" },
    { day: "thursday", open: "15:00", close: "17:00" },
  ];

  const weekdays: TimeWindow[] = [
    { day: "monday", open: "07:00", close: "17:00" },
    { day: "tuesday", open: "07:00", close: "17:00" },
    { day: "wednesday", open: "07:00", close: "17:00" },
    { day: "thursday", open: "07:00", close: "17:00" },
    { day: "friday", open: "07:00", close: "17:00" },
  ];

  const overnightSplit: TimeWindow[] = [
    { day: "monday", open: "17:00", close: "23:59" },
    { day: "tuesday", open: "00:00", close: "07:00" },
  ];

  it("returns true when open", () => {
    expect(isOpenNow(mondayLunch, etDate("monday", 12, 30))).toBe(true);
  });

  it("returns true at exact open time", () => {
    expect(isOpenNow(mondayLunch, etDate("monday", 11, 0))).toBe(true);
  });

  it("returns false at exact close time", () => {
    expect(isOpenNow(mondayLunch, etDate("monday", 14, 0))).toBe(false);
  });

  it("returns false on wrong day", () => {
    expect(isOpenNow(mondayLunch, etDate("tuesday", 12, 30))).toBe(false);
  });

  it("handles multi-day schedule", () => {
    expect(isOpenNow(multiDay, etDate("tuesday", 10, 0))).toBe(true);
    expect(isOpenNow(multiDay, etDate("thursday", 16, 0))).toBe(true);
    expect(isOpenNow(multiDay, etDate("wednesday", 10, 0))).toBe(false);
  });

  it("handles weekday schedule", () => {
    expect(isOpenNow(weekdays, etDate("monday", 9, 0))).toBe(true);
    expect(isOpenNow(weekdays, etDate("friday", 16, 0))).toBe(true);
    expect(isOpenNow(weekdays, etDate("saturday", 10, 0))).toBe(false);
  });

  it("handles overnight split", () => {
    expect(isOpenNow(overnightSplit, etDate("monday", 20, 0))).toBe(true);
    expect(isOpenNow(overnightSplit, etDate("tuesday", 3, 0))).toBe(true);
    expect(isOpenNow(overnightSplit, etDate("tuesday", 10, 0))).toBe(false);
  });

  it("returns false for null schedule", () => {
    expect(isOpenNow(null, etDate("monday", 12, 0))).toBe(false);
  });

  it("returns false for empty schedule", () => {
    expect(isOpenNow([], etDate("monday", 12, 0))).toBe(false);
  });
});
