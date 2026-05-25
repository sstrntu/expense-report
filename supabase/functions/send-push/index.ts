// Supabase Edge Function: send-push
//
// Sends an APNs push notification to every registered iOS device for the
// notification recipient. Intended to be called from a Supabase Database
// Webhook on the `turfmapp_expenses.notifications` table (INSERT event).
//
// Required secrets (set via `supabase secrets set`):
//   APNS_KEY_ID       — 10-char key ID from Apple Developer portal (e.g. "ABCD123456")
//   APNS_TEAM_ID      — 10-char Team ID (e.g. "HAS8MJEJM2")
//   APNS_PRIVATE_KEY  — Contents of the .p8 file (the raw PEM text, newlines included)
//   APNS_BUNDLE_ID    — App bundle ID (e.g. "com.turfmapp.expense-report")
//
// Optional:
//   APNS_PRODUCTION   — Set to "true" for App Store / TestFlight builds.
//                       Omit or set to "false" for sandbox (development).
//
// Input (Supabase Database Webhook body):
//   { type: "INSERT", record: { id: uuid, recipient_membership_id: uuid,
//                               title: string, body: string, expense_id: uuid? } }
//
// Output: { ok: boolean, sent: number, error?: string }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL        = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID         = Deno.env.get("APNS_KEY_ID");
const APNS_TEAM_ID        = Deno.env.get("APNS_TEAM_ID");
const APNS_PRIVATE_KEY    = Deno.env.get("APNS_PRIVATE_KEY");
const APNS_BUNDLE_ID      = Deno.env.get("APNS_BUNDLE_ID") ?? "com.turfmapp.expense-report";
const APNS_PRODUCTION     = Deno.env.get("APNS_PRODUCTION") === "true";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ── APNs JWT helpers ──────────────────────────────────────────────────────────

function base64UrlEncode(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function buildApnsJwt(keyId: string, teamId: string, pem: string): Promise<string> {
  // Strip PEM headers/footers and decode base64 key body
  const pemBody = pem
    .replace(/-----BEGIN (?:EC )?PRIVATE KEY-----|-----END (?:EC )?PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const header = base64UrlEncode(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const now = Math.floor(Date.now() / 1000);
  const payload = base64UrlEncode(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: now })));
  const sigInput = new TextEncoder().encode(`${header}.${payload}`);

  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, privateKey, sigInput);
  return `${header}.${payload}.${base64UrlEncode(sig)}`;
}

// ── APNs send ─────────────────────────────────────────────────────────────────

async function sendApns(opts: {
  deviceToken: string;
  title: string;
  body: string;
  expenseId?: string;
  eventType?: string;
  route?: string;
  jwt: string;
}): Promise<boolean> {
  const host = APNS_PRODUCTION
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";

  const payload = {
    aps: { alert: { title: opts.title, body: opts.body }, sound: "default", badge: 1 },
    expense_id: opts.expenseId ?? null,
    // event_type + route let the iOS notification handler dispatch to
    // the right deep-link target. event_type is the semantic key
    // (workspace_invite → Permissions, project_budget_warning →
    // Manage projects, anything expense-related → expense detail).
    event_type: opts.eventType ?? null,
    route: opts.route ?? null,
  };

  const resp = await fetch(`${host}/3/device/${opts.deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${opts.jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!resp.ok) {
    const body = await resp.text().catch(() => "");
    console.error(`APNs error ${resp.status} for ${opts.deviceToken}: ${body}`);
  }
  return resp.ok;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
    return json({ ok: false, error: "APNs credentials not configured." }, 503);
  }

  let record: {
    id: string;
    recipient_membership_id: string;
    title: string;
    body: string;
    expense_id?: string;
    event_type?: string;
    deep_link_route?: string;
  };

  try {
    const payload = await req.json();
    // Support both direct call `{ notification_id }` and Database Webhook body.
    record = payload.record ?? payload;
    if (!record?.id || !record?.recipient_membership_id) {
      return json({ ok: false, error: "Missing required notification fields." }, 400);
    }
  } catch {
    return json({ ok: false, error: "Invalid JSON body" }, 400);
  }

  // Use service role to bypass RLS when reading device tokens.
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    db: { schema: "turfmapp_expenses" },
  });

  const { data: tokens, error } = await supabase
    .from("device_tokens")
    .select("device_token")
    .eq("membership_id", record.recipient_membership_id)
    .eq("platform", "ios");

  if (error) {
    console.error("device_tokens query error:", error);
    return json({ ok: false, error: error.message }, 500);
  }

  if (!tokens || tokens.length === 0) {
    return json({ ok: true, sent: 0 });
  }

  const jwt = await buildApnsJwt(APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY);

  const results = await Promise.all(
    tokens.map((t: { device_token: string }) =>
      sendApns({
        deviceToken: t.device_token,
        title: record.title,
        body: record.body,
        expenseId: record.expense_id,
        eventType: record.event_type,
        route: record.deep_link_route,
        jwt,
      })
    )
  );

  const sent = results.filter(Boolean).length;
  return json({ ok: true, sent });
});
