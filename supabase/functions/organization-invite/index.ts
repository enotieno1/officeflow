import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const appBaseUrl = (Deno.env.get("APP_BASE_URL") ?? "https://office-sort.vercel.app").replace(/\/$/, "");
const corsHeaders = {
  "Access-Control-Allow-Origin": appBaseUrl,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: corsHeaders });
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return new Response(JSON.stringify({ error: "Sign in as an organization administrator first." }), { status: 401, headers: corsHeaders });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) return new Response(JSON.stringify({ error: "Invitation service is not configured." }), { status: 500, headers: corsHeaders });

  const userClient = createClient(supabaseUrl, anonKey, { auth: { persistSession: false, autoRefreshToken: false }, global: { headers: { Authorization: `Bearer ${token}` } } });
  const adminClient = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  try {
    const { data: userData, error: userError } = await userClient.auth.getUser(token);
    if (userError || !userData.user?.email) return new Response(JSON.stringify({ error: "Your session is invalid or expired. Please sign in again." }), { status: 401, headers: corsHeaders });
    const body = await req.json();
    const email = String(body.email ?? "").trim().toLowerCase();
    const role = String(body.role ?? "employee");
    const unitId = body.unit_id ? String(body.unit_id) : null;
    const { data: invitationId, error: createError } = await userClient.rpc("fn_create_org_invitation", { p_email: email, p_role: role, p_unit_id: unitId });
    if (createError || !invitationId) return new Response(JSON.stringify({ error: createError?.message ?? "Could not create invitation." }), { status: 400, headers: corsHeaders });

    const redirectTo = `${appBaseUrl}/dashboard/accept-invitation.html?invitation_id=${encodeURIComponent(invitationId)}`;
    const { error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, { redirectTo, data: { invitation_id: invitationId } });
    if (inviteError) {
      await adminClient.from("organization_invitations").delete().eq("id", invitationId);
      return new Response(JSON.stringify({ error: inviteError.message || "The invitation email could not be sent." }), { status: 502, headers: corsHeaders });
    }
    return new Response(JSON.stringify({ success: true, invitation_id: invitationId, email, expires_in_days: 7 }), { status: 200, headers: corsHeaders });
  } catch (_error) {
    return new Response(JSON.stringify({ error: "Invitation could not be completed. Please try again." }), { status: 500, headers: corsHeaders });
  }
});