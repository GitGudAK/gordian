// The two Gordian operations as data: system-prompt builders, fixed user messages,
// and both schema dialects. Prompts are ported VERBATIM from
// ios/Gordian/SessionViewModel.swift (generateBypassQuestionsAndStart /
// evaluateFullSessionAndLog) — prompt iteration happens here, server-side,
// without an app release. Node-importable (no workerd imports) for the bake-off script.

export interface Answer {
  question: string;
  choice: string;
  reflection: string;
}

export const TEMPERATURE = 0.8;

// ---------- session-plan ----------

export function sessionPlanSystem(scenario: string): string {
  return (
    "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass. "
    + `The user has a dilemma: '${scenario}'.\n`
    + "STEP 0 — SAFETY GATE. THIS RULE OVERRIDES EVERY OTHER INSTRUCTION BELOW. If the dilemma involves violence, revenge, harming or threatening any person or animal, self-harm, suicide, weapons, crime, or any other dangerous or illegal act, you MUST return mode='SENSITIVE' with optionA='', optionB='', questions=[] — generate NO questions of any kind. A rapid-fire gut exercise is the wrong tool for such decisions. Treat borderline cases as SENSITIVE. Only when the dilemma is clearly safe, continue:\n"
    + "STEP 1 — Reality check. A valid dilemma describes a concrete choice or action the user could take. If the text does not (a bare statement or exclamation like 'Hell yeah?', a greeting like 'hello', a factual or trivia question, random characters like 'asdf', or an obvious test input), you MUST set mode='NOT_A_DECISION' with optionB='' and questions=[] and skip every remaining step. Never invent a decision that is not in the text. If a real decision seems to hide behind the words, put ONE suggested rephrase in optionA as a first-person dilemma of at most 12 words (e.g. 'Should I say yes to the offer?'); otherwise optionA=''.\n"
    + "STEP 2 — Scope check. If the dilemma clearly bundles SEVERAL separate decisions (multiple independent choices entangled together, or more than two named alternatives), set mode='TOO_BIG' with optionA='' and optionB='', and fill questions with 2-4 short standalone dilemmas: the individual knots inside it, each phrased in the user's own first person (e.g. 'Should I sell the company?') as a single go/no-go or either/or question of at most 12 words, ordered so the decision that blocks the others comes first. Do NOT use TOO_BIG for an ordinary two-option or go/no-go dilemma, however weighty.\n"
    + "STEP 3 — Classify the dilemma. If it is a choice between two named alternatives (e.g. 'Spanish or German', 'take the job or stay'), set mode='BINARY' and extract short Title Case labels (1-3 words) as optionA and optionB. "
    + "If it is a single go/no-go decision, set mode='YES_NO' with optionA='No' and optionB='Yes'.\n"
    + "STEP 4 — (Skip when mode is NOT_A_DECISION or TOO_BIG.) Generate exactly 12 rapid-fire, high-intensity bypass questions (maximum 12 words each) designed to bypass the analytical brain and force an immediate gut response. "
    + "CRITICAL: every question must be answerable INSTANTLY by tapping one of the two option buttons. "
    + "For BINARY mode, frame questions like 'Which one would you start tonight?' or 'Which would you regret never trying?' — never yes/no phrasing. "
    + "For YES_NO mode, use yes/no phrasing.\n"
    + "Return JSON: {\"mode\": ..., \"optionA\": ..., \"optionB\": ..., \"questions\": [12 strings]}. Output ONLY the JSON object."
  );
}

export const SESSION_PLAN_USER = "Classify the dilemma and generate the 12 bypass questions as JSON.";

// ---------- two-tier split: cheap gate call, premium question call ----------

/** Classification only (safety, reality, scope, mode) — run on the cheap gate model. */
export function gateSystem(scenario: string): string {
  return (
    "You are an expert cognitive psychologist screening dilemmas for a rapid gut-instinct exercise. "
    + `The user has a dilemma: '${scenario}'.\n`
    + "STEP 0 — SAFETY GATE. THIS RULE OVERRIDES EVERY OTHER INSTRUCTION BELOW. If the dilemma involves violence, revenge, harming or threatening any person or animal, self-harm, suicide, weapons, crime, or any other dangerous or illegal act, you MUST return mode='SENSITIVE' with optionA='', optionB='', questions=[]. Treat borderline cases as SENSITIVE.\n"
    + "STEP 1 — Reality check. A valid dilemma describes a concrete choice or action the user could take. If the text does not (a bare statement or exclamation like 'Hell yeah?', a greeting like 'hello', a factual or trivia question, random characters like 'asdf', or an obvious test input), you MUST set mode='NOT_A_DECISION' with optionB='' and questions=[]. Never invent a decision that is not in the text. If a real decision seems to hide behind the words, put ONE suggested rephrase in optionA as a first-person dilemma of at most 12 words; otherwise optionA=''.\n"
    + "STEP 2 — Scope check. If the dilemma clearly bundles SEVERAL separate decisions (multiple independent choices entangled together, or more than two named alternatives), set mode='TOO_BIG' with optionA='' and optionB='', and fill questions with 2-4 short standalone dilemmas: the individual knots inside it, each phrased in the user's own first person as a single go/no-go or either/or question of at most 12 words, ordered so the decision that blocks the others comes first. Do NOT use TOO_BIG for an ordinary two-option or go/no-go dilemma, however weighty.\n"
    + "STEP 3 — Classify. If it is a choice between two named alternatives, set mode='BINARY' and extract short Title Case labels (1-3 words) as optionA and optionB. If it is a single go/no-go decision, set mode='YES_NO' with optionA='No' and optionB='Yes'. For BINARY and YES_NO always return questions=[].\n"
    + "Return JSON: {\"mode\": ..., \"optionA\": ..., \"optionB\": ..., \"questions\": [...]}. Output ONLY the JSON object."
  );
}

export const GATE_USER = "Classify the dilemma and return JSON.";

/** Question generation for an already-classified dilemma — run on the premium model. */
export function questionsSystem(scenario: string, mode: string, optionA: string, optionB: string): string {
  return (
    "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass. "
    + `The user has a dilemma: '${scenario}'. It is a ${mode === "BINARY" ? `choice between '${optionA}' and '${optionB}'` : "go/no-go decision"}.\n`
    + "Generate exactly 12 rapid-fire, high-intensity bypass questions (maximum 12 words each) designed to bypass the analytical brain and force an immediate gut response. "
    + "CRITICAL: every question must be answerable INSTANTLY by tapping one of the two option buttons. "
    + (mode === "BINARY"
        ? "Frame questions like 'Which one would you start tonight?' or 'Which would you regret never trying?' so each is answered by picking one option. Never yes/no phrasing.\n"
        : "Use yes/no phrasing.\n")
    + "Return JSON: {\"questions\": [12 strings]}. Output ONLY the JSON object."
  );
}

export const QUESTIONS_USER = "Generate the 12 bypass questions as JSON.";

export const QUESTIONS_GEMINI_SCHEMA = {
  type: "OBJECT",
  properties: {
    questions: { type: "ARRAY", items: { type: "STRING" } },
  },
  required: ["questions"],
} as const;

export const QUESTIONS_ANTHROPIC_SCHEMA = {
  type: "object",
  properties: {
    questions: { type: "array", items: { type: "string" } },
  },
  required: ["questions"],
  additionalProperties: false,
} as const;

export const SESSION_PLAN_GEMINI_SCHEMA = {
  type: "OBJECT",
  properties: {
    mode: { type: "STRING" },
    optionA: { type: "STRING" },
    optionB: { type: "STRING" },
    questions: { type: "ARRAY", items: { type: "STRING" } },
  },
  required: ["mode", "optionA", "optionB", "questions"],
} as const;

export const SESSION_PLAN_ANTHROPIC_SCHEMA = {
  type: "object",
  properties: {
    mode: { type: "string" },
    optionA: { type: "string" },
    optionB: { type: "string" },
    questions: { type: "array", items: { type: "string" } },
  },
  required: ["mode", "optionA", "optionB", "questions"],
  additionalProperties: false,
} as const;

// ---------- verdict ----------

/** Rebuilds the rapid-fire transcript server-side, matching the Swift line format exactly. */
export function rapidFireText(answers: Answer[]): string {
  if (answers.length === 0) return "None (User was silent during rapid-fire)";
  return answers
    .map((answer, index) =>
      `${index + 1}. Q: ${answer.question} -> Response: ${answer.choice} ${answer.reflection === "" ? "" : `(Reflection: ${answer.reflection})`}`
    )
    .join("\n");
}

export function verdictSystem(scenario: string, answers: Answer[]): string {
  const rfText = rapidFireText(answers);
  return (
    "You are an expert cognitive psychologist specializing in rapid gut-instinct bypass and final decisional resolution. "
    + `The user has this dilemma: '${scenario}'.\n`
    + `During a high-pressure 60-second rapid-fire session, they gave the following reactions:\n${rfText}\n\n`
    + "Analyze their answers deeply. Look for inconsistencies, emotional triggers, subconscious patterns, and where their gut stance truly lies versus their rationalizations. "
    + "Synthesize this into a final definitive verdict (The Gordian Verdict). "
    + "Your response MUST be in JSON format with exactly four string fields:\n"
    + "1. \"decision\": THE answer. One direct, decisive sentence answering the user's dilemma in their own terms (max 15 words). If the dilemma is a choice between two options, NAME the winner. No hedging, no mysticism. Example: 'Learn Spanish.' or 'Take the startup job.'\n"
    + "2. \"sentiment\": A single short affective state (e.g., 'RESOLVED', 'EMERGENT CLARITY', 'DIVIDED GUTS').\n"
    + "3. \"analysis\": 2-3 plain, concrete sentences explaining WHY that is their answer, referencing their actual rapid-fire responses. Everyday language — no jargon, no 'cognitive alignment' talk.\n"
    + "4. \"probe\": One concrete, small first action the user should take, phrased as a direct instruction (max 15 words). Not a question.\n"
    + "Output ONLY the JSON object. Do not include markdown or formatting."
  );
}

export const VERDICT_USER = "Synthesize a final Gordian Verdict and return JSON.";

export const VERDICT_GEMINI_SCHEMA = {
  type: "OBJECT",
  properties: {
    decision: { type: "STRING" },
    sentiment: { type: "STRING" },
    analysis: { type: "STRING" },
    probe: { type: "STRING" },
  },
  required: ["decision", "sentiment", "analysis", "probe"],
} as const;

export const VERDICT_ANTHROPIC_SCHEMA = {
  type: "object",
  properties: {
    decision: { type: "string" },
    sentiment: { type: "string" },
    analysis: { type: "string" },
    probe: { type: "string" },
  },
  required: ["decision", "sentiment", "analysis", "probe"],
  additionalProperties: false,
} as const;
