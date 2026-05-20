// Supabase Edge Function: send-workspace-invite
//
// Sends the invite-code email to the invited address. Idempotent and
// non-authoritative — the invite row already exists when this is called;
// failure here is recoverable (admin can re-send).
//
// Required secrets:
//   RESEND_API_KEY        — Resend API key (free tier OK for v1)
//   INVITE_EMAIL_FROM     — verified sender, e.g. "Expenses <invites@yourdomain.com>"
//                           For testing, "onboarding@resend.dev" works without DNS.
// Optional:
//   INVITE_APP_NAME       — display name in the email (default "Expenses")
//   INVITE_APP_STORE_URL  — link in the email pointing to the App Store listing.
//
// Input body: { invite_id: uuid }
// Output:     { ok: boolean, error?: string }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const INVITE_EMAIL_FROM = Deno.env.get("INVITE_EMAIL_FROM") ?? "onboarding@resend.dev";
const APP_NAME = Deno.env.get("INVITE_APP_NAME") ?? "Expenses";
const APP_STORE_URL = Deno.env.get("INVITE_APP_STORE_URL") ?? "";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ ok: false, error: "Missing Authorization header" }, 401);

  if (!RESEND_API_KEY) {
    return json({ ok: false, error: "Email delivery is not configured (missing RESEND_API_KEY)." }, 503);
  }

  let inviteId: string;
  try {
    const body = await req.json();
    inviteId = body.invite_id ?? body.inviteId;
    if (!inviteId) return json({ ok: false, error: "invite_id is required" }, 400);
  } catch {
    return json({ ok: false, error: "Invalid JSON body" }, 400);
  }

  // Pull invite under the caller's JWT — RLS enforces that only the admin
  // who can manage invites for that workspace can trigger an email send.
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    db: { schema: "turfmapp_expenses" },
    global: { headers: { Authorization: authHeader } },
  });

  const { data: invite, error: inviteError } = await supabase
    .from("workspace_invites")
    .select("id, email, role, expires_at, workspace_id, status, workspaces(name)")
    .eq("id", inviteId)
    .single();

  if (inviteError || !invite) {
    return json({ ok: false, error: `Invite not found or not accessible: ${inviteError?.message ?? "unknown"}` }, 404);
  }

  if (invite.status !== "pending") {
    return json({ ok: false, error: `Invite is not pending (status: ${invite.status})` }, 422);
  }

  // Inviter display name — best-effort; fall back to "An admin" if hidden.
  let inviterName = "An admin";
  const { data: userResult } = await supabase.auth.getUser();
  if (userResult?.user) {
    const { data: profile } = await supabase
      .from("users")
      .select("display_name")
      .eq("id", userResult.user.id)
      .maybeSingle();
    if (profile?.display_name) inviterName = profile.display_name;
  }

  const workspaceName: string = (invite as any).workspaces?.name ?? "a workspace";
  const expiresAt = new Date(invite.expires_at as string).toLocaleDateString();
  const role = String(invite.role);
  const code = String(invite.id);

  const subject = `${inviterName} invited you to ${workspaceName} on ${APP_NAME}`;
  const appLink = APP_STORE_URL ? `<p style="margin:16px 0;"><a href="${escapeHtml(APP_STORE_URL)}" style="color:#3b82f6;">Download the app</a> if you don't already have it.</p>` : "";
  const html = `<!doctype html>
<html><body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;line-height:1.5;color:#111827;max-width:560px;margin:0 auto;padding:32px 20px;">
  <h2 style="margin:0 0 12px;font-size:20px;">You've been invited to ${escapeHtml(workspaceName)}</h2>
  <p>${escapeHtml(inviterName)} added you as a <strong>${escapeHtml(role)}</strong> on ${escapeHtml(workspaceName)} in ${escapeHtml(APP_NAME)}.</p>
  ${appLink}
  <p style="margin:16px 0;">Open ${escapeHtml(APP_NAME)}, sign up with this email address, and enter the code below to join the workspace:</p>
  <div style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;background:#f3f4f6;border:1px solid #e5e7eb;border-radius:10px;padding:14px 16px;font-size:13px;letter-spacing:0.4px;word-break:break-all;">${escapeHtml(code)}</div>
  <p style="color:#6b7280;font-size:12px;margin-top:24px;">This invite expires on ${escapeHtml(expiresAt)}. If you weren't expecting this, you can ignore this email.</p>
</body></html>`;
  const text = `${inviterName} added you as a ${role} on ${workspaceName} in ${APP_NAME}.\n\nOpen the app, sign up with this email, and enter the code below to join:\n\n${code}\n\nThis invite expires on ${expiresAt}.`;

  const resendResp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: INVITE_EMAIL_FROM,
      to: [invite.email],
      subject,
      html,
      text,
    }),
  });

  if (!resendResp.ok) {
    const errBody = await resendResp.text();
    return json({ ok: false, error: `Resend error (${resendResp.status}): ${errBody}` }, 502);
  }

  return json({ ok: true });
});
