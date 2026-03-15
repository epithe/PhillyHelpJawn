import { createClient } from "@supabase/supabase-js";
import { SearchResourcesInputSchema } from "./types.js";
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

  const { category, eligibility } = parsed.data;
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

  return data as Resource[];
}
