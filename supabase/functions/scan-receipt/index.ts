// Supabase Edge Function: scan-receipt
// Extracts merchant/amount/currency/date/category from a receipt via OpenAI
// vision and persists into turfmapp_expenses.receipt_scans/_fields.
//
// Supports multilingual receipts. Specifically handles:
//  - Thai receipts (ใบเสร็จ, ใบกำกับภาษี): keeps merchant names in original
//    script, converts Buddhist Era (พ.ศ.) dates to Gregorian by subtracting
//    543 years, recognizes บาท as THB.
//  - English receipts (default behaviour).
//  - Numbers with thai-localized digits (๐-๙) and comma separators.
//
// Required secret: OPENAI_API_KEY. Optional: OPENAI_MODEL (default gpt-4o-mini),
// SUPABASE_STORAGE_RECEIPT_BUCKET (default receipts).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
const RECEIPT_BUCKET = Deno.env.get("SUPABASE_STORAGE_RECEIPT_BUCKET") ?? "receipts";

interface ScanField {
  id: string;
  field_name: string;
  extracted_value: string;
  normalized_value: string | null;
  confidence: "high" | "medium" | "low" | "manual";
  confirmed_by_user: boolean;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/// Convert Thai digits (๐-๙) to ASCII digits. Idempotent on Latin digits.
function thaiToArabicDigits(s: string): string {
  return s.replace(/[๐-๙]/g, (d) => String("๐๑๒๓๔๕๖๗๘๙".indexOf(d)));
}

/// If the year part of an ISO date string is in the Thai Buddhist Era (>= 2400,
/// i.e. > Gregorian 1857), subtract 543 to convert to Gregorian. Receipts
/// dated 2567 → 2024, 2568 → 2025, etc. Best-effort: leaves invalid input alone.
function normalizeBuddhistDate(date: string): string {
  const ascii = thaiToArabicDigits(date.trim());
  const m = ascii.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$/);
  if (!m) return ascii;
  let year = parseInt(m[1], 10);
  const month = parseInt(m[2], 10);
  const day = parseInt(m[3], 10);
  // Buddhist Era is current Gregorian + 543. Heuristic: anything above 2400
  // is almost certainly B.E. (2400 BE = 1857 AD, before photography existed).
  if (year >= 2400) year -= 543;
  const mm = String(month).padStart(2, "0");
  const dd = String(day).padStart(2, "0");
  return `${year}-${mm}-${dd}`;
}

/// Strip non-numeric junk and Thai digits from a money string.
function normalizeAmount(raw: string): string {
  const ascii = thaiToArabicDigits(raw).replace(/[,\s฿$€£¥]/g, "");
  // Keep first valid decimal number we find.
  const m = ascii.match(/-?\d+(?:\.\d+)?/);
  return m ? m[0] : ascii;
}

/// Per-field plausibility check. Each entry is true if the field passes
/// sanity, false if it looks wrong. The caller uses this to drop the
/// failing fields' normalized values so the iOS UI flags them as needing
/// user input, while keeping good fields auto-filled. This is the soft
/// validation layer — it does NOT reject the scan as a whole. Layer 1
/// (is_receipt) handles the "this isn't a receipt at all" case.
function fieldPlausibility(opts: {
  merchant: string;
  amount: string;
  date: string;
  currency: string;
}): { merchant: boolean; amount: boolean; date: boolean; currency: boolean } {
  // Merchant: not blank and not a placeholder the model emits when it
  // gives up.
  const lowerMerchant = opts.merchant.trim().toLowerCase();
  const placeholders = ["", "n/a", "na", "unknown", "receipt", "merchant", "store", "shop", "—", "-"];
  const merchantOK = !placeholders.includes(lowerMerchant);
  // Amount: positive finite number, capped at 10M to catch parse glitches.
  const amountNum = Number(opts.amount);
  const amountOK = Number.isFinite(amountNum) && amountNum > 0 && amountNum <= 10_000_000;
  // Date: parses, and falls within ±5 years of today (catches misread
  // "best by" dates, OCR'd OS timestamps, etc.). Empty date is OK — the
  // user can supply one.
  let dateOK = true;
  if (opts.date) {
    const parsed = Date.parse(opts.date);
    if (!Number.isFinite(parsed)) {
      dateOK = false;
    } else {
      const fiveYears = 5 * 365 * 24 * 60 * 60 * 1000;
      dateOK = Math.abs(Date.now() - parsed) <= fiveYears;
    }
  }
  // Currency, if present, must be a real 3-letter ISO 4217 code.
  const currencyOK = !opts.currency || /^[A-Z]{3}$/.test(opts.currency);
  return { merchant: merchantOK, amount: amountOK, date: dateOK, currency: currencyOK };
}

/// Per-user rate limit. Stops a misuse case where someone iterates dozens
/// of random images at our OpenAI expense. Counts the user's own
/// receipt_scans rows in the last hour via the same RLS-aware client we
/// already have for everything else.
async function checkRateLimit(supabase: ReturnType<typeof createClient>): Promise<string | null> {
  const sinceISO = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count, error } = await supabase
    .from("receipt_scans")
    .select("id", { count: "exact", head: true })
    .gte("created_at", sinceISO);
  if (error) {
    // Don't block scans on a rate-limit query failure — log and continue.
    console.error("rate limit query failed:", error.message);
    return null;
  }
  const HOURLY_LIMIT = 30;
  if ((count ?? 0) >= HOURLY_LIMIT) {
    return `You've scanned ${HOURLY_LIMIT} receipts in the last hour. Try again later.`;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  let attachmentId: string;
  try {
    const body = await req.json();
    attachmentId = body.attachment_id ?? body.attachmentId;
    if (!attachmentId) return json({ error: "attachment_id is required" }, 400);
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    db: { schema: "turfmapp_expenses" },
    global: { headers: { Authorization: authHeader } },
  });

  // Layer 3 — rate limit. Cheap query against receipt_scans the caller can
  // already read via RLS, so no extra grants needed.
  const rateLimited = await checkRateLimit(supabase);
  if (rateLimited) {
    return json({ error: rateLimited }, 429);
  }

  const { data: attachment, error: attachmentError } = await supabase
    .from("attachments")
    .select("id, expense_id, workspace_id, storage_key, content_type")
    .eq("id", attachmentId)
    .is("deleted_at", null)
    .single();

  if (attachmentError || !attachment) {
    return json({ error: "Attachment not found or not accessible" }, 404);
  }

  const { data: scan, error: scanError } = await supabase
    .from("receipt_scans")
    .insert({
      attachment_id: attachment.id,
      expense_id: attachment.expense_id,
      status: "processing",
      provider: "openai",
    })
    .select("id")
    .single();

  if (scanError || !scan) {
    return json({ error: `Could not create scan: ${scanError?.message ?? "unknown"}` }, 500);
  }
  const scanId = scan.id as string;

  const fail = async (message: string) => {
    await supabase
      .from("receipt_scans")
      .update({ status: "failed", error_message: message })
      .eq("id", scanId);
    return json({
      id: scanId,
      attachment_id: attachment.id,
      expense_id: attachment.expense_id,
      status: "failed",
      error_message: message,
      receipt_scan_fields: [],
    });
  };

  if (!OPENAI_API_KEY) {
    return await fail("Receipt scanning is not configured (missing OPENAI_API_KEY secret).");
  }

  const { data: file, error: downloadError } = await supabase.storage
    .from(RECEIPT_BUCKET)
    .download(attachment.storage_key);

  if (downloadError || !file) {
    return await fail(`Could not download receipt: ${downloadError?.message ?? "unknown"}`);
  }

  const bytes = new Uint8Array(await file.arrayBuffer());
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  const base64 = btoa(binary);
  const mime = attachment.content_type || "image/jpeg";
  const dataUrl = `data:${mime};base64,${base64}`;

  let extracted: Record<string, string> = {};
  try {
    const completion = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: [
              "You extract structured data from receipts and tax invoices in any language.",
              "FIRST: decide whether the image is actually a receipt, tax invoice, or proof of purchase.",
              "Photos of meals, products, places, screenshots, memes, or random documents are NOT receipts even if they contain some text.",
              "Respond ONLY with a JSON object containing these keys:",
              "  is_receipt        — true or false. True only if the image clearly shows an itemized receipt, invoice, or other proof-of-purchase document with at least a merchant and a total.",
              "  rejection_reason  — Short user-facing reason when is_receipt is false (e.g. 'This looks like a photo of food, not a receipt.'). Empty string when is_receipt is true.",
              "  confidence        — 'high', 'medium', or 'low' — how sure you are about the extracted fields. 'low' for blurry, partial, or hard-to-read receipts.",
              "  merchant   — Business/store name, copied verbatim in its original script (English OR Thai). Do NOT transliterate.",
              "  amount     — Final total paid, as a plain numeric string with optional decimal. Convert Thai digits (๐-๙) to ASCII. Strip currency symbols, commas, and the word บาท.",
              "  currency   — ISO 4217 code (e.g. USD, THB, EUR). For Thai receipts default to THB if บาท or ฿ appears.",
              "  date       — Purchase date in YYYY-MM-DD. If the receipt uses Buddhist Era (พ.ศ., a 4-digit year ≥ 2400), KEEP the Buddhist year as-is — server code will convert it.",
              "  category   — One of: Meals, Travel, Software, Office, Other. Choose based on the items/business type.",
              "  language   — Either 'en' or 'th' depending on the receipt's primary language.",
              "If is_receipt is false, leave all other fields as empty strings. If is_receipt is true, use an empty string only for fields you genuinely cannot determine.",
            ].join(" "),
          },
          {
            role: "user",
            content: [
              { type: "text", text: "Extract the receipt fields." },
              { type: "image_url", image_url: { url: dataUrl } },
            ],
          },
        ],
      }),
    });

    if (!completion.ok) {
      return await fail(`Vision model error (${completion.status}): ${await completion.text()}`);
    }
    const payload = await completion.json();
    const content = payload?.choices?.[0]?.message?.content ?? "{}";
    extracted = JSON.parse(content);
  } catch (e) {
    return await fail(`Scan failed: ${e instanceof Error ? e.message : String(e)}`);
  }

  // Layer 1 — honour the model's own is_receipt judgment. If it says the
  // image isn't a receipt, stop here with the model's user-facing reason.
  const isReceipt = extracted["is_receipt"] === true || extracted["is_receipt"] === "true";
  if (!isReceipt) {
    const reason = String(extracted["rejection_reason"] ?? "").trim();
    return await fail(reason || "This doesn't look like a receipt. Please try another photo.");
  }

  // Post-process Thai-specific fields before persisting.
  const language = String(extracted["language"] ?? "").trim().toLowerCase();
  const rawValue = (key: string) => String(extracted[key] ?? "").trim();
  const normalizedAmount = normalizeAmount(rawValue("amount"));
  const normalizedDate = normalizeBuddhistDate(rawValue("date"));
  const currencyRaw = rawValue("currency").toUpperCase();
  // If the model misses currency on a Thai receipt, default to THB.
  const currency = currencyRaw || (language === "th" ? "THB" : "USD");

  // Layer 2 — per-field plausibility. Real receipts often have one field
  // we can't read cleanly (creased corner over the date, faded total, etc).
  // Rather than reject the whole scan, scrub the bad fields: keep the
  // extracted_value so the user sees what the model thought it read, but
  // drop the normalized_value and mark confidence=low so the iOS form
  // doesn't auto-fill that field and the user knows to type it in.
  const plausibility = fieldPlausibility({
    merchant: rawValue("merchant"),
    amount: normalizedAmount,
    date: normalizedDate,
    currency,
  });

  // When a field fails plausibility we clear BOTH extracted_value and
  // normalized_value. The iOS form falls back to extracted_value when
  // normalized is nil, so any value left in extracted_value would still
  // auto-fill the form with the bogus guess. Empty strings on both sides
  // surface as "the model couldn't read this" — the user types it in.
  const rows = [
    {
      field_name: "merchant",
      extracted_value: plausibility.merchant ? rawValue("merchant") : "",
      normalized_value: plausibility.merchant ? rawValue("merchant") || null : null,
      ok: plausibility.merchant,
    },
    {
      field_name: "amount",
      extracted_value: plausibility.amount ? rawValue("amount") : "",
      normalized_value: plausibility.amount ? (normalizedAmount || null) : null,
      ok: plausibility.amount,
    },
    {
      field_name: "currency",
      extracted_value: plausibility.currency ? rawValue("currency") : "",
      normalized_value: plausibility.currency ? currency : null,
      ok: plausibility.currency,
    },
    {
      field_name: "date",
      extracted_value: plausibility.date ? rawValue("date") : "",
      normalized_value: plausibility.date ? (normalizedDate || null) : null,
      ok: plausibility.date,
    },
    {
      field_name: "category",
      extracted_value: rawValue("category"),
      normalized_value: rawValue("category") || null,
      ok: !!rawValue("category"),
    },
    {
      field_name: "language",
      extracted_value: language,
      normalized_value: language || null,
      ok: !!language,
    },
  ].map((r) => ({
    receipt_scan_id: scanId,
    field_name: r.field_name,
    extracted_value: r.extracted_value,
    normalized_value: r.normalized_value,
    confidence: r.ok ? "high" : "low",
    confirmed_by_user: false,
  }));

  const { data: savedFields, error: fieldError } = await supabase
    .from("receipt_scan_fields")
    .upsert(rows, { onConflict: "receipt_scan_id,field_name" })
    .select("id, field_name, extracted_value, normalized_value, confidence, confirmed_by_user");

  if (fieldError) {
    return await fail(`Could not save fields: ${fieldError.message}`);
  }

  await supabase
    .from("receipt_scans")
    .update({ status: "needs_review", raw_result_json: extracted, error_message: null })
    .eq("id", scanId);

  return json({
    id: scanId,
    attachment_id: attachment.id,
    expense_id: attachment.expense_id,
    status: "needs_review",
    error_message: null,
    receipt_scan_fields: (savedFields ?? []) as ScanField[],
  });
});
