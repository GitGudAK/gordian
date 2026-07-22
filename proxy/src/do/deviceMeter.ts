// Per-device meter (one DO instance per X-Device-ID, SQLite-backed):
//  1. sliding-window rate limit across both operations
//  2. per-UTC-day session cap (session-plan calls only)
//  3. ISO-week session counter — the Phase 3.5 freemium meter READS this;
//     nothing enforces it this phase (weekly_meter_exhausted stays dormant).

import { DurableObject } from "cloudflare:workers";

export type MeteredOp = "session-plan" | "verdict";

export interface MeterResult {
  allowed: boolean;
  reason?: "rate_limited";
  weeklySessions: number;
  /** Active safety lock (epoch ms; 0 = none) and lifetime strike count. */
  safetyLockedUntil: number;
  safetyStrikes: number;
}

export interface SafetyState {
  lockedUntil: number;
  strikes: number;
}

// Strike ladder: 1st = refusal only, 2nd = 5 min, 3rd = 30 min, 4th+ = 24 h.
// Strikes decay after 7 clean days.
const SAFETY_DELAYS_MS = [0, 5 * 60_000, 30 * 60_000, 24 * 60 * 60_000];
const SAFETY_DECAY_MS = 7 * 24 * 60 * 60_000;

/** ISO-8601 week key, UTC, e.g. "2026-W29". Handles year-boundary weeks (Thursday rule). */
export function isoWeekKey(date: Date): string {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const year = d.getUTCFullYear();
  const yearStart = Date.UTC(year, 0, 1);
  const week = Math.ceil(((d.getTime() - yearStart) / 86_400_000 + 1) / 7);
  return `${year}-W${String(week).padStart(2, "0")}`;
}

function intVar(value: string | undefined, fallback: number): number {
  const n = parseInt(value ?? "", 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

export class DeviceMeterDO extends DurableObject<Env> {
  private async safetyFields(now: number): Promise<{ safetyLockedUntil: number; safetyStrikes: number }> {
    const until = (await this.ctx.storage.get<number>("safety:until")) ?? 0;
    const strikes = (await this.ctx.storage.get<number>("safety:strikes")) ?? 0;
    return { safetyLockedUntil: until > now ? until : 0, safetyStrikes: strikes };
  }

  async checkAndCount(op: MeteredOp): Promise<MeterResult> {
    const now = Date.now();
    const maxCalls = intVar(this.env.RATE_LIMIT_CALLS, 6);
    const windowMs = intVar(this.env.RATE_LIMIT_WINDOW_MIN, 10) * 60_000;
    const dailySessions = intVar(this.env.DEVICE_DAILY_SESSIONS, 20);

    const safety = await this.safetyFields(now);
    const weekKey = `sessions:${isoWeekKey(new Date(now))}`;
    const weekly = (await this.ctx.storage.get<number>(weekKey)) ?? 0;

    let stamps = (await this.ctx.storage.get<number[]>("stamps")) ?? [];
    stamps = stamps.filter((t) => now - t < windowMs);

    if (stamps.length >= maxCalls) {
      await this.ctx.storage.put("stamps", stamps);
      return { allowed: false, reason: "rate_limited", weeklySessions: weekly, ...safety };
    }

    if (op === "session-plan") {
      const dayKey = `day:${new Date(now).toISOString().slice(0, 10)}`;
      const today = (await this.ctx.storage.get<number>(dayKey)) ?? 0;
      if (today >= dailySessions) {
        await this.ctx.storage.put("stamps", stamps);
        return { allowed: false, reason: "rate_limited", weeklySessions: weekly, ...safety };
      }
      stamps.push(now);
      // tier: forward hook for the App Attest lane — no logic on it this phase
      const tier = (await this.ctx.storage.get<string>("tier")) ?? "uuid";
      await this.ctx.storage.put({
        stamps,
        tier,
        [dayKey]: today + 1,
        [weekKey]: weekly + 1,
      });
      return { allowed: true, weeklySessions: weekly + 1, ...safety };
    }

    stamps.push(now);
    await this.ctx.storage.put("stamps", stamps);
    return { allowed: true, weeklySessions: weekly, ...safety };
  }

  /** Records a harmful-intent strike (never called for self-harm classifications). */
  async recordSafetyStrike(): Promise<SafetyState> {
    const now = Date.now();
    let strikes = (await this.ctx.storage.get<number>("safety:strikes")) ?? 0;
    const last = (await this.ctx.storage.get<number>("safety:last")) ?? 0;
    if (last > 0 && now - last > SAFETY_DECAY_MS) strikes = 0; // 7 clean days forgives
    strikes += 1;
    const delay = SAFETY_DELAYS_MS[Math.min(strikes - 1, SAFETY_DELAYS_MS.length - 1)];
    const until = delay > 0 ? now + delay : 0;
    await this.ctx.storage.put({
      "safety:strikes": strikes,
      "safety:last": now,
      "safety:until": until,
    });
    return { lockedUntil: until, strikes };
  }
}
