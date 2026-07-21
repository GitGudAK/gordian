// Global daily spend cap — a single DO instance (idFromName("global")).
// Date-keyed counter: a new UTC day is simply a new key, so there is no
// reset machinery to break. Hard stop bounds worst-case upstream spend in dollars.

import { DurableObject } from "cloudflare:workers";

export interface SpendResult {
  allowed: boolean;
}

export class SpendCapDO extends DurableObject<Env> {
  async checkAndIncrement(): Promise<SpendResult> {
    const cap = parseInt(this.env.DAILY_CALL_CAP ?? "1500", 10) || 1500;
    const key = `calls:${new Date().toISOString().slice(0, 10)}`;
    const count = (await this.ctx.storage.get<number>(key)) ?? 0;
    if (count >= cap) return { allowed: false };
    await this.ctx.storage.put(key, count + 1);
    return { allowed: true };
  }
}
