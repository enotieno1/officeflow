import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!url || !serviceKey || !authHeader) return reply(401, { error: "Authentication required" });

  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userResult, error: userError } = await userClient.auth.getUser();
  const user = userResult?.user;
  if (userError || !user) return reply(401, { error: "Invalid session" });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "Invalid JSON" }); }
  const payrollRunId = typeof body.payroll_run_id === "string" ? body.payroll_run_id : "";
  const providerAccountId = typeof body.provider_account_id === "string" ? body.provider_account_id : "";
  const idempotencyKey = typeof body.idempotency_key === "string" ? body.idempotency_key.trim() : "";
  if (!payrollRunId || !providerAccountId || !/^[A-Za-z0-9._:-]{8,120}$/.test(idempotencyKey)) {
    return reply(400, { error: "Provide payroll_run_id, provider_account_id and a valid idempotency_key" });
  }

  const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await db.from("profiles")
    .select("organization_id,role").eq("id", user.id).maybeSingle();
  if (profileError || !profile?.organization_id || !["administrator", "super_admin"].includes(profile.role)) {
    return reply(403, { error: "Only an organization administrator can prepare a payroll payment batch" });
  }

  const { data: existing } = await db.from("payroll_payment_batches")
    .select("id,status,total_amount,item_count").eq("organization_id", profile.organization_id)
    .eq("idempotency_key", idempotencyKey).maybeSingle();
  if (existing) return reply(200, { batch: existing, duplicate_request: true, payout_started: false });

  const { data: run, error: runError } = await db.from("payroll_runs")
    .select("id,organization_id,status,approved_by,net_total,currency")
    .eq("id", payrollRunId).eq("organization_id", profile.organization_id).maybeSingle();
  if (runError || !run) return reply(404, { error: "Payroll run not found for this organization" });
  if (run.status !== "approved" || !run.approved_by || run.approved_by === user.id) {
    return reply(409, { error: "Payroll must be approved by a different authorized user before a payment batch can be prepared" });
  }

  const { data: providerAccount, error: providerError } = await db.from("payroll_provider_accounts")
    .select("id,organization_id,provider,status,environment,account_label")
    .eq("id", providerAccountId).eq("organization_id", profile.organization_id).maybeSingle();
  if (providerError || !providerAccount) return reply(404, { error: "Provider account not found for this organization" });
  if (providerAccount.status !== "active") return reply(409, { error: "Provider account must be verified and active before preparing a batch" });
  if (run.currency !== "KES") return reply(409, { error: "Only KES payroll is supported" });

  const { data: items, error: itemsError } = await db.from("payroll_items")
    .select("id,organization_id,employee_id,net_pay")
    .eq("payroll_run_id", run.id).eq("organization_id", profile.organization_id);
  if (itemsError) return reply(503, { error: "Could not load payroll items" });
  if (!items?.length || items.some((item) => !item.employee_id || Number(item.net_pay) <= 0)) {
    return reply(409, { error: "Payroll must contain employee-linked items with positive net pay" });
  }
  const total = Math.round(items.reduce((sum, item) => sum + Math.round(Number(item.net_pay) * 100), 0)) / 100;
  if (Math.abs(total - Number(run.net_total)) > 0.01) {
    return reply(409, { error: "Payroll item total does not match the approved payroll control total" });
  }

  const { data: batch, error: batchError } = await db.from("payroll_payment_batches").insert({
    organization_id: profile.organization_id,
    payroll_run_id: run.id,
    provider_account_id: providerAccount.id,
    provider: providerAccount.provider,
    currency: "KES",
    total_amount: total,
    item_count: items.length,
    status: "pending_approval",
    created_by: user.id,
    idempotency_key: idempotencyKey,
  }).select("id,status,total_amount,item_count,provider,created_at").single();
  if (batchError || !batch) {
    if (batchError?.code === "23505") return reply(409, { error: "A batch with this idempotency key already exists; refresh and review it" });
    return reply(503, { error: "Could not create payment batch" });
  }

  const rows = items.map((item) => ({
    organization_id: profile.organization_id,
    batch_id: batch.id,
    payroll_item_id: item.id,
    provider: providerAccount.provider,
    amount: Number(item.net_pay),
    currency: "KES",
    status: "queued",
  }));
  const { error: transactionError } = await db.from("payroll_payment_transactions").insert(rows);
  if (transactionError) {
    await db.from("payroll_payment_batches").update({ status: "failed" }).eq("id", batch.id);
    return reply(503, { error: "Batch created but transaction records failed; batch marked failed for administrator review" });
  }

  await db.from("payroll_audit_events").insert({
    organization_id: profile.organization_id,
    payroll_run_id: run.id,
    actor_id: user.id,
    event_type: "payment_batch_prepared",
    event_details: { batch_id: batch.id, provider: providerAccount.provider, total_amount: total, item_count: items.length, status: "pending_approval" },
  });

  return reply(201, {
    batch,
    message: "Payment batch prepared for separate approval. No provider request or salary transfer has been initiated.",
    payout_started: false,
    next_gate: "A different authorized approver must approve the batch; provider payout remains disabled until the provider adapter and server-side credentials are configured.",
  });
});
