# Supabase And OpenAI Setup

This app should keep the mobile client and server-side secrets separate.

## Mobile App Values

The iOS app may contain only mobile-safe Supabase values:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

These are currently represented in `ios/TurfmappExpenseReport/Info.plist` and read through `AppEnvironment`.

Never put these values in the iOS app:

- `OPENAI_API_KEY`
- `SUPABASE_SECRET_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## OpenAI Secret

The OpenAI key belongs in Supabase Edge Function secrets.

For local development, copy:

```bash
cp supabase/functions/.env.example supabase/functions/.env
```

Then fill:

```env
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4.1-mini
SUPABASE_STORAGE_RECEIPT_BUCKET=receipts
```

For hosted Supabase:

```bash
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set OPENAI_MODEL=gpt-4.1-mini
```

Or from an env file:

```bash
supabase secrets set --env-file supabase/functions/.env
```

## Receipt Scan Flow

1. iOS uploads receipt to Supabase Storage.
2. iOS creates an attachment row.
3. iOS invokes `scan-receipt`.
4. `scan-receipt` reads `OPENAI_API_KEY` from Supabase secrets.
5. `scan-receipt` calls OpenAI and returns normalized fields.
6. iOS shows fields for user review before submission.

## Local Function Command

```bash
supabase functions serve scan-receipt --env-file supabase/functions/.env
```

## Deploy Function

```bash
supabase functions deploy scan-receipt
```
