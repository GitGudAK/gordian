// Fixture replay through the Gemini adapter's parse/repair path, plus
// adapter wire-shape assertions (Gemini schema constants, Anthropic body).
// Fixtures are the REAL captured responses from spike 002.

import { describe, it, expect, beforeAll, afterEach } from "vitest";
import { installFetchMock, clearFetchMocks, mockOnce, GEMINI_ORIGIN, ANTHROPIC_ORIGIN } from "./helpers/fetch-mock";
import { cleanJSONText, extractText, repairAndParse, generateStructured as geminiGenerate } from "../src/providers/gemini";
import { generateStructured as anthropicGenerate } from "../src/providers/anthropic";
import { UpstreamError } from "../src/providers/types";
import * as ops from "../src/operations";
import questionsFixture from "./fixtures/response-questions.json";
import verdictFixture from "./fixtures/response-verdict.json";
import errorFixture from "./fixtures/response-error.json";
import truncatedFixture from "./fixtures/response-truncated.json";

const structuredReq = {
  system: "system",
  user: "user",
  geminiSchema: ops.SESSION_PLAN_GEMINI_SCHEMA,
  anthropicSchema: ops.SESSION_PLAN_ANTHROPIC_SCHEMA,
  temperature: ops.TEMPERATURE,
};

beforeAll(() => {
  installFetchMock();
});

afterEach(() => {
  clearFetchMocks();
});

describe("fixture replay: parse path", () => {
  it("parses the captured questions response (ARRAY payload)", () => {
    const text = extractText(questionsFixture as never);
    const parsed = repairAndParse(text) as string[];
    expect(Array.isArray(parsed)).toBe(true);
    expect(parsed).toHaveLength(12);
    expect(parsed[0]).toContain("?");
  });

  it("parses the captured verdict response (OBJECT payload)", () => {
    const text = extractText(verdictFixture as never);
    const parsed = repairAndParse(text) as Record<string, string>;
    expect(parsed["sentiment"]).toBe("EMERGENT CLARITY");
    expect(parsed["analysis"]).toBeTruthy();
    expect(parsed["probe"]).toBeTruthy();
  });

  it("concatenates ALL parts, never parts[0] alone", () => {
    const full = extractText(verdictFixture as never);
    const mid = Math.floor(full.length / 2);
    const multiPart = {
      candidates: [
        { content: { parts: [{ text: full.slice(0, mid) }, { text: full.slice(mid) }] } },
      ],
    };
    expect(extractText(multiPart as never)).toBe(full);
    expect(repairAndParse(extractText(multiPart as never))).toEqual(repairAndParse(full));
  });

  it("strips markdown fences", () => {
    expect(repairAndParse('```json\n{"a": 1}\n```')).toEqual({ a: 1 });
    expect(cleanJSONText("```\n[1]\n```")).toBe("[1]");
  });

  it("repairs a trailing comma", () => {
    expect(repairAndParse('["one", "two",')).toEqual(["one", "two"]);
  });

  it("repairs the truncated fixture (dropped closing brace, finishReason STOP)", () => {
    const text = extractText(truncatedFixture as never);
    expect(() => JSON.parse(text)).toThrow(); // genuinely truncated as captured
    const parsed = repairAndParse(text) as { mode: string; questions: string[] };
    expect(parsed.mode).toBe("YES_NO");
    expect(parsed.questions.length).toBeGreaterThan(0);
  });

  it("repairs a truncated ARRAY (the spike's ~40% failure mode)", () => {
    expect(repairAndParse('["a", "b", "c"')).toEqual(["a", "b", "c"]);
  });

  it("throws UpstreamError on irreparable garbage", () => {
    expect(() => repairAndParse("the model apologizes profusely")).toThrow(UpstreamError);
  });
});

describe("gemini adapter wire behavior", () => {
  it("maps the captured upstream error envelope to UpstreamError with its message", async () => {
    mockOnce(GEMINI_ORIGIN, () => Response.json(errorFixture, { status: 400 }));
    await expect(
      geminiGenerate(structuredReq, "gemini-3.5-flash", { GEMINI_API_KEY: "test-key" }),
    ).rejects.toThrow("API key not valid");
  });

  it("sends the key as x-goog-api-key header with responseSchema, no ?key= param", async () => {
    let captured: Request | undefined;
    let capturedBody: Record<string, unknown> = {};
    mockOnce(GEMINI_ORIGIN, async (req) => {
      captured = req;
      capturedBody = (await req.json()) as Record<string, unknown>;
      return Response.json(questionsFixture);
    });

    await geminiGenerate(structuredReq, "gemini-3.5-flash", { GEMINI_API_KEY: "test-key" });
    expect(captured).toBeDefined();
    const url = new URL(captured!.url);
    expect(url.pathname).toContain(":generateContent");
    expect(url.search).not.toContain("key=");
    expect(captured!.headers.get("x-goog-api-key")).toBe("test-key");
    const config = capturedBody["generationConfig"] as Record<string, unknown>;
    expect(config["responseMimeType"]).toBe("application/json");
    expect(config["responseSchema"]).toEqual(ops.SESSION_PLAN_GEMINI_SCHEMA);
    expect(config["maxOutputTokens"]).toBeUndefined();
  });
});

describe("anthropic adapter wire behavior", () => {
  it("builds a Messages body with max_tokens and output_config json_schema", async () => {
    let capturedBody: Record<string, unknown> = {};
    mockOnce(ANTHROPIC_ORIGIN, async (req) => {
      capturedBody = (await req.json()) as Record<string, unknown>;
      return Response.json({ content: [{ type: "text", text: '{"ok":true}' }] });
    });

    const text = await anthropicGenerate(structuredReq, "claude-haiku-4-5", {
      ANTHROPIC_API_KEY: "test-key",
    });
    expect(JSON.parse(text)).toEqual({ ok: true });
    expect(capturedBody["max_tokens"]).toBe(1024);
    const format = (capturedBody["output_config"] as Record<string, Record<string, unknown>>)["format"];
    expect(format["type"]).toBe("json_schema");
    expect(format["schema"]).toEqual(ops.SESSION_PLAN_ANTHROPIC_SCHEMA);
  });

  it("throws UpstreamError without a configured key", async () => {
    await expect(anthropicGenerate(structuredReq, "claude-haiku-4-5", {})).rejects.toThrow(
      UpstreamError,
    );
  });
});

describe("schema constants (REQ-005 guard)", () => {
  it("gemini schemas require every declared property", () => {
    for (const schema of [ops.SESSION_PLAN_GEMINI_SCHEMA, ops.VERDICT_GEMINI_SCHEMA]) {
      expect([...schema.required].sort()).toEqual(Object.keys(schema.properties).sort());
      expect(schema.type).toBe("OBJECT");
    }
  });

  it("anthropic schemas mirror them in lowercase with additionalProperties false", () => {
    for (const schema of [ops.SESSION_PLAN_ANTHROPIC_SCHEMA, ops.VERDICT_ANTHROPIC_SCHEMA]) {
      expect(schema.type).toBe("object");
      expect(schema.additionalProperties).toBe(false);
      expect([...schema.required].sort()).toEqual(Object.keys(schema.properties).sort());
    }
  });
});

describe("prompt port (verbatim sentinels)", () => {
  it("session-plan prompt carries the Swift prompt text with the scenario interpolated", () => {
    const system = ops.sessionPlanSystem("Should I learn Spanish or German?");
    expect(system).toContain("rapid gut-instinct bypass");
    expect(system).toContain("The user has a dilemma: 'Should I learn Spanish or German?'");
    expect(system).toContain("Output ONLY the JSON object.");
  });

  it("session-plan prompt includes the STEP 0 safety gate (SENSITIVE mode)", () => {
    const system = ops.sessionPlanSystem("x");
    expect(system).toContain("STEP 0 — SAFETY GATE");
    expect(system).toContain("mode='SENSITIVE'");
  });

  it("verdict prompt reconstructs the rapid-fire transcript in the exact Swift line format", () => {
    const answers = [
      { question: "Q1?", choice: "YES", reflection: "" },
      { question: "Q2?", choice: "NO", reflection: "felt heavy" },
    ];
    const system = ops.verdictSystem("Quit my job?", answers);
    expect(system).toContain("1. Q: Q1? -> Response: YES ");
    expect(system).toContain("2. Q: Q2? -> Response: NO (Reflection: felt heavy)");
    expect(ops.rapidFireText([])).toBe("None (User was silent during rapid-fire)");
  });
});
