// The ONLY console call site in the Worker. One JSON line per request, built from
// a hard allowlist of fields — dilemma/answer content cannot pass through here
// because the API simply does not accept it (REQ-003).

export interface LogFields {
  op: string;
  deviceId: string;
  provider: string;
  model: string;
  latencyMs: number;
  outcome: string;
}

/** First 12 hex chars of SHA-256(device id) — the raw id never reaches the log sink. */
async function hashDevice(deviceId: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(deviceId));
  return [...new Uint8Array(digest)]
    .slice(0, 6)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function buildLogLine(fields: LogFields): Promise<string> {
  return JSON.stringify({
    ts: new Date().toISOString(),
    op: fields.op,
    device: await hashDevice(fields.deviceId),
    provider: fields.provider,
    model: fields.model,
    latency_ms: fields.latencyMs,
    outcome: fields.outcome,
  });
}

export async function logRequest(fields: LogFields): Promise<void> {
  console.log(await buildLogLine(fields));
}
