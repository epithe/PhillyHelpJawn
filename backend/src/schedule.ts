export interface TimeWindow {
  day: string;
  open: string; // "HH:MM" 24hr
  close: string;
}

const DAYS = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
] as const;

export interface TimeQuery {
  now?: Date;
  targetDay?: string;
  targetTime?: string;
}

export function isOpenAt(
  schedule: TimeWindow[] | null,
  query?: TimeQuery
): boolean {
  if (!schedule || schedule.length === 0) return false;

  const dt = query?.now ?? new Date();
  const philly = new Date(
    dt.toLocaleString("en-US", { timeZone: "America/New_York" })
  );

  const dayName = query?.targetDay?.toLowerCase() ?? DAYS[philly.getDay()];
  const currentTime =
    query?.targetTime ??
    philly.getHours().toString().padStart(2, "0") +
      ":" +
      philly.getMinutes().toString().padStart(2, "0");

  return schedule.some(
    (w) => w.day === dayName && currentTime >= w.open && currentTime < w.close
  );
}

// Convenience alias
export function isOpenNow(
  schedule: TimeWindow[] | null,
  now?: Date
): boolean {
  return isOpenAt(schedule, { now });
}
