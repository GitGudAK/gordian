// Pure input validation — every reject becomes a 400 bad_request upstream of any
// meter or model call. Limits: body ≤ 16 KB, scenario ≤ MAX_SCENARIO_CHARS,
// answers ≤ 20 × (question ≤ 200, choice ≤ 50, reflection ≤ 500).

import type { Answer } from "./operations.ts";

export const MAX_BODY_BYTES = 16_384;
export const MAX_ANSWERS = 20;
export const MAX_QUESTION_CHARS = 200;
export const MAX_CHOICE_CHARS = 50;
export const MAX_REFLECTION_CHARS = 500;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Validated<T> = { ok: true; value: T } | { ok: false; message: string };

export interface SessionPlanInput {
  scenario: string;
}

export interface VerdictInput {
  scenario: string;
  answers: Answer[];
}

export function validateDeviceId(header: string | null): string | null {
  if (!header || !UUID_RE.test(header)) return null;
  return header.toLowerCase();
}

function validateScenario(body: Record<string, unknown>, maxChars: number): Validated<string> {
  const scenario = body["scenario"];
  if (typeof scenario !== "string" || scenario.trim().length === 0) {
    return { ok: false, message: "scenario must be a non-empty string" };
  }
  if (scenario.length > maxChars) {
    return { ok: false, message: `scenario exceeds ${maxChars} characters` };
  }
  return { ok: true, value: scenario };
}

function asObject(body: unknown): Record<string, unknown> | null {
  return typeof body === "object" && body !== null && !Array.isArray(body)
    ? (body as Record<string, unknown>)
    : null;
}

export function validateSessionPlanBody(body: unknown, maxScenarioChars: number): Validated<SessionPlanInput> {
  const obj = asObject(body);
  if (!obj) return { ok: false, message: "body must be a JSON object" };
  const scenario = validateScenario(obj, maxScenarioChars);
  if (!scenario.ok) return scenario;
  return { ok: true, value: { scenario: scenario.value } };
}

export function validateVerdictBody(body: unknown, maxScenarioChars: number): Validated<VerdictInput> {
  const obj = asObject(body);
  if (!obj) return { ok: false, message: "body must be a JSON object" };
  const scenario = validateScenario(obj, maxScenarioChars);
  if (!scenario.ok) return scenario;

  const raw = obj["answers"];
  if (!Array.isArray(raw)) return { ok: false, message: "answers must be an array" };
  if (raw.length > MAX_ANSWERS) return { ok: false, message: `answers exceeds ${MAX_ANSWERS} items` };

  const answers: Answer[] = [];
  for (const item of raw) {
    const a = asObject(item);
    if (!a) return { ok: false, message: "each answer must be an object" };
    const question = a["question"];
    const choice = a["choice"];
    const reflection = a["reflection"] ?? "";
    if (typeof question !== "string" || question.length === 0 || question.length > MAX_QUESTION_CHARS) {
      return { ok: false, message: `answer.question must be a string of 1-${MAX_QUESTION_CHARS} chars` };
    }
    if (typeof choice !== "string" || choice.length === 0 || choice.length > MAX_CHOICE_CHARS) {
      return { ok: false, message: `answer.choice must be a string of 1-${MAX_CHOICE_CHARS} chars` };
    }
    if (typeof reflection !== "string" || reflection.length > MAX_REFLECTION_CHARS) {
      return { ok: false, message: `answer.reflection must be a string of 0-${MAX_REFLECTION_CHARS} chars` };
    }
    answers.push({ question, choice, reflection });
  }
  return { ok: true, value: { scenario: scenario.value, answers } };
}
