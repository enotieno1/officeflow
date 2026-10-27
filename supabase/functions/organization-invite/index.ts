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
    const suppliedInvitationId = body.invitation_id ? String(body.invitation_id) : null;
    if (!email || email.length > 320 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return new Response(JSON.stringify({ error: "Enter a valid invitation email address." }), { status: 400, headers: corsHeaders });
    }

    let invitationId: string;
    let createdHere = false;
    if (suppliedInvitationId) {
      // Onboarding creates the invitation record transactionally with the organization.
      // Only its creator may ask this function to send that exact pending invitation.
      const { data: profile, error: profileError } = await userClient.from("profiles")
        .select("role,organization_id").eq("id", userData.user.id).single();
      if (profileError || profile?.role !== "administrator" || !profile.organization_id) {
        return new Response(JSON.stringify({ error: "Only an organization administrator can send invitations." }), { status: 403, headers: corsHeaders });
      }
      const { data: invite, error: inviteLookupError } = await adminClient.from("organization_invitations")
        .select("id,email,role,status,expires_at,invited_by,organization_id")
        .eq("id", suppliedInvitationId).maybeSingle();
      if (inviteLookupError || !invite || invite.invited_by !== userData.user.id ||
          invite.organization_id !== profile.organization_id || invite.email !== email ||
          invite.role !== role || invite.status !== "pending" || new Date(invite.expires_at).getTime() <= Date.now()) {
        return new Response(JSON.stringify({ error: "This invitation is missing, expired, or not authorized for your organization." }), { status: 403, headers: corsHeaders });
      }
      invitationId = invite.id;
    } else {
      const { data, error: createError } = await userClient.rpc("fn_create_org_invitation", { p_email: email, p_role: role, p_unit_id: unitId });
      if (createError || !data) return new Response(JSON.stringify({ error: createError?.message ?? "Could not create invitation." }), { status: 400, headers: corsHeaders });
      invitationId = data;
      createdHere = true;
    }

    const redirectTo = `${appBaseUrl}/dashboard/accept-invitation.html?invitation_id=${encodeURIComponent(invitationId)}`;
    const { error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, { redirectTo, data: { invitation_id: invitationId } });
    if (inviteError) {
      // Keep onboarding-created invitations pending so an administrator can retry delivery.
      if (createdHere) await adminClient.from("organization_invitations").delete().eq("id", invitationId);
      return new Response(JSON.stringify({ error: inviteError.message || "The invitation email could not be sent." }), { status: 502, headers: corsHeaders });
    }
    return new Response(JSON.stringify({ success: true, invitation_id: invitationId, email, expires_in_days: 7 }), { status: 200, headers: corsHeaders });
  } catch (_error) {
    return new Response(JSON.stringify({ error: "Invitation could not be completed. Please try again." }), { status: 500, headers: corsHeaders });
  }
});
