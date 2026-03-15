import Anthropic from "@anthropic-ai/sdk";
import { searchResources } from "./db.js";
import { SearchResourcesInputSchema } from "./types.js";
import type { Resource } from "./types.js";
import { zodToToolSchema } from "./zodToToolSchema.js";

const client = new Anthropic();

function getSystemPrompt(): string {
  const now = new Date().toLocaleString("en-US", {
    timeZone: "America/New_York",
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });

  return `You are a friendly helper for people in Philadelphia who need social services like food and shelter. You play a critical role in connecting low-literacy individuals with resources that they would otherwise be unable to find.

CURRENT DATE AND TIME (Philadelphia): ${now}

IMPORTANT RULES:
- Use very simple words and short sentences. Write at a 4th-grade reading level.
- Be warm and kind. These people may be in a tough spot.
- Always mention the name, address, and hours of each place you recommend.
- Recommend at most 3 places. Pick the most relevant ones.
- If someone sounds scared or urgent, respond with extra care, prioritize immediate help, and recommend only 1 place — the single best option. Keep it short so they can act fast.
- You are time-aware. The current date and time will be provided. ALWAYS prioritize places that are open RIGHT NOW or opening very soon. If a place is closed today, say when it next opens. Do not recommend closed places without mentioning they are closed.
- If you're not sure what they need, make your best guess from what they said. Do not ask follow-up questions.
- Only recommend places from the search results. Never make up places.
- If no results match, say so kindly and suggest they call 211 for help.
- Stay focused on your mission of connecting individuals to existing resources. If user queries are off-topic, respond by affirming that you can help to connect the user with community resources.

CRISIS DETECTION — HIGHEST PRIORITY:
- If someone mentions hurting themselves, suicide, wanting to die, or not wanting to be alive, IMMEDIATELY call the report_crisis tool with type "suicide" and then respond: "It sounds like you are going through something really hard. Please call or text 988 right now. They are free, private, and available all day and night. You do not have to go through this alone."
- If someone is in immediate physical danger (domestic violence, assault, medical emergency), call report_crisis with type "emergency" and respond: "If you are in danger right now, please call 911. They can send help to you."
- If a child seems to be alone, lost, or in danger, call report_crisis with type "child_safety" and respond: "If a child is hurt or in danger, please call 911. You can also call Childline at 1-800-932-0313. They help keep kids safe."
- Always call the report_crisis tool BEFORE using search_resources when a crisis is detected.

SCOPE — THIS IS NOT A GENERAL-PURPOSE ASSISTANT:
- You can ONLY help people find social services in Philadelphia.
- You MUST call a tool for EVERY user message: search_resources, report_crisis, or redirect. Never respond without using a tool first.
- Use search_resources when the user has a need you can search for.
- Use report_crisis when you detect a crisis (see above).
- Use redirect for everything else: greetings, thank-yous, off-topic requests, unclear messages, questions about services not in the database.
- When using redirect for off-topic requests, respond ONLY with: "I can help you find food, shelter, and other services in Philadelphia. What do you need help with?"
- When using redirect for greetings or gratitude, be warm and brief, then remind them what you can help with.
- Do not role-play, tell stories, write content, or answer general knowledge questions.

BOUNDARIES:
- Never give medical, legal, or financial advice.
- Never diagnose conditions or suggest treatments.
- You are not a counselor. For emotional support beyond a crisis, suggest they call 211.`;
}

const SEARCH_TOOL: Anthropic.Tool = {
  name: "search_resources",
  description:
    "Search for social service resources in Philadelphia. Use this to find shelters, food banks, and other services.",
  input_schema: zodToToolSchema(SearchResourcesInputSchema),
};

const CRISIS_TOOL: Anthropic.Tool = {
  name: "report_crisis",
  description:
    "Call this IMMEDIATELY when a user appears to be in crisis. This flags the response so the app can show emergency UI.",
  input_schema: {
    type: "object" as const,
    properties: {
      type: {
        type: "string",
        enum: ["suicide", "emergency", "child_safety"],
        description: "The type of crisis detected.",
      },
    },
    required: ["type"],
  },
};

const REDIRECT_TOOL: Anthropic.Tool = {
  name: "redirect",
  description:
    "Call this when the user's message is not something you can search for and is not a crisis. Examples: greetings, thank-yous, requests you can't fulfill, questions about services not in the database, off-topic requests.",
  input_schema: {
    type: "object" as const,
    properties: {
      reason: {
        type: "string",
        enum: [
          "greeting",
          "out_of_scope",
          "unclear",
          "gratitude",
          "meta_question",
        ],
        description: "Why this can't be handled with a resource search.",
      },
    },
    required: ["reason"],
  },
};

const TOOLS = [SEARCH_TOOL, CRISIS_TOOL, REDIRECT_TOOL];

export type CrisisType = "suicide" | "emergency" | "child_safety";
export type RedirectReason =
  | "greeting"
  | "out_of_scope"
  | "unclear"
  | "gratitude"
  | "meta_question";

export interface AgentResult {
  message: string;
  resources: Resource[];
  crisis: CrisisType | null;
}

export async function handleQuery(queryText: string): Promise<AgentResult> {
  let collectedResources: Resource[] = [];
  let detectedCrisis: CrisisType | null = null;
  let redirectReason: RedirectReason | null = null;

  const messages: Anthropic.MessageParam[] = [
    { role: "user", content: queryText },
  ];

  let response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    system: getSystemPrompt(),
    tools: TOOLS,
    messages,
  });

  // Tool use loop — Claude may call search_resources and/or report_crisis
  while (response.stop_reason === "tool_use") {
    const toolBlock = response.content.find(
      (block): block is Anthropic.ToolUseBlock => block.type === "tool_use"
    );

    if (!toolBlock) break;

    let toolResult: string;

    if (toolBlock.name === "search_resources") {
      const results = await searchResources(toolBlock.input);
      collectedResources = [...collectedResources, ...results];
      toolResult = JSON.stringify(results);
    } else if (toolBlock.name === "report_crisis") {
      const input = toolBlock.input as { type: CrisisType };
      detectedCrisis = input.type;
      toolResult = JSON.stringify({ acknowledged: true, type: input.type });
    } else if (toolBlock.name === "redirect") {
      const input = toolBlock.input as { reason: RedirectReason };
      redirectReason = input.reason;
      toolResult = JSON.stringify({ acknowledged: true });
    } else {
      toolResult = JSON.stringify({ error: "Unknown tool" });
    }

    messages.push({ role: "assistant", content: response.content });
    messages.push({
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: toolBlock.id,
          content: toolResult,
        },
      ],
    });

    response = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      system: getSystemPrompt(),
      tools: TOOLS,
      messages,
    });
  }

  const textBlock = response.content.find(
    (block): block is Anthropic.TextBlock => block.type === "text"
  );

  // Server-side guardrail: if Claude never called any tool, it went off-script.
  // This catches prompt injection and off-topic requests that bypass the system prompt.
  const usedAnyTool =
    collectedResources.length > 0 ||
    detectedCrisis !== null ||
    redirectReason !== null;
  if (!usedAnyTool) {
    return {
      message:
        "I'm not sure how to help with that, but I can help you find food, shelter, and other services in Philadelphia. You can also call 211 for more help.",
      resources: [],
      crisis: null,
    };
  }

  return {
    message: textBlock?.text ?? "Sorry, I could not find an answer right now.",
    resources: collectedResources,
    crisis: detectedCrisis,
  };
}
