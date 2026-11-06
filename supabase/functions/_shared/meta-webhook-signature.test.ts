import { assertEquals } from "jsr:@std/assert";
import { verifyMetaWebhookSignature } from "./meta-webhook-signature.ts";

Deno.test("accepts a valid Meta-style HMAC SHA-256 signature", async () => {
  const body = new TextEncoder().encode("The quick brown fox jumps over the lazy dog");
  const valid = "sha256=f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8";
  assertEquals(await verifyMetaWebhookSignature(body, valid, "key"), true);
});

Deno.test("rejects a signature for a modified body", async () => {
  const body = new TextEncoder().encode("The quick brown fox jumps over the lazy dog.");
  const validForOriginal = "sha256=f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8";
  assertEquals(await verifyMetaWebhookSignature(body, validForOriginal, "key"), false);
});

Deno.test("rejects malformed headers and missing secrets", async () => {
  const body = new TextEncoder().encode("payload");
  assertEquals(await verifyMetaWebhookSignature(body, null, "key"), false);
  assertEquals(await verifyMetaWebhookSignature(body, "sha1=bad", "key"), false);
  assertEquals(await verifyMetaWebhookSignature(body, "sha256=bad", "key"), false);
  assertEquals(await verifyMetaWebhookSignature(body, "sha256=" + "0".repeat(64), ""), false);
});
