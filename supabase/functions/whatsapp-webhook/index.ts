import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyMetaWebhookSignature } from "../_shared/meta-webhook-signature.ts";

const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

async function digest(bytes: Uint8Array): Promise<string> {
  const value = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...value].map((n) => n.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  if (req.method === "GET") {
    const configured = Deno.env.get("META_WHATSAPP_VERIFY_TOKEN");
    if (url.searchParams.get("hub.mode") === "subscribe" && configured &&
      url.searchParams.get("hub.verify_token") === configured && url.searchParams.has("hub.challenge")) {
      return new Response(url.searchParams.get("hub.challenge"), { status: 200 });
    }
    return reply(403, { error: "Webhook verification failed" });
  }
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });

  const secret = Deno.env.get("META_APP_SECRET");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!secret || !supabaseUrl || !serviceKey) return reply(503, { error: "Webhook is not configured" });

  const raw = new Uint8Array(await req.arrayBuffer());
  if (!await verifyMetaWebhookSignature(raw, req.headers.get("x-hub-signature-256"), secret)) {
    return reply(401, { error: "Invalid webhook signature" });
  }

  let payload: Record<string, unknown>;
  try {
    const value: unknown = JSON.parse(new TextDecoder().decode(raw));
    if (!value || typeof value !== "object" || Array.isArray(value)) return reply(400, { error: "Invalid payload" });
    payload = value as Record<string, unknown>;
  } catch {
    return reply(400, { error: "Invalid payload" });
  }

  const bodyDigest = await digest(raw);
  const events: Array<Record<string, unknown>> = [];
  const entries = Array.isArray(payload.entry) ? payload.entry : [];
  for (const entry of entries) {
    if (!entry || typeof entry !== "object") continue;
    const changes = Array.isArray((entry as Record<string, unknown>).changes)
      ? (entry as Record<string, unknown>).changes as unknown[] : [];
    for (const change of changes) {
      if (!change || typeof change !== "object") continue;
      const value = (change as Record<string, unknown>).value;
      if (!value || typeof value !== "object") continue;
      const data = value as Record<string, unknown>;
      const metadata = data.metadata && typeof data.metadata === "object"
        ? data.metadata as Record<string, unknown> : {};
      const phoneId = typeof metadata.phone_number_id === "string" ? metadata.phone_number_id : null;
      for (const [field, kind] of [["messages", "message"], ["statuses", "status"]] as const) {
        const items = Array.isArray(data[field]) ? data[field] as unknown[] : [];
        for (const item of items) {
          if (!item || typeof item !== "object") continue;
          const record = item as Record<string, unknown>;
          const id = typeof record.id === "string" ? record.id : bodyDigest;
          const status = typeof record.status === "string" ? record.status : "";
          const timestamp = typeof record.timestamp === "string" ? record.timestamp : "";
          events.push({
            provider_event_key: kind === "message" ? `message:${id}` : `status:${id}:${status}:${timestamp}`,
            event_type: kind === "message" ? "message" : `message_status:${status || "unknown"}`,
            phone_number_id: phoneId,
            payload_sha256: bodyDigest,
          });
        }
      }
    }
  }
  if (events.length === 0) events.push({
    provider_event_key: `envelope:${bodyDigest}`, event_type: "unclassified",
    phone_number_id: null, payload_sha256: bodyDigest,
  });

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await supabase.from("whatsapp_webhook_receipts")
    .upsert(events, { onConflict: "provider_event_key", ignoreDuplicates: true });
  if (error) return reply(503, { error: "Webhook receipt could not be persisted" });

  // Receipts only in this release; no approvals, payroll actions, payouts or credit decisions.
  return reply(200, { received: true, recorded: events.length });
});
