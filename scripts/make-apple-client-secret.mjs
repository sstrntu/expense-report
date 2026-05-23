#!/usr/bin/env node
// Generates the Apple OAuth client secret JWT that Supabase's "Secret Key
// (for OAuth)" field expects. Sign in with Apple gives you a .p8 private key;
// this script signs a short-lived JWT with that key using Apple's required
// ES256 algorithm + custom header (kid).
//
// Usage:
//   node scripts/make-apple-client-secret.mjs \
//     --team-id HAS8MJEJM2 \
//     --services-id com.turfmapp.expense-report.signin \
//     --key-id ABC1234567 \
//     --p8 /path/to/AuthKey_ABC1234567.p8 \
//     [--days 180]                 # JWT lifetime (max 180 = 6 months)
//
// Output: the JWT string. Paste it into Supabase → Auth → Providers → Apple
// → Secret Key (for OAuth).
//
// Note: Apple caps JWT lifetime at 6 months. Re-run this script and update
// the Supabase field every ~5 months.

import { readFileSync } from "node:fs";
import { createSign } from "node:crypto";

function parseArgs() {
  const args = process.argv.slice(2);
  const out = {};
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (!flag.startsWith("--")) continue;
    const key = flag.slice(2);
    out[key] = args[i + 1];
    i++;
  }
  return out;
}

function base64url(input) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buf
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

// Convert ASN.1 DER ECDSA signature (what node's crypto produces) to the raw
// r||s 64-byte concatenation that JWT/ES256 expects. Apple is strict about this.
function derToJoseEcdsa(der) {
  // SEQUENCE { INTEGER r, INTEGER s }
  if (der[0] !== 0x30) throw new Error("Invalid DER signature");
  const seqLen = der[1];
  let offset = 2;
  if (seqLen & 0x80) offset += seqLen & 0x7f;
  // INTEGER r
  if (der[offset] !== 0x02) throw new Error("Invalid DER: expected INTEGER (r)");
  const rLen = der[offset + 1];
  let r = der.subarray(offset + 2, offset + 2 + rLen);
  offset += 2 + rLen;
  // INTEGER s
  if (der[offset] !== 0x02) throw new Error("Invalid DER: expected INTEGER (s)");
  const sLen = der[offset + 1];
  let s = der.subarray(offset + 2, offset + 2 + sLen);

  // Pad/trim to 32 bytes each
  const fix = (buf) => {
    if (buf.length === 32) return buf;
    if (buf.length === 33 && buf[0] === 0x00) return buf.subarray(1);
    if (buf.length < 32) {
      const padded = Buffer.alloc(32);
      buf.copy(padded, 32 - buf.length);
      return padded;
    }
    throw new Error("ECDSA component longer than 32 bytes");
  };
  return Buffer.concat([fix(r), fix(s)]);
}

const args = parseArgs();
const required = ["team-id", "services-id", "key-id", "p8"];
for (const k of required) {
  if (!args[k]) {
    console.error(`Missing required flag: --${k}`);
    console.error("See header comment for usage.");
    process.exit(1);
  }
}

const teamId = args["team-id"];
const servicesId = args["services-id"];
const keyId = args["key-id"];
const days = Math.min(parseInt(args.days || "180", 10), 180);
const privateKey = readFileSync(args.p8, "utf8");

const now = Math.floor(Date.now() / 1000);
const header = { alg: "ES256", kid: keyId, typ: "JWT" };
const payload = {
  iss: teamId,
  iat: now,
  exp: now + days * 24 * 60 * 60,
  aud: "https://appleid.apple.com",
  sub: servicesId,
};

const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
const signer = createSign("SHA256");
signer.update(signingInput);
const derSig = signer.sign({ key: privateKey, format: "pem" });
const joseSig = derToJoseEcdsa(derSig);

const jwt = `${signingInput}.${base64url(joseSig)}`;
console.log(jwt);
