import { createClient } from "@supabase/supabase-js";
import { SearchResourcesInputSchema } from "./types.js";
import { isOpenAt } from "./schedule.js";
import type { Resource } from "./types.js";

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
);

export async function searchResources(
  rawInput: unknown
): Promise<Resource[]> {
  const parsed = SearchResourcesInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    console.error("Invalid tool input:", parsed.error.issues);
    return [];
  }

  const { category, eligibility, targetDay, targetTime } = parsed.data;
  let query = supabase.from("resources").select("*");

  if (category) {
    // ilike for case-insensitive match (Claude may send "shelter" vs "Shelter")
    query = query.ilike("category", category);
  }
  if (eligibility) {
    query = query.ilike("eligibility", `%${eligibility}%`);
  }

  const { data, error } = await query;

  if (error) {
    console.error("Supabase query error:", error);
    return [];
  }

  const allResults = data as (Resource & { schedule?: any })[];

  // Filter to resources open at the target time (defaults to now)
  return allResults.filter((r) =>
    isOpenAt(r.schedule, { targetDay, targetTime })
  );
}
