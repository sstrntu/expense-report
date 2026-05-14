type ScanReceiptRequest = {
  attachmentId?: string
  storagePath?: string
  signedUrl?: string
  contentType?: string
}

type ScanReceiptField = {
  fieldName: string
  extractedValue: string
  normalizedValue?: string
  confidence: 'high' | 'medium' | 'low' | 'manual'
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const openAIKey = Deno.env.get('OPENAI_API_KEY')
  if (!openAIKey) {
    return json({ error: 'OPENAI_API_KEY is not configured for this Edge Function.' }, 500)
  }

  const body = await request.json().catch(() => ({})) as ScanReceiptRequest
  if (!body.attachmentId && !body.storagePath && !body.signedUrl) {
    return json({ error: 'attachmentId, storagePath, or signedUrl is required.' }, 400)
  }

  const model = Deno.env.get('OPENAI_MODEL') ?? 'gpt-4.1-mini'
  const receiptReference = body.signedUrl ?? body.storagePath ?? body.attachmentId ?? 'receipt'

  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openAIKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: 'system',
          content: [
            {
              type: 'input_text',
              text: 'Extract expense receipt fields. Return only strict JSON with keys merchant, amount, currency, category, purchaseDate, confidenceNotes.',
            },
          ],
        },
        {
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: `Receipt reference: ${receiptReference}. If this is a signed URL, inspect the image/document and extract fields for an expense report.`,
            },
          ],
        },
      ],
      text: {
        format: {
          type: 'json_object',
        },
      },
    }),
  })

  if (!response.ok) {
    const message = await response.text()
    return json({ error: 'OpenAI receipt scan failed.', detail: message }, 502)
  }

  const result = await response.json()
  const extractedText = result.output_text ?? '{}'
  const parsed = safeJSON(extractedText)
  const fields: ScanReceiptField[] = normalizeFields(parsed)

  return json({
    attachmentId: body.attachmentId,
    status: 'needs_review',
    fields,
    raw: parsed,
  })
})

function normalizeFields(value: Record<string, unknown>): ScanReceiptField[] {
  return [
    field('merchant', value.merchant, undefined, 'medium'),
    field('amount', value.amount, value.amount, 'medium'),
    field('currency', value.currency ?? 'USD', value.currency ?? 'USD', 'medium'),
    field('category', value.category, value.category, 'low'),
    field('purchase_date', value.purchaseDate, value.purchaseDate, 'medium'),
  ].filter((item) => item.extractedValue.length > 0)
}

function field(
  fieldName: string,
  extractedValue: unknown,
  normalizedValue: unknown,
  confidence: ScanReceiptField['confidence'],
): ScanReceiptField {
  return {
    fieldName,
    extractedValue: String(extractedValue ?? ''),
    normalizedValue: normalizedValue == null ? undefined : String(normalizedValue),
    confidence,
  }
}

function safeJSON(text: string): Record<string, unknown> {
  try {
    const parsed = JSON.parse(text)
    return typeof parsed === 'object' && parsed !== null ? parsed as Record<string, unknown> : {}
  } catch {
    return {}
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}
