// Supabase Edge Function: convert-currency
// Snapshots an FX rate for an expense at submit time. Takes a native amount,
// looks up the cached rate in turfmapp_expenses.fx_rates first, falls back
// to the Frankfurter (ECB) API on cache miss, and writes through to cache.
//
// Why snapshot rather than convert on display? Audit. Once an expense is
// in the books, the conversion shouldn't move when ECB rates drift. The
// dashboard sums the stored converted amount, never re-converting.
//
// Request body:
//   { amount: number, from: "USD", to: "THB", date: "2026-05-20" }
//     - amount is in **minor units** (cents/satang). 2050 = $20.50.
//     - date is the historical date for the rate (typically expense.created_at).
//       Frankfurter returns the latest rate on or before that date.
//
// Response:
//   { rate: 36.124, converted: 74054, source: "frankfurter" | "cache" | "identity" | "fallback-static", asOf: "2026-05-20" }
//     - converted is in **minor units** of the `to` currency.
//
// Auth: requires a valid user JWT (verified via the SUPABASE_ANON_KEY client).
// Anyone authenticated can convert — this is read-only market data.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Static fallback rates (USD-based, captured 2026-05-20). Used when Frankfurter
// is unreachable AND the cache has no entry — keeps offline-ish flows working.
// Mirrors the iOS CurrencyConverter table; keep them in sync on each release.
const FALLBACK_USD_RATES: Record<string, number> = {
  USD: 1.0,
  EUR: 0.92,
  GBP: 0.79,
  JPY: 156.4,
  THB: 36.1,
  SGD: 1.35,
  HKD: 7.81,
  AUD: 1.52,
  CAD: 1.37,
  CHF: 0.91,
  CNY: 7.22,
  INR: 83.5,
  KRW: 1374.0,
  MYR: 4.72,
  IDR: 16100.0,
  PHP: 57.8,
  VND: 25400.0,
  TWD: 32.3,
  NZD: 1.66,
  MXN: 17.0,
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface ConvertBody {
  amount: number;
  from: string;
  to: string;
  date: string;
}

function parseBody(raw: unknown): ConvertBody | null {
  if (!raw || typeof raw !== "object") return null;
  const b = raw as Record<string, unknown>;
  if (typeof b.amount !== "number" || !Number.isFinite(b.amount) || b.amount < 0) return null;
  if (typeof b.from !== "string" || b.from.length !== 3) return null;
  if (typeof b.to !== "string" || b.to.length !== 3) return null;
  if (typeof b.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(b.date)) return null;
  return {
    amount: b.amount,
    from: b.from.toUpperCase(),
    to: b.to.toUpperCase(),
    date: b.date,
  };
}

/// Round half-up to the nearest integer — matches finance/accounting conventions
/// for minor-unit conversions (no banker's rounding ambiguity).
function roundMinor(value: number): number {
  return Math.floor(value + 0.5);
}

/// Call Frankfurter for the rate on (or before) the given date. Frankfurter
/// returns the most recent business day's rate when the requested date is a
/// weekend/holiday, which is the correct behaviour for our use case.
async function fetchFrankfurterRate(from: string, to: string, date: string): Promise<{ rate: number; asOf: string } | null> {
  try {
    const url = `https://api.frankfurter.app/${date}?from=${from}&to=${to}`;
    const resp = await fetch(url, { headers: { Accept: "application/json" } });
    if (!resp.ok) return null;
    const data = await resp.json() as { date?: string; rates?: Record<string, number> };
    const rate = data.rates?.[to];
    if (typeof rate !== "number" || !Number.isFinite(rate) || rate <= 0) return null;
    return { rate, asOf: data.date ?? date };
  } catch (_err) {
    return null;
  }
}

/// USD-pivoted fallback for when Frankfurter is unreachable. Less accurate
/// (USD pivot drifts vs direct pair) but better than failing the request.
function fallbackRate(from: string, to: string): number | null {
  const fromUsd = FALLBACK_USD_RATES[from];
  const toUsd = FALLBACK_USD_RATES[to];
  if (!fromUsd || !toUsd) return null;
  return toUsd / fromUsd;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Verify the caller has a valid JWT. We don't need to know who they are —
  // anyone authenticated can convert — but we don't want to expose this to
  // the public internet either.
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) return json({ error: "unauthorized" }, 401);

  let raw: unknown;
  try { raw = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  const body = parseBody(raw);
  if (!body) return json({ error: "invalid_body" }, 400);

  // Identity case: same currency, no conversion needed.
  if (body.from === body.to) {
    return json({ rate: 1.0, converted: body.amount, source: "identity", asOf: body.date });
  }

  // Use the service-role client for cache reads/writes — the table is
  // RLS-restricted to service_role on writes, and reads are cheap.
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    db: { schema: "turfmapp_expenses" },
  });

  // 1. Cache hit?
  const { data: cached } = await admin
    .from("fx_rates")
    .select("rate, source, as_of_date")
    .eq("from_currency", body.from)
    .eq("to_currency", body.to)
    .eq("as_of_date", body.date)
    .maybeSingle();

  if (cached) {
    const converted = roundMinor(body.amount * Number(cached.rate));
    return json({ rate: Number(cached.rate), converted, source: "cache", asOf: cached.as_of_date });
  }

  // 2. Live fetch from Frankfurter.
  const live = await fetchFrankfurterRate(body.from, body.to, body.date);
  if (live) {
    await admin.from("fx_rates").upsert({
      from_currency: body.from,
      to_currency: body.to,
      as_of_date: live.asOf,
      rate: live.rate,
      source: "frankfurter",
    }, { onConflict: "from_currency,to_currency,as_of_date" });
    const converted = roundMinor(body.amount * live.rate);
    return json({ rate: live.rate, converted, source: "frankfurter", asOf: live.asOf });
  }

  // 3. Static fallback — Frankfurter unreachable and nothing cached.
  const fallback = fallbackRate(body.from, body.to);
  if (fallback) {
    const converted = roundMinor(body.amount * fallback);
    return json({ rate: fallback, converted, source: "fallback-static", asOf: body.date });
  }

  return json({ error: "unsupported_currency_pair", from: body.from, to: body.to }, 422);
});
