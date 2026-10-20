import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const hashKey = async (parts: string[]) => crypto.subtle.digest("SHA-256", new TextEncoder().encode(parts.join(":")))
  .then((h) => Array.from(new Uint8Array(h)).map((b) => b.toString(16).padStart(2, "0")).join(""));
const providerStatus = async (secret: string, invoiceId: string) => {
  const response = await fetch("https://api.intasend.com/api/v1/payment/status/", {
    method: "POST", headers: { Authorization: "Bearer " + secret, "Content-Type": "application/json" },
    body: JSON.stringify({ invoice_id: invoiceId })
  });
  const data = await response.json().catch(() => ({})) as Record<string, unknown>;
  return { response, invoice: (data.invoice && typeof data.invoice === "object" ? data.invoice : data) as Record<string, unknown> };
};
const allowedInvoiceStates = ["PENDING", "PROCESSING", "RETRY", "PARTIAL", "COMPLETE", "FAILED", "CANCELED", "CANCELLED"];

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });
  const url = Deno.env.get("SUPABASE_URL"), service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const secret = Deno.env.get("INTASEND_SECRET_KEY"), challenge = Deno.env.get("INTASEND_WEBHOOK_CHALLENGE");
  if (!url || !service || !secret || !challenge) return reply(503, { error: "Webhook verification is not configured." });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid JSON" }); }
  if (typeof body.challenge !== "string" || body.challenge !== challenge) return reply(401, { error: "Webhook challenge mismatch" });

  const topic = typeof body.topic === "string" ? body.topic : "collection_event";
  const db = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });

  if (topic === "collection_event") {
    const event = body as Record<string, unknown>;
    const invoiceId = typeof event.invoice_id === "string" ? event.invoice_id : "";
    const apiRef = typeof event.api_ref === "string" ? event.api_ref : "";
    const incomingState = typeof event.state === "string" ? event.state.toUpperCase() : "";
    if (!invoiceId || !apiRef || !incomingState) return reply(200, { received: true, ignored: true });
    if (!allowedInvoiceStates.includes(incomingState)) return reply(400, { error: "Unsupported payment state" });
    const { data: attempt, error: lookupErr } = await db.from("billing_payment_attempts")
      .select("id,api_ref,provider_invoice_id").eq("api_ref", apiRef).maybeSingle();
    if (lookupErr) return reply(503, { error: "Could not find payment attempt; retry webhook" });
    if (!attempt) return reply(200, { received: true, ignored: true });
    let verified;
    try { verified = await providerStatus(secret, invoiceId); }
    catch { return reply(503, { error: "Provider verification unavailable; retry webhook" }); }
    if (!verified.response.ok) return reply(503, { error: "Provider verification failed; retry webhook" });
    const invoice = verified.invoice;
    const verifiedId = String(invoice.invoice_id ?? "");
    const verifiedRef = String(invoice.api_ref ?? "");
    const state = String(invoice.state ?? "").toUpperCase();
    const amount = Number(invoice.value), currency = String(invoice.currency ?? "");
    if (verifiedId !== invoiceId || verifiedRef !== apiRef || !Number.isFinite(amount) || !currency || !allowedInvoiceStates.includes(state)) {
      return reply(409, { error: "Verified provider invoice does not match the event" });
    }
    if (attempt.provider_invoice_id && attempt.provider_invoice_id !== invoiceId) return reply(409, { error: "Invoice ID does not match the stored attempt" });
    const eventKey = await hashKey(["intasend", topic, invoiceId, incomingState]);
    const { data: result, error: reconcileErr } = await db.rpc("fn_reconcile_intasend_payment", {
      p_event_key: eventKey, p_topic: topic, p_invoice_id: invoiceId, p_api_ref: apiRef,
      p_provider_state: state, p_provider_reference: invoice.provider_ref ?? invoice.mpesa_reference ?? null,
      p_amount: amount, p_currency: currency, p_failure_reason: invoice.failed_reason ?? invoice.failed_code ?? null
    });
    if (reconcileErr) return reply(503, { error: "Payment verification succeeded but reconciliation needs retry" });
    return reply(200, { received: true, status: result?.status ?? state.toLowerCase(), duplicate: result?.duplicate === true });
  }

  if (topic !== "subscription_event") return reply(200, { received: true, ignored: true });
  const subscriptionEvent = (body.subscription && typeof body.subscription === "object" ? body.subscription : body) as Record<string, unknown>;
  const providerSubscriptionId = typeof subscriptionEvent.subscription_id === "string" ? subscriptionEvent.subscription_id : "";
  const reference = typeof subscriptionEvent.reference === "string" ? subscriptionEvent.reference : "";
  if (!providerSubscriptionId || !reference) return reply(400, { error: "Subscription reference missing" });

  let local = (await db.from("billing_subscriptions").select(
    "id,organization_id,plan_id,status,payment_method,created_by,provider_subscription_id,provider_plan_id,provider_customer_id"
  ).eq("provider_subscription_id", providerSubscriptionId).maybeSingle()).data;
  if (!local) {
    const { data } = await db.from("billing_subscriptions").select(
      "id,organization_id,plan_id,status,payment_method,created_by,provider_subscription_id,provider_plan_id,provider_customer_id"
    ).eq("id", reference).maybeSingle();
    local = data;
  }
  if (!local || local.id !== reference || local.payment_method !== "card") return reply(200, { received: true, ignored: true });

  let providerResponse: Response;
  try {
    providerResponse = await fetch("https://api.intasend.com/api/v1/subscriptions/" + encodeURIComponent(providerSubscriptionId) + "/", {
      method: "GET", headers: { Authorization: "Bearer " + secret, "Content-Type": "application/json" }
    });
  } catch { return reply(503, { error: "Could not verify provider subscription; retry webhook" }); }
  const providerData = await providerResponse.json().catch(() => ({})) as Record<string, unknown>;
  if (!providerResponse.ok) return reply(503, { error: "Provider subscription verification failed; retry webhook" });
  const verifiedSub = (providerData.subscription && typeof providerData.subscription === "object"
    ? providerData.subscription : providerData) as Record<string, unknown>;
  const verifiedId = String(verifiedSub.subscription_id ?? verifiedSub.id ?? "");
  const verifiedReference = String(verifiedSub.reference ?? "");
  const status = String(verifiedSub.status ?? "").toUpperCase();
  const planObj = (verifiedSub.plan && typeof verifiedSub.plan === "object" ? verifiedSub.plan : {}) as Record<string, unknown>;
  const providerPlanId = String(planObj.plan_id ?? "");
  const amount = Number(planObj.amount), currency = String(planObj.currency ?? "");
  if (verifiedId !== providerSubscriptionId || verifiedReference !== reference ||
      providerPlanId !== String(local.provider_plan_id ?? "") || !allowedSubscriptionStates.includes(status)) {
    return reply(409, { error: "Provider subscription does not match OfficeFlow's stored subscription" });
  }
  const { data: localPlan, error: planErr } = await db.from("billing_plans")
    .select("amount,currency,interval_unit,interval_count").eq("id", local.plan_id).maybeSingle();
  if (planErr || !localPlan || Number(localPlan.amount) !== amount || localPlan.currency !== currency) {
    return reply(409, { error: "Provider recurring plan amount or currency does not match OfficeFlow's plan" });
  }
  const nextDateRaw = verifiedSub.next_date;
  const nextDate = typeof nextDateRaw === "string" && /^\d{4}-\d{2}-\d{2}$/.test(nextDateRaw) ? nextDateRaw : null;
  const cycles = Number.isInteger(Number(verifiedSub.completed_cycles)) ? Number(verifiedSub.completed_cycles) : 0;
  const failReason = typeof verifiedSub.fail_reason === "string" ? verifiedSub.fail_reason : null;

  if (!local.provider_subscription_id) {
    const { error: saveSubIdErr } = await db.from("billing_subscriptions").update({
      provider_subscription_id: providerSubscriptionId,
      provider_subscription_status: status,
      next_billing_at: nextDate,
      updated_at: new Date().toISOString()
    }).eq("id", local.id).is("provider_subscription_id", null);
    if (saveSubIdErr) return reply(503, { error: "Could not save provider subscription mapping; retry webhook" });
  }

  const payments = Array.isArray(subscriptionEvent.payments) ? subscriptionEvent.payments
    : Array.isArray(verifiedSub.payments) ? verifiedSub.payments : [];
  for (const item of payments) {
    if (!item || typeof item !== "object") continue;
    const payment = item as Record<string, unknown>;
    const invoice = (payment.invoice && typeof payment.invoice === "object" ? payment.invoice : payment) as Record<string, unknown>;
    const invoiceId = typeof invoice.invoice_id === "string" ? invoice.invoice_id : "";
    if (!invoiceId) continue;
    let verifiedPayment;
    try { verifiedPayment = await providerStatus(secret, invoiceId); }
    catch { return reply(503, { error: "Could not verify subscription invoice; retry webhook" }); }
    if (!verifiedPayment.response.ok) return reply(503, { error: "Subscription invoice verification failed; retry webhook" });
    const inv = verifiedPayment.invoice;
    const state = String(inv.state ?? "").toUpperCase();
    const paidAmount = Number(inv.value), paidCurrency = String(inv.currency ?? "");
    if (String(inv.invoice_id ?? "") !== invoiceId || !allowedInvoiceStates.includes(state) ||
        !Number.isFinite(paidAmount) || paidAmount !== Number(localPlan.amount) || paidCurrency !== localPlan.currency) {
      return reply(409, { error: "Recurring invoice failed server-side amount/currency verification" });
    }
    const { data: priorAttempt, error: priorErr } = await db.from("billing_payment_attempts")
      .select("id,api_ref").eq("provider_invoice_id", invoiceId).maybeSingle();
    if (priorErr) return reply(503, { error: "Could not check recurring invoice idempotency" });
    let localRef = priorAttempt?.api_ref;
    if (!priorAttempt) {
      localRef = "of-sub-" + local.id + "-" + invoiceId;
      const { error: insertErr } = await db.from("billing_payment_attempts").insert({
        organization_id: local.organization_id, subscription_id: local.id, plan_id: local.plan_id,
        initiated_by: local.created_by, provider: "intasend", payment_method: "card",
        api_ref: localRef, provider_invoice_id: invoiceId, amount: localPlan.amount,
        currency: localPlan.currency, status: "processing", provider_state: state
      });
      if (insertErr) {
        const { data: retryAttempt } = await db.from("billing_payment_attempts")
          .select("id,api_ref").eq("provider_invoice_id", invoiceId).maybeSingle();
        if (!retryAttempt) return reply(503, { error: "Could not record recurring invoice; retry webhook" });
        localRef = retryAttempt.api_ref;
      }
    }
    const eventKey = await hashKey(["intasend", "subscription_event", providerSubscriptionId, invoiceId, state]);
    const { error: reconcileErr } = await db.rpc("fn_reconcile_intasend_payment", {
      p_event_key: eventKey, p_topic: "subscription_event", p_invoice_id: invoiceId, p_api_ref: localRef,
      p_provider_state: state, p_provider_reference: inv.provider_ref ?? inv.mpesa_reference ?? null,
      p_amount: paidAmount, p_currency: paidCurrency, p_failure_reason: inv.failed_reason ?? inv.failed_code ?? null
    });
    if (reconcileErr) return reply(503, { error: "Recurring invoice verified but reconciliation needs retry" });
  }

  const statusKey = await hashKey(["intasend", "subscription-status", providerSubscriptionId, status, String(cycles), String(nextDate ?? ""), String(failReason ?? "")]);
  const { data: syncResult, error: syncErr } = await db.rpc("fn_sync_intasend_subscription_status", {
    p_event_key: statusKey, p_provider_subscription_id: providerSubscriptionId, p_reference: local.id,
    p_provider_status: status, p_next_date: nextDate, p_completed_cycles: cycles, p_fail_reason: failReason
  });
  if (syncErr) return reply(503, { error: "Subscription status verified but reconciliation needs retry" });
  return reply(200, { received: true, status: syncResult?.status ?? status.toLowerCase(), duplicate: syncResult?.duplicate === true });
});

const allowedSubscriptionStates = ["PENDING", "ACTIVE", "CANCELED", "CANCELLED", "COMPLETE", "FAILED"];
