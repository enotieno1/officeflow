/**
 * Verify Meta Cloud API webhook signatures against the exact raw request body.
 * The GET webhook verification token is a separate mechanism and must not be used
 * as the POST app secret.
 */
export async function verifyMetaWebhookSignature(
  rawBody: Uint8Array,
  signatureHeader: string | null,
  appSecret: string,
): Promise<boolean> {
  if (!signatureHeader || !appSecret || !signatureHeader.startsWith("sha256=")) {
    return false;
  }

  const suppliedHex = signatureHeader.slice("sha256=".length);
  if (!/^[0-9a-f]{64}$/i.test(suppliedHex)) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(appSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const expected = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, rawBody),
  );
  const supplied = Uint8Array.from(
    suppliedHex.match(/.{2}/g)!.map((byte) => Number.parseInt(byte, 16)),
  );

  // Constant-time comparison for equal-length signatures.
  let mismatch = 0;
  for (let i = 0; i < expected.length; i++) mismatch |= expected[i] ^ supplied[i];
  return mismatch === 0;
}
