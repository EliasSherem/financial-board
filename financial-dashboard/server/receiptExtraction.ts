import OpenAI from 'openai';

export type ReceiptPaymentMethod = 'cash' | 'card' | 'transfer' | 'unknown';
export type ReceiptCurrency = 'MXN' | 'USD';

export type ExtractReceiptInput = {
  imageBuffer: Buffer;
  mimeType: string;
  userId: number;
};

export type ExtractedReceipt = {
  merchant: string | null;
  date: string | null;
  total: number | null;
  currency: ReceiptCurrency | null;
  payment_method: ReceiptPaymentMethod;
  category: string | null;
  description: string | null;
  items: Array<{ name: string; amount: number | null }>;
  tax: number | null;
  tip: number | null;
  confidence: number;
  warnings: string[];
};

const DEFAULT_RECEIPT_EXTRACTION_MODEL = 'gpt-4.1-mini';
const VALID_CURRENCIES = new Set<ReceiptCurrency>(['MXN', 'USD']);
const VALID_PAYMENT_METHODS = new Set<ReceiptPaymentMethod>([
  'cash',
  'card',
  'transfer',
  'unknown',
]);

const RECEIPT_EXTRACTION_PROMPT = `You are extracting financial transaction data from a receipt image.

Return only valid JSON matching this schema:
{
  "merchant": string | null,
  "date": "YYYY-MM-DD" | null,
  "total": number | null,
  "currency": "MXN" | "USD" | null,
  "payment_method": "cash" | "card" | "transfer" | "unknown",
  "category": string | null,
  "description": string | null,
  "items": [
    {
      "name": string,
      "amount": number | null
    }
  ],
  "tax": number | null,
  "tip": number | null,
  "confidence": number,
  "warnings": string[]
}

Rules:
- Extract the final paid total, not subtotal.
- Ignore loyalty points, savings, authorization numbers, card endings, invoice numbers, and change due.
- If multiple totals exist, choose the amount most likely paid by the customer.
- Do not invent values.
- If unsure, set confidence below 0.75 and add a warning.
- Normalize dates to YYYY-MM-DD.
- Use null for missing or uncertain fields.
- If the year is missing, infer only if clearly safe from receipt context; otherwise return null.
- Currency can default to MXN only if the receipt clearly appears Mexican or the app context strongly implies MXN.
- description should be a clean transaction description, usually the merchant name or short purchase summary.
- category should be a reasonable generic category string for now.`;

const RECEIPT_EXTRACTION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    merchant: { type: ['string', 'null'] },
    date: { type: ['string', 'null'] },
    total: { type: ['number', 'null'] },
    currency: { type: ['string', 'null'], enum: ['MXN', 'USD', null] },
    payment_method: {
      type: 'string',
      enum: ['cash', 'card', 'transfer', 'unknown'],
    },
    category: { type: ['string', 'null'] },
    description: { type: ['string', 'null'] },
    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          name: { type: 'string' },
          amount: { type: ['number', 'null'] },
        },
        required: ['name', 'amount'],
      },
    },
    tax: { type: ['number', 'null'] },
    tip: { type: ['number', 'null'] },
    confidence: { type: 'number' },
    warnings: { type: 'array', items: { type: 'string' } },
  },
  required: [
    'merchant',
    'date',
    'total',
    'currency',
    'payment_method',
    'category',
    'description',
    'items',
    'tax',
    'tip',
    'confidence',
    'warnings',
  ],
};

let openaiClient: OpenAI | null = null;

function getOpenAiClient(): OpenAI {
  if (openaiClient) return openaiClient;
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey) {
    throw new Error('OPENAI_API_KEY is not configured');
  }
  openaiClient = new OpenAI({ apiKey });
  return openaiClient;
}

function receiptExtractionModel(): string {
  return process.env.RECEIPT_EXTRACTION_MODEL?.trim() || DEFAULT_RECEIPT_EXTRACTION_MODEL;
}

function nullableString(value: unknown, maxLength = 255): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
}

function nullableFiniteNumber(value: unknown): number | null {
  const num = typeof value === 'number' ? value : typeof value === 'string' ? Number(value) : NaN;
  if (!Number.isFinite(num)) return null;
  return Math.round(num * 100) / 100;
}

function normalizeConfidence(value: unknown): number {
  const num = typeof value === 'number' ? value : typeof value === 'string' ? Number(value) : 0;
  if (!Number.isFinite(num)) return 0;
  return Math.max(0, Math.min(1, num));
}

function normalizeDate(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return null;

  const date = new Date(`${trimmed}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return null;
  if (date.toISOString().slice(0, 10) !== trimmed) return null;
  return trimmed;
}

function normalizeCurrency(value: unknown): ReceiptCurrency | null {
  if (typeof value !== 'string') return null;
  const upper = value.trim().toUpperCase();
  return VALID_CURRENCIES.has(upper as ReceiptCurrency) ? (upper as ReceiptCurrency) : null;
}

function normalizePaymentMethod(value: unknown): ReceiptPaymentMethod {
  if (typeof value !== 'string') return 'unknown';
  const normalized = value.trim().toLowerCase();
  return VALID_PAYMENT_METHODS.has(normalized as ReceiptPaymentMethod)
    ? (normalized as ReceiptPaymentMethod)
    : 'unknown';
}

function normalizeWarnings(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => nullableString(entry, 180))
    .filter((entry): entry is string => entry !== null)
    .slice(0, 12);
}

function normalizeItems(value: unknown): Array<{ name: string; amount: number | null }> {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => {
      if (!entry || typeof entry !== 'object') return null;
      const item = entry as Record<string, unknown>;
      const name = nullableString(item.name, 160);
      if (!name) return null;
      return {
        name,
        amount: nullableFiniteNumber(item.amount),
      };
    })
    .filter((entry): entry is { name: string; amount: number | null } => entry !== null)
    .slice(0, 80);
}

function parseResponseJson(outputText: string): unknown {
  const trimmed = outputText.trim();
  if (!trimmed) {
    throw new Error('Receipt extraction returned an empty response');
  }
  return JSON.parse(trimmed);
}

function normalizeExtractedReceipt(raw: unknown): ExtractedReceipt {
  const source = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  return {
    merchant: nullableString(source.merchant),
    date: normalizeDate(source.date),
    total: nullableFiniteNumber(source.total),
    currency: normalizeCurrency(source.currency),
    payment_method: normalizePaymentMethod(source.payment_method),
    category: nullableString(source.category, 100),
    description: nullableString(source.description),
    items: normalizeItems(source.items),
    tax: nullableFiniteNumber(source.tax),
    tip: nullableFiniteNumber(source.tip),
    confidence: normalizeConfidence(source.confidence),
    warnings: normalizeWarnings(source.warnings),
  };
}

export async function extractReceiptFromImage({
  imageBuffer,
  mimeType,
  userId,
}: ExtractReceiptInput): Promise<ExtractedReceipt> {
  const client = getOpenAiClient();
  const normalizedMime = mimeType.trim().toLowerCase();
  const imageBase64 = imageBuffer.toString('base64');
  const imageDataUrl = `data:${normalizedMime};base64,${imageBase64}`;
  const model = receiptExtractionModel();

  console.info('Receipt extraction request', {
    user_id: userId,
    model,
    mime_type: normalizedMime,
    image_size_bytes: imageBuffer.length,
  });

  const response = await client.responses.create({
    model,
    input: [
      {
        role: 'user',
        content: [
          { type: 'input_text', text: RECEIPT_EXTRACTION_PROMPT },
          { type: 'input_image', image_url: imageDataUrl, detail: 'high' },
        ],
      },
    ],
    text: {
      format: {
        type: 'json_schema',
        name: 'receipt_transaction_extraction',
        strict: true,
        schema: RECEIPT_EXTRACTION_SCHEMA,
      },
    },
    temperature: 0,
    max_output_tokens: 1200,
    store: false,
    user: String(userId),
  });

  if (response.error) {
    throw new Error(`Receipt extraction failed: ${response.error.message}`);
  }

  const normalized = normalizeExtractedReceipt(parseResponseJson(response.output_text || ''));
  console.info('Receipt extraction completed', {
    user_id: userId,
    has_total: normalized.total !== null,
    has_date: normalized.date !== null,
    confidence: normalized.confidence,
    warning_count: normalized.warnings.length,
  });

  return normalized;
}
