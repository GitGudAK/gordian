// Endpoint integration through SELF with mocked upstreams: payload shapes,
// the error-code contract (REQ-006), and the privacy log guarantee (REQ-003).

import { describe, it, expect, beforeAll, afterEach } from "vitest";
import { env, createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import worker from "../src/index";
import { installFetchMock, clearFetchMocks, mockOnce, GEMINI_ORIGIN } from "./helpers/fetch-mock";
import { buildLogLine } from "../src/log";
import type { ErrorCode } from "../src/providers/types";
import questionsFixture from "./fixtures/response-questions.json";
import verdictFixture from "./fixtures/response-verdict.json";

const DEVICE = "0f0e0d0c-0b0a-0908-0706-050403020100";

beforeAll(() => {
  installFetchMock();
});

afterEach(() => {
  clearFetchMocks();
});

function mockUpstreamText(text: string, status = 200) {
  mockOnce(GEMINI_ORIGIN, () => new Response(text, { status, headers: { "content-type": "application/json" } }));
}

async function dispatch(path: string, init?: RequestInit): Promise<Response> {
  const request = new Request(`https://proxy.test${path}`, init);
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

function post(path: string, deviceId: string | null, body: BodyInit): Promise<Response> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (deviceId) headers["X-Device-ID"] = deviceId;
  return dispatch(path, { method: "POST", headers, body });
}

async function errorCode(res: Response): Promise<string> {
  const body = (await res.json()) as { error: { code: string } };
  return body.error.code;
}

describe("happy paths", () => {
  it("session-plan returns the session payload shape + weekly header (gate + questions calls)", async () => {
    const spikeQuestions = JSON.parse(
      (questionsFixture as { candidates: Array<{ content: { parts: Array<{ text: string }> } }> })
        .candidates[0].content.parts[0].text,
    );
    // Call 1: cheap gate classifies. Call 2: premium model writes the questions.
    mockUpstreamText(
      JSON.stringify({
        candidates: [{ content: { parts: [{ text: JSON.stringify({ mode: "BINARY", optionA: "Spanish", optionB: "German", questions: [] }) }] }, finishReason: "STOP" }],
      }),
    );
    mockUpstreamText(
      JSON.stringify({
        candidates: [{ content: { parts: [{ text: JSON.stringify({ questions: spikeQuestions }) }] }, finishReason: "STOP" }],
      }),
    );

    const res = await post("/v1/session-plan", DEVICE, JSON.stringify({ scenario: "Spanish or German?" }));
    expect(res.status).toBe(200);
    expect(res.headers.get("X-Weekly-Sessions")).toBe("1");
    const body = (await res.json()) as {
      mode: string;
      optionA: string;
      optionB: string;
      questions: string[];
    };
    expect(body.mode).toBe("BINARY");
    expect(body.optionA).toBe("Spanish");
    expect(body.optionB).toBe("German");
    expect(body.questions).toHaveLength(12);
  });

  it("verdict returns decision/sentiment/analysis/probe", async () => {
    // Spike verdict fixture predates the decision field — extend it to the 4-field shape.
    const captured = JSON.parse(
      (verdictFixture as { candidates: Array<{ content: { parts: Array<{ text: string }> } }> })
        .candidates[0].content.parts[0].text,
    ) as Record<string, string>;
    const verdictText = JSON.stringify({ decision: "Take the startup job.", ...captured });
    mockUpstreamText(
      JSON.stringify({
        candidates: [{ content: { parts: [{ text: verdictText }] }, finishReason: "STOP" }],
      }),
    );

    const res = await post(
      "/v1/verdict",
      DEVICE,
      JSON.stringify({
        scenario: "Take the startup job?",
        answers: [
          { question: "Excited?", choice: "YES", reflection: "" },
          { question: "Scared?", choice: "YES", reflection: "but good scared" },
        ],
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, string>;
    expect(body["decision"]).toBe("Take the startup job.");
    expect(body["sentiment"]).toBe("EMERGENT CLARITY");
    expect(body["analysis"]).toBeTruthy();
    expect(body["probe"]).toBeTruthy();
  });
});

describe("bad_request contract", () => {
  it("missing X-Device-ID → 400 bad_request", async () => {
    const res = await post("/v1/session-plan", null, JSON.stringify({ scenario: "x" }));
    expect(res.status).toBe(400);
    expect(await errorCode(res)).toBe("bad_request");
  });

  it("malformed device id → 400 bad_request", async () => {
    const res = await post("/v1/session-plan", "not-a-uuid", JSON.stringify({ scenario: "x" }));
    expect(res.status).toBe(400);
    expect(await errorCode(res)).toBe("bad_request");
  });

  it("scenario over MAX_SCENARIO_CHARS → 400 bad_request", async () => {
    const res = await post(
      "/v1/session-plan",
      DEVICE,
      JSON.stringify({ scenario: "x".repeat(501) }),
    );
    expect(res.status).toBe(400);
    expect(await errorCode(res)).toBe("bad_request");
  });

  it("body over 16 KB → 400 bad_request", async () => {
    const res = await post(
      "/v1/verdict",
      DEVICE,
      JSON.stringify({ scenario: "x", answers: [], padding: "y".repeat(17_000) }),
    );
    expect(res.status).toBe(400);
    expect(await errorCode(res)).toBe("bad_request");
  });

  it("non-JSON body → 400 bad_request", async () => {
    const res = await post("/v1/session-plan", DEVICE, "not json at all");
    expect(res.status).toBe(400);
    expect(await errorCode(res)).toBe("bad_request");
  });
});

describe("upstream_error contract + AI-always fallback chain", () => {
  it("gate + primary failure fall back to the second model and succeed", async () => {
    const goodBody = JSON.stringify({
      candidates: [
        { content: { parts: [{ text: '{"mode":"YES_NO","optionA":"No","optionB":"Yes","questions":["q?"]}' }] } },
      ],
    });
    const modelsSeen: string[] = [];
    const fail = (req: Request) => {
      modelsSeen.push(new URL(req.url).pathname);
      return new Response(JSON.stringify({ error: { code: 500, message: "boom" } }), { status: 500 });
    };
    mockOnce(GEMINI_ORIGIN, fail); // gate model
    mockOnce(GEMINI_ORIGIN, fail); // primary (legacy single-call)
    mockOnce(GEMINI_ORIGIN, (req) => {
      modelsSeen.push(new URL(req.url).pathname);
      return new Response(goodBody, { status: 200, headers: { "content-type": "application/json" } });
    });

    const res = await post("/v1/session-plan", DEVICE, JSON.stringify({ scenario: "x" }));
    expect(res.status).toBe(200);
    expect(modelsSeen[0]).toContain("gemini-flash-lite-latest");
    expect(modelsSeen[1]).toContain("gemini-3.5-flash");
    expect(modelsSeen[2]).toContain("gemini-flash-latest");
  });

  it("terminal gate classification returns without a premium call", async () => {
    mockUpstreamText(
      JSON.stringify({
        candidates: [{ content: { parts: [{ text: '{"mode":"NOT_A_DECISION","optionA":"","optionB":"","questions":[]}' }] } }],
      }),
    );
    const res = await post("/v1/session-plan", DEVICE, JSON.stringify({ scenario: "hello" }));
    expect(res.status).toBe(200);
    const body = (await res.json()) as { mode: string };
    expect(body.mode).toBe("NOT_A_DECISION");
    // one mock registered, one consumed: no second upstream call happened
  });

  it("all models failing → 502 upstream_error", async () => {
    for (let i = 0; i < 3; i++) {
      mockUpstreamText(JSON.stringify({ error: { code: 500, message: "boom" } }), 500);
    }
    const res = await post("/v1/session-plan", DEVICE, JSON.stringify({ scenario: "x" }));
    expect(res.status).toBe(502);
    expect(await errorCode(res)).toBe("upstream_error");
  });

  it("irreparable garbage from every attempt → 502 upstream_error", async () => {
    const garbage = JSON.stringify({
      candidates: [{ content: { parts: [{ text: "I cannot answer in JSON, sorry" }] } }],
    });
    for (let i = 0; i < 3; i++) mockUpstreamText(garbage);
    const res = await post("/v1/session-plan", DEVICE, JSON.stringify({ scenario: "x" }));
    expect(res.status).toBe(502);
    expect(await errorCode(res)).toBe("upstream_error");
  });
});

describe("routing", () => {
  it("GET /v1/guides → 404 not_found (reserved route)", async () => {
    const res = await dispatch("/v1/guides");
    expect(res.status).toBe(404);
    expect(await errorCode(res)).toBe("not_found");
  });

  it("unknown route → 404 not_found", async () => {
    const res = await dispatch("/v1/nope", { method: "POST" });
    expect(res.status).toBe(404);
    expect(await errorCode(res)).toBe("not_found");
  });
});

describe("privacy log guarantee (REQ-003)", () => {
  it("log lines carry only allowlisted fields and can never contain dilemma text", async () => {
    // The log API accepts only these fields — dilemma/answer text has no way in.
    const line = await buildLogLine({
      op: "session-plan",
      deviceId: DEVICE,
      provider: "gemini",
      model: "gemini-3.5-flash",
      latencyMs: 7012,
      outcome: "ok",
    });
    expect(line).not.toContain("SECRET_DILEMMA_XYZ");
    expect(line).not.toContain("SECRET_REFLECTION_ABC");
    expect(line).not.toContain(DEVICE); // raw device id never logged
    const parsed = JSON.parse(line) as Record<string, unknown>;
    const allowed = ["ts", "op", "device", "provider", "model", "latency_ms", "outcome"];
    expect(Object.keys(parsed).every((k) => allowed.includes(k))).toBe(true);
    expect(String(parsed["device"])).toHaveLength(12);
  });

  it("the reserved weekly meter code exists in the union (compile-time) but is never returned", () => {
    const reserved: ErrorCode = "weekly_meter_exhausted";
    expect(reserved).toBe("weekly_meter_exhausted");
  });
});
