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
}

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
  async checkAndCount(op: MeteredOp): Promise<MeterResult> {
    const now = Date.now();
    const maxCalls = intVar(this.env.RATE_LIMIT_CALLS, 6);
    const windowMs = intVar(this.env.RATE_LIMIT_WINDOW_MIN, 10) * 60_000;
    const dailySessions = intVar(this.env.DEVICE_DAILY_SESSIONS, 20);

    const weekKey = `sessions:${isoWeekKey(new Date(now))}`;
    const weekly = (await this.ctx.storage.get<number>(weekKey)) ?? 0;

    let stamps = (await this.ctx.storage.get<number[]>("stamps")) ?? [];
    stamps = stamps.filter((t) => now - t < windowMs);

    if (stamps.length >= maxCalls) {
      await this.ctx.storage.put("stamps", stamps);
      return { allowed: false, reason: "rate_limited", weeklySessions: weekly };
    }

    if (op === "session-plan") {
      const dayKey = `day:${new Date(now).toISOString().slice(0, 10)}`;
      const today = (await this.ctx.storage.get<number>(dayKey)) ?? 0;
      if (today >= dailySessions) {
        await this.ctx.storage.put("stamps", stamps);
        return { allowed: false, reason: "rate_limited", weeklySessions: weekly };
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
      return { allowed: true, weeklySessions: weekly + 1 };
    }

    stamps.push(now);
    await this.ctx.storage.put("stamps", stamps);
    return { allowed: true, weeklySessions: weekly };
  }
}
