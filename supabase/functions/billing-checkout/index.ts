import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const allowedOrigins = new Set(
  (Deno.env.get("APP_ORIGINS") ?? "https://officeflow.co.ke,https://office-sort.vercel.app")
    .split(",").map((origin) => origin.trim()).filter(Boolean)
);
const corsHeaders = (req: Request) => {
  const requestedOrigin = req.headers.get("Origin") ?? "";
  const allowedOrigin = allowedOrigins.has(requestedOrigin)
    ? requestedOrigin
    : (allowedOrigins.values().next().value ?? "https://officeflow.co.ke");
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
    "Vary": "Origin"
  };
};
const reply = (req: Request, status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders(req) });
const phoneKE = (v: unknown) => {
  if (typeof v !== "string") return null;
  const d = v.replace(/[\s()+-]/g, "");
  if (/^0[17]\d{8}$/.test(d)) return "254" + d.slice(1);
  if (/^254[17]\d{8}$/.test(d)) return d;
  return null;
};
const providerPost = async (path: string, secret: string, payload: Record<string, unknown>) => {
  const response = await fetch("https://api.intasend.com/api/v1/" + path, {
    method: "POST",
    headers: { Authorization: "Bearer " + secret, "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  const data = await response.json().catch(() => ({}));
  return { response, data: data as Record<string, unknown> };
};
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });
  if (req.method !== "POST") return reply(req, 405, { error: "Method not allowed" });

  const url = Deno.env.get("SUPABASE_URL"), anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"), secret = Deno.env.get("INTASEND_SECRET_KEY");
  const app = Deno.env.get("APP_BASE_URL");
  if (!url || !anon || !service || !secret || !app) {
    return reply(req, 503, { error: "Billing is not configured. No payment was initiated." });
  }

  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return reply(req, 401, { error: "Sign in to manage billing." });
  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false, autoRefreshToken: false }
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return reply(req, 401, { error: "Session invalid or expired. Sign in again." });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(req, 400, { error: "Invalid request." }); }
  const planId = typeof body.plan_id === "string" ? body.plan_id : "";
  const method = body.payment_method;
  if (!planId || !["mpesa", "card"].includes(String(method))) {
    return reply(req, 400, { error: "Choose an active plan and M-Pesa or card." });
  }
  const phone = method === "mpesa" ? phoneKE(body.phone_number) : null;
  if (method === "mpesa" && !phone) return reply(req, 400, { error: "Enter a valid Kenyan mobile number." });
  if (method === "card" && !user.email) return reply(req, 400, { error: "Your account needs a verified email address before card subscription setup." });

  const db = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: pErr } = await db.from("profiles")
    .select("organization_id,role").eq("id", user.id).maybeSingle();
  if (pErr || !profile?.organization_id || !["administrator", "super_admin"].includes(profile.role)) {
    return reply(req, 403, { error: "Only an organization administrator can manage billing." });
  }
  const { data: plan } = await db.from("billing_plans")
    .select("id,name,amount,currency,interval_unit,interval_count")
    .eq("id", planId).eq("is_active", true).maybeSingle();
  if (!plan) return reply(req, 404, { error: "Plan unavailable. No payment was initiated." });

  const { data: existing, error: existingErr } = await db.from("billing_subscriptions")
    .select("id,status,plan_id,payment_method,current_period_end,provider_subscription_id,provider_setup_url,provider_customer_id,provider_plan_id,provider_subscription_status,provider_subscription_failure_reason,created_at")
    .eq("organization_id", profile.organization_id)
    .in("status", ["pending", "active", "past_due"])
    .order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (existingErr) return reply(req, 500, { error: "Could not check the current subscription." });

  const isMpesaRenewal = !!existing &&
    ["active", "past_due"].includes(existing.status) &&
    existing.payment_method === "mpesa" &&
    method === "mpesa";
  if (existing && ["active", "past_due"].includes(existing.status) && !isMpesaRenewal) {
    return reply(req, 409, {
      error: existing.payment_method === "card" && existing.status === "active"
        ? "Your card subscription is already active; recurring charges are managed by IntaSend."
        : "Resolve the existing subscription before starting a different payment method."
    });
  }
  if (isMpesaRenewal) {
    if (existing.plan_id !== plan.id) return reply(req, 409, { error: "Plan changes are not self-service yet. Renew the current plan or contact support." });
    const end = existing.current_period_end ? Date.parse(existing.current_period_end) : NaN;
    if (!Number.isFinite(end) || end > Date.now() + 7 * 86400000) {
      return reply(req, 409, { error: "M-Pesa renewal opens seven days before the current billing period ends." });
    }
  }
  if (existing?.status === "pending" && existing.payment_method !== method) {
    return reply(req, 409, { error: "Finish or reconcile the existing subscription setup before changing payment method." });
  }

  const subId = existing?.id ?? crypto.randomUUID();
  if (!existing) {
    const { error } = await db.from("billing_subscriptions").insert({
      id: subId, organization_id: profile.organization_id, plan_id: plan.id,
      status: "pending", payment_method: method, provider: "intasend", created_by: user.id
    });
    if (error) return reply(req, 500, { error: "Could not start subscription setup." });
  }

  const origin = app.replace(/\/$/, "");
  const metadata = (user.user_metadata ?? {}) as Record<string, unknown>;
  const names = (typeof metadata.full_name === "string" ? metadata.full_name : "OfficeFlow Customer").trim().split(/\s+/);
  const firstName = names[0] || "OfficeFlow", lastName = names.slice(1).join(" ") || "Customer";

  if (method === "card") {
    if (existing?.provider_subscription_id && existing.provider_setup_url && existing.status === "pending") {
      return reply(req, 200, {
        status: "processing", message: "Continue the secure card setup. The subscription activates only after provider-verified payment.",
        checkout_url: existing.provider_setup_url, reference: existing.id
      });
    }
    if (existing?.status === "pending" && existing.provider_subscription_id && !existing.provider_setup_url) {
      return reply(req, 409, {
        error: "The provider subscription exists but its secure setup URL is unavailable. Do not create another subscription; contact support.",
        reference: existing.id
      });
    }
    if (existing?.status === "pending" && !existing.provider_subscription_id) {
      const safeRetry = typeof existing.provider_subscription_failure_reason === "string" &&
        (existing.provider_subscription_failure_reason.includes("no card subscription was created") ||
         existing.provider_subscription_failure_reason.includes("no subscription was created"));
      if (!safeRetry) {
        return reply(req, 409, {
          error: "A card subscription setup is awaiting provider reconciliation. Do not retry; contact support with this subscription reference.",
          reference: existing.id
        });
      }
    }

    const customerResult = await providerPost("subscriptions-customers/", secret, {
      email: user.email, first_name: firstName, last_name: lastName, country: "KE",
      reference: String(profile.organization_id)
    }).catch(() => null);
    if (!customerResult || !customerResult.response.ok) {
      await db.from("billing_subscriptions").update({
        provider_subscription_failure_reason: "IntaSend customer setup failed; no card subscription was created.",
        updated_at: new Date().toISOString()
      }).eq("id", subId).is("provider_subscription_id", null);
      return reply(req, 502, { error: "Card customer setup failed. No successful payment was recorded; contact support before retrying.", reference: subId });
    }
    const customerData = customerResult.data;
    const customerId = String(customerData.customer_id ?? (customerData.customer as Record<string, unknown> | undefined)?.customer_id ?? (customerData.customer as Record<string, unknown> | undefined)?.id ?? customerData.id ?? "");
    if (!customerId) return reply(req, 502, { error: "IntaSend returned no customer reference. Contact support before retrying.", reference: subId });

    const intervalUnit = plan.interval_unit === "year" ? "Y" : "M";
    const planName = "OF " + (plan.id === "starter_monthly" ? "Starter" : "Professional") +
      " " + (intervalUnit === "Y" ? "Yearly " : "Monthly ") + String(plan.amount).replace(/\.00$/, "");
    const providerPlanResult = await providerPost("subscriptions-plans/", secret, {
      name: planName.slice(0, 32), amount: Number(plan.amount), currency: plan.currency,
      frequency: Number(plan.interval_count), frequency_unit: intervalUnit,
      billing_cycles: 2147483647, redirect_url: origin + "/dashboard/billing.html?payment=pending"
    }).catch(() => null);
    if (!providerPlanResult || !providerPlanResult.response.ok) {
      await db.from("billing_subscriptions").update({
        provider_customer_id: customerId,
        provider_subscription_failure_reason: "IntaSend recurring plan setup failed; no subscription was created.",
        updated_at: new Date().toISOString()
      }).eq("id", subId).is("provider_subscription_id", null);
      return reply(req, 502, { error: "Card plan setup failed. No card subscription was created; contact support before retrying.", reference: subId });
    }
    const providerPlanId = String(providerPlanResult.data.plan_id ?? (providerPlanResult.data.plan as Record<string, unknown> | undefined)?.plan_id ?? (providerPlanResult.data.plan as Record<string, unknown> | undefined)?.id ?? providerPlanResult.data.id ?? "");
    if (!providerPlanId) return reply(req, 502, { error: "IntaSend returned no recurring plan reference. Contact support before retrying.", reference: subId });

    const { error: localPlanErr } = await db.from("billing_subscriptions").update({
      provider_customer_id: customerId, provider_plan_id: providerPlanId,
      provider_subscription_failure_reason: null, updated_at: new Date().toISOString()
    }).eq("id", subId).is("provider_subscription_id", null);
    if (localPlanErr) return reply(req, 500, { error: "Provider plan exists but OfficeFlow could not store its reference. Contact support before retrying.", reference: subId });

    const providerSubscriptionResult = await providerPost("subscriptions/", secret, {
      customer_id: customerId, plan_id: providerPlanId, reference: subId,
      redirect_url: origin + "/dashboard/billing.html?payment=pending"
    }).catch(() => null);
    if (!providerSubscriptionResult || !providerSubscriptionResult.response.ok) {
      await db.from("billing_subscriptions").update({
        provider_subscription_failure_reason: "IntaSend subscription creation response was not confirmed; reconcile by OfficeFlow reference before retrying.",
        updated_at: new Date().toISOString()
      }).eq("id", subId).is("provider_subscription_id", null);
      return reply(req, 502, { error: "Card subscription setup could not be confirmed. Do not retry yet; contact support with this reference.", reference: subId });
    }
    const providerSubscription = providerSubscriptionResult.data;
    const providerSubscriptionId = String(providerSubscription.subscription_id ?? providerSubscription.id ?? "");
    const setupUrl = String(providerSubscription.setup_url ?? providerSubscription.url ?? "");
    if (!providerSubscriptionId || !/^https:\/\/(payment\.)?intasend\.com\//i.test(setupUrl)) {
      await db.from("billing_subscriptions").update({
        provider_subscription_failure_reason: "Provider returned an incomplete subscription response; reconcile before retrying.",
        updated_at: new Date().toISOString()
      }).eq("id", subId);
      return reply(req, 502, { error: "IntaSend returned an incomplete card setup response. Contact support before retrying.", reference: subId });
    }
    const { error: saveErr } = await db.from("billing_subscriptions").update({
      provider_subscription_id: providerSubscriptionId, provider_setup_url: setupUrl,
      provider_subscription_status: String(providerSubscription.status ?? "PENDING").toUpperCase(),
      provider_subscription_failure_reason: null, updated_at: new Date().toISOString()
    }).eq("id", subId);
    if (saveErr) return reply(req, 500, { error: "Provider subscription was created but OfficeFlow could not store its reference. Contact support before retrying.", reference: subId });
    return reply(req, 200, {
      status: "processing", message: "Add your card on IntaSend's secure page. Recurring billing activates only after provider-verified payment.",
      checkout_url: setupUrl, reference: subId
    });
  }

  // M-Pesa is a customer-confirmed STK payment. Renewals are available only
  // during the final seven days of the existing paid period.
  const { data: inFlight, error: flightErr } = await db.from("billing_payment_attempts")
    .select("id,api_ref,created_at").eq("subscription_id", subId)
    .in("status", ["pending", "processing"])
    .gte("created_at", new Date(Date.now() - 15 * 60 * 1000).toISOString())
    .limit(1).maybeSingle();
  if (flightErr) return reply(req, 500, { error: "Could not check existing payment attempts." });
  if (inFlight) return reply(req, 409, {
    error: "A payment attempt is already pending or processing. Check its status before trying again.",
    reference: inFlight.api_ref
  });

  const apiRef = "of-" + crypto.randomUUID();
  const { error: attemptErr } = await db.from("billing_payment_attempts").insert({
    organization_id: profile.organization_id, subscription_id: subId, plan_id: plan.id,
    initiated_by: user.id, provider: "intasend", payment_method: "mpesa",
    api_ref: apiRef, amount: plan.amount, currency: plan.currency, status: "pending"
  });
  if (attemptErr) return reply(req, 500, { error: "Could not create a payment attempt. No payment was initiated." });

  const payload = {
    amount: Number(plan.amount), currency: plan.currency, email: user.email ?? "",
    first_name: firstName, last_name: lastName, phone_number: phone,
    api_ref: apiRef, redirect_url: origin + "/dashboard/billing.html?payment=pending", host: origin
  };
  let response: Response;
  try {
    response = await fetch("https://api.intasend.com/api/v1/payment/mpesa-stk-push/", {
      method: "POST", headers: { Authorization: "Bearer " + secret, "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
  } catch {
    await db.from("billing_payment_attempts").update({
      status: "processing", failure_reason: "Provider response was uncertain; reconcile this reference before retrying.",
      updated_at: new Date().toISOString()
    }).eq("api_ref", apiRef);
    return reply(req, 502, { error: "Payment provider response was uncertain. Do not retry yet; contact support with the reference.", reference: apiRef });
  }
  const provider = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok) {
    await db.from("billing_payment_attempts").update({
      status: "failed", failure_reason: "Provider rejected checkout request.", updated_at: new Date().toISOString()
    }).eq("api_ref", apiRef);
    return reply(req, 502, { error: "Payment provider rejected the request. No successful payment recorded." });
  }
  const invoiceId = provider.invoice_id ?? (provider.invoice as Record<string, unknown> | undefined)?.invoice_id;
  const checkoutUrl = provider.url ?? provider.checkout_url ?? null;
  if (!invoiceId) {
    await db.from("billing_payment_attempts").update({
      status: "processing", failure_reason: "Provider response had no invoice ID; reconcile before retrying.",
      updated_at: new Date().toISOString()
    }).eq("api_ref", apiRef);
    return reply(req, 502, { error: "Provider returned no invoice reference. The attempt is retained for reconciliation; do not retry yet.", reference: apiRef });
  }
  const { error: payErr } = await db.from("billing_payment_attempts").update({
    status: "processing", provider_state: "PROCESSING", provider_invoice_id: String(invoiceId),
    checkout_url: checkoutUrl, updated_at: new Date().toISOString()
  }).eq("api_ref", apiRef).neq("status", "paid");
  if (payErr) return reply(req, 500, { error: "Provider may have started a payment prompt. The attempt is retained for reconciliation; do not retry yet.", reference: apiRef });
  return reply(req, 200, {
    status: "processing", message: isMpesaRenewal
      ? "Complete the M-Pesa renewal prompt. Your paid period extends only after IntaSend verifies payment."
      : "Complete the M-Pesa prompt on your phone. OfficeFlow will verify payment.",
    checkout_url: checkoutUrl, reference: apiRef
  });
});
