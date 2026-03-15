import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import { parse } from "csv-parse/sync";
import { readFileSync } from "fs";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SECRET_KEY!
);

// Column indices matching the CSV header
const COL = {
  RESOURCE: 0,
  ORGANIZATION: 1,
  LOCATION: 2,
  DETAILS: 3,
  HOURS: 4,
  PHONE1: 5,
  PHONE2: 6,
  PHONE3: 7,
} as const;

async function geocode(
  address: string
): Promise<{ lat: number; lng: number } | null> {
  const query = encodeURIComponent(address);
  const res = await fetch(
    `https://nominatim.openstreetmap.org/search?q=${query}&format=json&limit=1`,
    { headers: { "User-Agent": "PhillyHelpJawn-Hackathon/0.1" } }
  );
  const data = await res.json();
  if (data.length === 0) return null;
  return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) };
}

async function main() {
  const csv = readFileSync("data/PhillyHelpJawn - Data.csv", "utf-8");
  const rows: string[][] = parse(csv, { skip_empty_lines: true });

  // Skip header row, filter out empty rows
  const dataRows = rows.slice(1).filter((row) => row[COL.RESOURCE]?.trim());

  console.log(`Seeding ${dataRows.length} resources...\n`);

  for (const row of dataRows) {
    // Rate limit: Nominatim asks for 1 req/sec
    await new Promise((r) => setTimeout(r, 1100));

    const address = row[COL.LOCATION]?.trim();
    const coords = address ? await geocode(address) : null;
    if (address && !coords) {
      console.warn(`  ! Could not geocode: ${address}`);
    }

    // Combine phone numbers, filtering empties and "none"
    const phones = [row[COL.PHONE1], row[COL.PHONE2], row[COL.PHONE3]]
      .map((p) => p?.trim())
      .filter((p) => p && p.toLowerCase() !== "none");

    const { error } = await supabase.from("resources").insert({
      category: row[COL.RESOURCE]?.trim(),
      name: row[COL.ORGANIZATION]?.trim(),
      address: address || null,
      lat: coords?.lat ?? null,
      lng: coords?.lng ?? null,
      eligibility: row[COL.DETAILS]?.trim() || null,
      hours: row[COL.HOURS]?.trim() || null,
      phone: phones.length > 0 ? phones.join(", ") : null,
      description: null,
    });

    const name = row[COL.ORGANIZATION]?.trim();
    if (error) {
      console.error(`  ✗ ${name}: ${error.message}`);
    } else {
      console.log(
        `  ✓ ${name}${coords ? ` (${coords.lat.toFixed(4)}, ${coords.lng.toFixed(4)})` : " (no coords)"}`
      );
    }
  }

  console.log("\nDone.");
}

main();
