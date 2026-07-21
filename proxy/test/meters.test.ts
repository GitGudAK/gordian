// Meter behavior through the real router (SELF) with mocked upstream:
// sliding-window rate limit, daily session cap, global spend cap, ISO-week counter.
// Each test gets isolated DO storage (vitest-pool-workers default), so tests
// prefill counters via runInDurableObject instead of overriding limit vars.

import { describe, it, expect, beforeAll, afterEach } from "vitest";
import { env, createExecutionContext, waitOnExecutionContext, runInDurableObject } from "cloudflare:test";
import worker from "../src/index";
import { installFetchMock, clearFetchMocks, mockPersist, GEMINI_ORIGIN } from "./helpers/fetch-mock";
import { isoWeekKey } from "../src/do/deviceMeter";
import verdictFixture from "./fixtures/response-verdict.json";

// The worker handler is dispatched directly (same context as the tests, so the
// fetch stub intercepts its upstream calls — 0.18's replacement for SELF).
// DO storage persists across tests in this file, so each test uses fresh device ids.
const DEVICE_A = "11111111-2222-3333-4444-555555555555";
const DEVICE_B = "66666666-7777-8888-9999-aaaaaaaaaaaa";
const DEVICE_C = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
const DEVICE_D = "12121212-3434-5656-7878-909090909090";

beforeAll(() => {
  installFetchMock();
});

afterEach(() => {
  clearFetchMocks();
});

function mockUpstream(fixture: unknown) {
  clearFetchMocks();
  mockPersist(GEMINI_ORIGIN, () => Response.json(fixture));
}

// A generateContent body whose payload satisfies BOTH the gate call (mode/options)
// and the questions call (questions array) — persisted mocks serve every hop.
const fullSessionBody = {
  candidates: [
    {
      content: {
        parts: [
          {
            text: JSON.stringify({
              mode: "BINARY",
              optionA: "Berlin",
              optionB: "Austin",
              questions: Array.from({ length: 12 }, (_, i) => `Question ${i + 1}?`),
            }),
          },
        ],
      },
      finishReason: "STOP",
    },
  ],
};

async function post(path: string, deviceId: string | null, body: unknown): Promise<Response> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (deviceId) headers["X-Device-ID"] = deviceId;
  const request = new Request(`https://proxy.test${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

const sessionBody = { scenario: "Should I quit my job to freelance?" };
const verdictBody = {
  scenario: "Should I quit my job to freelance?",
  answers: [{ question: "Ready?", choice: "YES", reflection: "" }],
};

describe("isoWeekKey", () => {
  it("formats a mid-year date", () => {
    expect(isoWeekKey(new Date(Date.UTC(2026, 6, 20)))).toBe("2026-W30");
  });

  it("assigns early January to the previous ISO year's final week", () => {
    // Jan 1 2027 is a Friday — it belongs to 2026-W53.
    expect(isoWeekKey(new Date(Date.UTC(2027, 0, 1)))).toBe("2026-W53");
  });

  it("assigns late December to the next ISO year's week 01", () => {
    // Dec 29 2025 is a Monday — the week containing Thu Jan 1 2026.
    expect(isoWeekKey(new Date(Date.UTC(2025, 11, 29)))).toBe("2026-W01");
  });
});

describe("sliding-window rate limit", () => {
  it("returns 429 rate_limited once the window is full, while another device still succeeds", async () => {
    mockUpstream(fullSessionBody);

    // Fill device A's window to RATE_LIMIT_CALLS (6).
    const stub = env.DEVICE_METER.get(env.DEVICE_METER.idFromName(DEVICE_A));
    await runInDurableObject(stub, async (_instance, state) => {
      const now = Date.now();
      await state.storage.put("stamps", [now, now, now, now, now, now]);
    });

    const limited = await post("/v1/session-plan", DEVICE_A, sessionBody);
    expect(limited.status).toBe(429);
    const body = (await limited.json()) as { error: { code: string } };
    expect(body.error.code).toBe("rate_limited");

    const other = await post("/v1/session-plan", DEVICE_B, sessionBody);
    expect(other.status).toBe(200);
  });

  it("enforces the per-day session cap under the same code", async () => {
    const stub = env.DEVICE_METER.get(env.DEVICE_METER.idFromName(DEVICE_C));
    const dayKey = `day:${new Date().toISOString().slice(0, 10)}`;
    await runInDurableObject(stub, async (_instance, state) => {
      await state.storage.put(dayKey, 20); // DEVICE_DAILY_SESSIONS default
    });

    const limited = await post("/v1/session-plan", DEVICE_C, sessionBody);
    expect(limited.status).toBe(429);
    const body = (await limited.json()) as { error: { code: string } };
    expect(body.error.code).toBe("rate_limited");
  });
});

describe("weekly session counter", () => {
  it("increments only on session-plan calls and is readable via X-Weekly-Sessions", async () => {
    mockUpstream(fullSessionBody);
    const first = await post("/v1/session-plan", DEVICE_D, sessionBody);
    expect(first.status).toBe(200);
    expect(first.headers.get("X-Weekly-Sessions")).toBe("1");

    const second = await post("/v1/session-plan", DEVICE_D, sessionBody);
    expect(second.headers.get("X-Weekly-Sessions")).toBe("2");

    mockUpstream(verdictFixture);
    const verdict = await post("/v1/verdict", DEVICE_D, verdictBody);
    expect(verdict.status).toBe(200);
    expect(verdict.headers.get("X-Weekly-Sessions")).toBeNull();

    const stub = env.DEVICE_METER.get(env.DEVICE_METER.idFromName(DEVICE_D));
    const weekly = await runInDurableObject(stub, (_instance, state) =>
      state.storage.get<number>(`sessions:${isoWeekKey(new Date())}`),
    );
    expect(weekly).toBe(2); // verdict did not increment
  });
});

describe("global spend cap", () => {
  it("returns 429 spend_cap once the daily call cap is reached", async () => {
    const freshDevice = "0a0b0c0d-1a1b-2a2b-3a3b-4a4b4c4d4e4f";
    const stub = env.SPEND_CAP.get(env.SPEND_CAP.idFromName("global"));
    const key = `calls:${new Date().toISOString().slice(0, 10)}`;
    await runInDurableObject(stub, async (_instance, state) => {
      await state.storage.put(key, 1500); // DAILY_CALL_CAP default
    });

    try {
      const capped = await post("/v1/session-plan", freshDevice, sessionBody);
      expect(capped.status).toBe(429);
      const body = (await capped.json()) as { error: { code: string } };
      expect(body.error.code).toBe("spend_cap");
    } finally {
      // The spend DO is a singleton — undo the prefill so later tests aren't capped.
      await runInDurableObject(stub, async (_instance, state) => {
        await state.storage.delete(key);
      });
    }
  });
});
