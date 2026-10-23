import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });
const present = (name: string) => Boolean(Deno.env.get(name)?.trim());

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "GET" && req.method !== "POST") return reply(405, { error: "Method not allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");
  let anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!anonKey) {
    try { anonKey = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}").default; } catch { /* handled below */ }
  }
  if (!url || !serviceKey || !anonKey || !authHeader) return reply(401, { error: "Authentication required" });

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) return reply(401, { error: "Invalid session" });

  const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: profile, error: profileError } = await db.from("profiles")
    .select("organization_id,role").eq("id", user.id).maybeSingle();
  if (profileError || !profile?.organization_id || !["administrator", "super_admin"].includes(profile.role)) {
    return reply(403, { error: "Only an organization administrator can view payment-provider readiness" });
  }

  const environment = Deno.env.get("OFFICEFLOW_DARAJA_ENV")?.trim().toLowerCase() ?? "";
  const credentials = {
    consumer_key: present("DARAJA_CONSUMER_KEY"),
    consumer_secret: present("DARAJA_CONSUMER_SECRET"),
    shortcode: present("DARAJA_B2C_SHORTCODE"),
    initiator_name: present("DARAJA_INITIATOR_NAME"),
    initiator_password: present("DARAJA_INITIATOR_PASSWORD"),
    public_certificate: present("DARAJA_PUBLIC_CERT_PEM"),
    result_callback_secret: present("DARAJA_CALLBACK_SECRET"),
  };
  const { data: accounts, error: accountError } = await db.from("payroll_provider_accounts")
    .select("id,account_label,environment,status,business_shortcode,callback_url")
    .eq("organization_id", profile.organization_id)
    .eq("provider", "safaricom_mpesa_b2c");

  if (accountError) return reply(503, { error: "Could not inspect provider account configuration" });

  const environmentValid = environment === "sandbox" || environment === "production";
  const credentialsComplete = Object.values(credentials).every(Boolean);
  const productionConfigured = environment === "production" && credentialsComplete;
  const activeAccount = (accounts ?? []).some((a) =>
    a.status === "active" && a.environment === environment &&
    (!a.business_shortcode || a.business_shortcode === Deno.env.get("DARAJA_B2C_SHORTCODE"))
  );

  return reply(200, {
    provider: "safaricom_mpesa_b2c",
    environment: environmentValid ? environment : "not_configured",
    credentials_present: credentials,
    credentials_complete: credentialsComplete,
    organization_provider_account: (accounts ?? []).map((a) => ({
      id: a.id, account_label: a.account_label, environment: a.environment,
      status: a.status, shortcode_configured: Boolean(a.business_shortcode),
      callback_url_configured: Boolean(a.callback_url),
    })),
    checks: {
      environment_configured: environmentValid,
      all_required_secret_values_present: credentialsComplete,
      matching_active_organization_account: activeAccount,
      production_credentials_configured: productionConfigured,
      production_approval_verified: false,
      payout_adapter_enabled: false,
    },
    live_disbursement_enabled: false,
    payout_started: false,
    next_steps: [
      "Apply for and receive Safaricom B2C/Bulk Disbursement approval and a production shortcode.",
      "Set provider credentials only in Supabase Edge Function Secrets; never put them in the browser, database, or chat.",
      "Create and verify the organization's provider account and confirm the legal business owns the shortcode.",
      "Complete sandbox adapter tests, callback reconciliation and independent payroll-batch approval before enabling any live payout path.",
    ],
  });
});
