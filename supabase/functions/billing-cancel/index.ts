import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const origins = new Set((Deno.env.get("APP_ORIGINS") ?? "https://officeflow.co.ke,https://office-sort.vercel.app")
  .split(",").map(x => x.trim()).filter(Boolean));
const headers = (req: Request) => {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": origins.has(origin) ? origin : (origins.values().next().value ?? "https://officeflow.co.ke"),
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
    "Vary": "Origin"
  };
};
const reply = (req: Request, status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: headers(req) });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: headers(req) });
  if (req.method !== "POST") return reply(req, 405, { error: "Method not allowed" });
  const url = Deno.env.get("SUPABASE_URL"), anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"), secret = Deno.env.get("INTASEND_SECRET_KEY");
  if (!url || !anon || !service) return reply(req, 503, { error: "Billing service is not configured." });
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return reply(req, 401, { error: "Sign in to manage billing." });
  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return reply(req, 401, { error: "Session invalid or expired. Sign in again." });
  const db = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileErr } = await db.from("profiles").select("organization_id,role").eq("id", user.id).maybeSingle();
  if (profileErr || !profile?.organization_id || !["administrator", "super_admin"].includes(profile.role)) {
    return reply(req, 403, { error: "Only an organization administrator can cancel billing." });
  }
  const { data: sub, error: subErr } = await db.from("billing_subscriptions")
    .select("id,status,payment_method,provider_subscription_id,current_period_end")
    .eq("organization_id", profile.organization_id).in("status", ["pending", "active", "past_due"])
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (subErr) return reply(req, 500, { error: "Could not load the current subscription." });
  if (!sub) return reply(req, 409, { error: "No cancellable subscription was found." });

  if (sub.payment_method === "card") {
    if (!secret) return reply(req, 503, { error: "Provider cancellation is not configured. No cancellation was reported." });
    if (!sub.provider_subscription_id) {
      return reply(req, 409, { error: "The provider subscription reference is missing. Contact support so the provider account can be reconciled before cancellation.", reference: sub.id });
    }
    let cancelResponse: Response;
    try {
      cancelResponse = await fetch("https://api.intasend.com/api/v1/subscriptions/" + encodeURIComponent(sub.provider_subscription_id) + "/unsubscribe/", {
        method: "POST", headers: { Authorization: "Bearer " + secret, "Content-Type": "application/json" }
      });
    } catch {
      return reply(req, 503, { error: "Provider cancellation could not be confirmed. Do not assume the recurring charge has stopped; contact support.", reference: sub.id });
    }
    if (!cancelResponse.ok) return reply(req, 502, { error: "IntaSend rejected the cancellation request. The subscription status was not changed.", reference: sub.id });
    let verifyResponse: Response;
    try {
      verifyResponse = await fetch("https://api.intasend.com/api/v1/subscriptions/" + encodeURIComponent(sub.provider_subscription_id) + "/", {
        method: "GET", headers: { Authorization: "Bearer " + secret, "Content-Type": "application/json" }
      });
    } catch {
      await db.from("billing_subscriptions").update({ cancel_at_period_end: true, updated_at: new Date().toISOString() }).eq("id", sub.id);
      return reply(req, 202, { status: "processing", message: "Cancellation was accepted by IntaSend but its final state could not yet be verified. OfficeFlow will update the record when the provider webhook arrives.", reference: sub.id });
    }
    const payload = await verifyResponse.json().catch(() => ({})) as Record<string, unknown>;
    if (!verifyResponse.ok) {
      await db.from("billing_subscriptions").update({ cancel_at_period_end: true, updated_at: new Date().toISOString() }).eq("id", sub.id);
      return reply(req, 202, { status: "processing", message: "Cancellation was accepted by IntaSend but final verification is pending. Do not assume it is complete until OfficeFlow receives the provider update.", reference: sub.id });
    }
    const verified = (payload.subscription && typeof payload.subscription === "object" ? payload.subscription : payload) as Record<string, unknown>;
    const state = String(verified.status ?? "").toUpperCase();
    if (String(verified.subscription_id ?? verified.id ?? "") !== sub.provider_subscription_id) {
      return reply(req, 409, { error: "Provider subscription identity did not match. Contact support.", reference: sub.id });
    }
    if (state === "CANCELED" || state === "CANCELLED" || state === "COMPLETE") {
      const { error } = await db.from("billing_subscriptions").update({
        status: "cancelled", cancel_at_period_end: true, provider_subscription_status: state,
        provider_subscription_failure_reason: null, updated_at: new Date().toISOString()
      }).eq("id", sub.id);
      if (error) return reply(req, 503, { error: "Provider cancellation is confirmed but OfficeFlow could not update its record. Retry the page or contact support.", reference: sub.id });
      return reply(req, 200, { status: "cancelled", message: "IntaSend confirms recurring card billing is cancelled. The recorded paid-period end date has been preserved." });
    }
    const { error } = await db.from("billing_subscriptions").update({
      cancel_at_period_end: true, provider_subscription_status: state, updated_at: new Date().toISOString()
    }).eq("id", sub.id);
    if (error) return reply(req, 503, { error: "Cancellation was accepted by IntaSend but OfficeFlow could not store the request. Contact support.", reference: sub.id });
    return reply(req, 202, { status: "processing", message: "Cancellation was accepted but the provider has not confirmed a terminal status. OfficeFlow will reconcile the webhook before reporting cancellation complete." });
  }

  // M-Pesa is renewed only by a customer-confirmed STK prompt; cancelling this
  // record prevents further manual renewals without pretending an automatic debit existed.
  const { error } = await db.from("billing_subscriptions").update({
    status: "cancelled", cancel_at_period_end: true, updated_at: new Date().toISOString()
  }).eq("id", sub.id);
  if (error) return reply(req, 500, { error: "Could not record the cancellation. No cancellation was reported." });
  return reply(req, 200, { status: "cancelled", message: "Future M-Pesa renewals are stopped. The recorded paid-period end date has been preserved." });
});
