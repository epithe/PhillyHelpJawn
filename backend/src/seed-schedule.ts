import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import type { TimeWindow } from "./schedule.js";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SECRET_KEY!
);

const WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday"];
const ALL_DAYS = [...WEEKDAYS, "saturday", "sunday"];

function weekdays(open: string, close: string): TimeWindow[] {
  return WEEKDAYS.map((day) => ({ day, open, close }));
}

function allDays(open: string, close: string): TimeWindow[] {
  return ALL_DAYS.map((day) => ({ day, open, close }));
}

// Overnight: 5pm-7am split across two days, plus full weekends
function afterHours(): TimeWindow[] {
  const windows: TimeWindow[] = [];
  // Weekday evenings
  for (const day of WEEKDAYS) {
    windows.push({ day, open: "17:00", close: "23:59" });
  }
  // Weekday mornings (next day)
  for (const day of ["tuesday", "wednesday", "thursday", "friday"]) {
    windows.push({ day, open: "00:00", close: "07:00" });
  }
  // Monday morning (from Sunday night)
  windows.push({ day: "monday", open: "00:00", close: "07:00" });
  // Full weekends
  windows.push({ day: "saturday", open: "00:00", close: "23:59" });
  windows.push({ day: "sunday", open: "00:00", close: "23:59" });
  return windows;
}

// Hand-mapped from the CSV data
const SCHEDULES: Record<string, TimeWindow[]> = {
  "Appletree Family Center": weekdays("07:00", "17:00"),
  "Roosevelt Darby Center": weekdays("07:00", "17:00"),
  "The Veterans Multi-Service Center": [
    { day: "tuesday", open: "09:00", close: "14:00" },
    { day: "thursday", open: "09:00", close: "14:00" },
  ],
  "Red Shield Family Residence": afterHours(),
  "ACTS After Hour Intake Site": afterHours(),
  "Mike Hinson Resource Center": afterHours(),
  "Gaudenzia\u2019s House of Passage": afterHours(),
  "Youth Access Point: Eddie\u2019s House": weekdays("10:00", "17:00"),
  "Youth Access Point: Synergy Project at Valley Youth House": [
    { day: "monday", open: "08:30", close: "17:30" },
    { day: "tuesday", open: "08:30", close: "17:30" },
    { day: "wednesday", open: "08:30", close: "17:30" },
    { day: "thursday", open: "08:30", close: "17:30" },
    { day: "friday", open: "08:30", close: "15:00" },
  ],
  "Dress for Success Greater Philadelphia": [
    { day: "monday", open: "10:00", close: "18:00" },
    { day: "wednesday", open: "10:00", close: "18:00" },
    { day: "friday", open: "10:00", close: "18:00" },
  ],
  // 4 PA CareerLink locations — all same hours
  "PA CareerLink Employment Services": weekdays("08:00", "16:30"),
  "Mount Tabor CEED Corporation": [
    { day: "monday", open: "12:00", close: "13:00" },
  ],
  "Drueding Center": [
    { day: "tuesday", open: "09:00", close: "12:00" },
    { day: "thursday", open: "15:00", close: "17:00" },
  ],
  "Lutheran Settlement House Senior Center": weekdays("09:00", "15:00"),
  "Saint Paul\u2019s Baptist Church": [
    { day: "wednesday", open: "10:00", close: "13:00" },
  ],
  "5th District Food Access at 10th & Poplar": [
    { day: "friday", open: "14:00", close: "16:00" },
  ],
  "Breaking Bread on Broad": [
    { day: "wednesday", open: "08:00", close: "10:00" },
  ],
};

async function main() {
  const { data: resources, error } = await supabase
    .from("resources")
    .select("id, name");

  if (error || !resources) {
    console.error("Failed to fetch resources:", error);
    return;
  }

  console.log(`Updating schedules for ${resources.length} resources...\n`);

  for (const resource of resources) {
    const schedule = SCHEDULES[resource.name];
    if (!schedule) {
      console.warn(`  ? No schedule mapped for: ${resource.name}`);
      continue;
    }

    const { error: updateError } = await supabase
      .from("resources")
      .update({ schedule })
      .eq("id", resource.id);

    if (updateError) {
      console.error(`  ✗ ${resource.name}: ${updateError.message}`);
    } else {
      console.log(`  ✓ ${resource.name} (${schedule.length} windows)`);
    }
  }

  console.log("\nDone.");
}

main();
