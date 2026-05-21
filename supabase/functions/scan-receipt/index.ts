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
              "Respond ONLY with a JSON object containing these keys:",
              "  merchant   — Business/store name, copied verbatim in its original script (English OR Thai). Do NOT transliterate.",
              "  amount     — Final total paid, as a plain numeric string with optional decimal. Convert Thai digits (๐-๙) to ASCII. Strip currency symbols, commas, and the word บาท.",
              "  currency   — ISO 4217 code (e.g. USD, THB, EUR). For Thai receipts default to THB if บาท or ฿ appears.",
              "  date       — Purchase date in YYYY-MM-DD. If the receipt uses Buddhist Era (พ.ศ., a 4-digit year ≥ 2400), KEEP the Buddhist year as-is — server code will convert it.",
              "  category   — One of: Meals, Travel, Software, Office, Other. Choose based on the items/business type.",
              "  language   — Either 'en' or 'th' depending on the receipt's primary language.",
              "Use an empty string for any field you cannot determine.",
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

  // Post-process Thai-specific fields before persisting.
  const language = String(extracted["language"] ?? "").trim().toLowerCase();
  const rawValue = (key: string) => String(extracted[key] ?? "").trim();
  const normalizedAmount = normalizeAmount(rawValue("amount"));
  const normalizedDate = normalizeBuddhistDate(rawValue("date"));
  const currencyRaw = rawValue("currency").toUpperCase();
  // If the model misses currency on a Thai receipt, default to THB.
  const currency = currencyRaw || (language === "th" ? "THB" : "USD");

  const rows = [
    { field_name: "merchant", extracted_value: rawValue("merchant"), normalized_value: rawValue("merchant") || null },
    { field_name: "amount", extracted_value: rawValue("amount"), normalized_value: normalizedAmount || null },
    { field_name: "currency", extracted_value: rawValue("currency"), normalized_value: currency },
    { field_name: "date", extracted_value: rawValue("date"), normalized_value: normalizedDate || null },
    { field_name: "category", extracted_value: rawValue("category"), normalized_value: rawValue("category") || null },
    { field_name: "language", extracted_value: language, normalized_value: language || null },
  ].map((r) => ({
    receipt_scan_id: scanId,
    field_name: r.field_name,
    extracted_value: r.extracted_value,
    normalized_value: r.normalized_value,
    confidence: r.extracted_value ? "high" : "low",
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
