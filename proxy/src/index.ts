// Gordian proxy router. Flow per request:
//   route → validate (bad_request) → DeviceMeterDO (rate_limited)
//   → SpendCapDO (spend_cap) → provider adapter (upstream_error) → JSON out.
// Every failure is the unified envelope {error:{code,message}}; every request
// emits exactly one allowlisted log line via log.ts.

import {
  ERROR_STATUS,
  UpstreamError,
  parseModelVar,
  type ErrorCode,
  type OperationConfig,
  type StructuredRequest,
} from "./providers/types.ts";
import * as gemini from "./providers/gemini.ts";
import * as anthropic from "./providers/anthropic.ts";
import * as ops from "./operations.ts";
import {
  MAX_BODY_BYTES,
  validateDeviceId,
  validateSessionPlanBody,
  validateVerdictBody,
} from "./validate.ts";
import { logRequest } from "./log.ts";
import { privacyPage, supportPage } from "./pages.ts";
import type { MeterResult, MeteredOp } from "./do/deviceMeter.ts";

export { DeviceMeterDO } from "./do/deviceMeter.ts";
export { SpendCapDO } from "./do/spendCap.ts";

interface RequestMeta {
  op: string;
  deviceId: string;
  provider: string;
  model: string;
  outcome: string;
}

class SpendCapError extends Error {}

function errorResponse(code: ErrorCode, message: string, meta: RequestMeta): Response {
  meta.outcome = code;
  return Response.json({ error: { code, message } }, { status: ERROR_STATUS[code] });
}

function adapterFor(config: OperationConfig) {
  return config.provider === "gemini" ? gemini.generateStructured : anthropic.generateStructured;
}

async function handleOperation(
  op: MeteredOp,
  request: Request,
  env: Env,
  meta: RequestMeta,
): Promise<Response> {
  meta.op = op;

  const deviceId = validateDeviceId(request.headers.get("X-Device-ID"));
  if (!deviceId) {
    return errorResponse("bad_request", "X-Device-ID header must be a UUID", meta);
  }
  meta.deviceId = deviceId;

  const raw = await request.arrayBuffer();
  if (raw.byteLength > MAX_BODY_BYTES) {
    return errorResponse("bad_request", `body exceeds ${MAX_BODY_BYTES} bytes`, meta);
  }
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder().decode(raw));
  } catch {
    return errorResponse("bad_request", "body must be valid JSON", meta);
  }

  const maxScenarioChars = parseInt(env.MAX_SCENARIO_CHARS ?? "500", 10) || 500;
  let structured: StructuredRequest;
  if (op === "session-plan") {
    const input = validateSessionPlanBody(body, maxScenarioChars);
    if (!input.ok) return errorResponse("bad_request", input.message, meta);
    structured = {
      system: ops.sessionPlanSystem(input.value.scenario),
      user: ops.SESSION_PLAN_USER,
      geminiSchema: ops.SESSION_PLAN_GEMINI_SCHEMA,
      anthropicSchema: ops.SESSION_PLAN_ANTHROPIC_SCHEMA,
      temperature: ops.TEMPERATURE,
    };
  } else {
    const input = validateVerdictBody(body, maxScenarioChars);
    if (!input.ok) return errorResponse("bad_request", input.message, meta);
    structured = {
      system: ops.verdictSystem(input.value.scenario, input.value.answers),
      user: ops.VERDICT_USER,
      geminiSchema: ops.VERDICT_GEMINI_SCHEMA,
      anthropicSchema: ops.VERDICT_ANTHROPIC_SCHEMA,
      temperature: ops.TEMPERATURE,
    };
  }

  const meterStub = env.DEVICE_METER.get(env.DEVICE_METER.idFromName(deviceId));
  const meter: MeterResult = await meterStub.checkAndCount(op);
  if (!meter.allowed) {
    return errorResponse("rate_limited", "device rate limit exceeded — try again later", meta);
  }

  const spendStub = env.SPEND_CAP.get(env.SPEND_CAP.idFromName("global"));
  const spend = await spendStub.checkAndIncrement();
  if (!spend.allowed) {
    return errorResponse("spend_cap", "global daily capacity reached — try again tomorrow", meta);
  }

  // widened: generated Env types vars as literals, but they're operator-tunable
  const modelVar = (op === "session-plan" ? env.MODEL_SESSION_PLAN : env.MODEL_VERDICT) as string | undefined;
  const fallbackVar = (op === "session-plan" ? env.MODEL_SESSION_PLAN_FALLBACK : env.MODEL_VERDICT_FALLBACK) as string | undefined;

  // Primary + fallback-model chain (AI-always), spend-counted per upstream attempt.
  const callChain = async (req: StructuredRequest): Promise<unknown> => {
    const config = parseModelVar(modelVar ?? "gemini:gemini-3.5-flash");
    meta.provider = config.provider;
    meta.model = config.model;
    try {
      return JSON.parse(await adapterFor(config)(req, config.model, env));
    } catch (err) {
      const fallback = fallbackVar && fallbackVar !== modelVar ? parseModelVar(fallbackVar) : null;
      if (!fallback) throw err;
      const retrySpend = await spendStub.checkAndIncrement();
      if (!retrySpend.allowed) throw new SpendCapError();
      meta.provider = fallback.provider;
      meta.model = fallback.model;
      return JSON.parse(await adapterFor(fallback)(req, fallback.model, env));
    }
  };

  let payload: unknown;
  try {
    if (op === "session-plan") {
      // Two-tier: cheap gate classifies; the premium model only ever writes questions.
      const gateVar = (env.MODEL_GATE as string | undefined);
      let gate: Record<string, unknown> | null = null;
      if (gateVar) {
        try {
          const gateConfig = parseModelVar(gateVar);
          const gateText = await adapterFor(gateConfig)(
            {
              system: ops.gateSystem((body as { scenario: string }).scenario ?? ""),
              user: ops.GATE_USER,
              geminiSchema: ops.SESSION_PLAN_GEMINI_SCHEMA,
              anthropicSchema: ops.SESSION_PLAN_ANTHROPIC_SCHEMA,
              temperature: 0.2,
            },
            gateConfig.model,
            env,
          );
          const parsed = JSON.parse(gateText) as Record<string, unknown>;
          if (typeof parsed["mode"] === "string") gate = parsed;
        } catch {
          gate = null; // gate model unavailable → legacy single-call below
        }
      }

      if (gate) {
        const mode = String(gate["mode"]).toUpperCase();
        if (mode === "SENSITIVE" || mode === "TOO_BIG" || mode === "NOT_A_DECISION") {
          payload = gate; // terminal classification: no premium call, fast return
        } else {
          const spend2 = await spendStub.checkAndIncrement();
          if (!spend2.allowed) throw new SpendCapError();
          const q = (await callChain({
            system: ops.questionsSystem(
              (body as { scenario: string }).scenario ?? "",
              mode,
              String(gate["optionA"] ?? ""),
              String(gate["optionB"] ?? ""),
            ),
            user: ops.QUESTIONS_USER,
            geminiSchema: ops.QUESTIONS_GEMINI_SCHEMA,
            anthropicSchema: ops.QUESTIONS_ANTHROPIC_SCHEMA,
            temperature: ops.TEMPERATURE,
          })) as Record<string, unknown>;
          payload = { ...gate, questions: q["questions"] ?? [] };
        }
      } else {
        payload = await callChain(structured);
      }
    } else {
      payload = await callChain(structured);
    }
  } catch (err) {
    if (err instanceof SpendCapError) {
      return errorResponse("spend_cap", "global daily capacity reached — try again tomorrow", meta);
    }
    const message = err instanceof UpstreamError ? err.message : "upstream call failed";
    return errorResponse("upstream_error", message, meta);
  }

  meta.outcome = "ok";
  const headers = new Headers({ "content-type": "application/json" });
  if (op === "session-plan") {
    headers.set("X-Weekly-Sessions", String(meter.weeklySessions));
  }
  return new Response(JSON.stringify(payload), { status: 200, headers });
}

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const started = Date.now();
    const meta: RequestMeta = {
      op: "-",
      deviceId: "unknown",
      provider: "-",
      model: "-",
      outcome: "-",
    };

    let response: Response;
    try {
      const url = new URL(request.url);
      if (request.method === "POST" && url.pathname === "/v1/session-plan") {
        response = await handleOperation("session-plan", request, env, meta);
      } else if (request.method === "POST" && url.pathname === "/v1/verdict") {
        response = await handleOperation("verdict", request, env, meta);
      } else if (request.method === "GET" && url.pathname === "/v1/guides") {
        // Reserved route: remote guide content ships in a later phase.
        meta.op = "guides";
        response = errorResponse("not_found", "guides not yet available", meta);
      } else if (request.method === "GET" && url.pathname === "/privacy") {
        meta.op = "privacy";
        meta.outcome = "ok";
        response = privacyPage();
      } else if (request.method === "GET" && url.pathname === "/support") {
        meta.op = "support";
        meta.outcome = "ok";
        response = supportPage();
      } else {
        response = errorResponse("not_found", "no such route", meta);
      }
    } catch (err) {
      // Unexpected exceptions become envelopes, never stack traces.
      response = errorResponse("upstream_error", "internal error", meta);
    }

    await logRequest({
      op: meta.op,
      deviceId: meta.deviceId,
      provider: meta.provider,
      model: meta.model,
      latencyMs: Date.now() - started,
      outcome: meta.outcome,
    });
    return response;
  },
} satisfies ExportedHandler<Env>;
