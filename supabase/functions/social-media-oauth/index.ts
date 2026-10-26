import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SITE_URL = Deno.env.get("SOCIAL_MEDIA_APP_URL") || "https://office-sort.vercel.app/dashboard/social-media-studio.html";
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
const cors = { "Access-Control-Allow-Origin": SITE_URL.startsWith("https://") ? "https://office-sort.vercel.app" : "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "GET,POST,OPTIONS", "Vary": "Origin" };
const providers = ["facebook", "x", "whatsapp", "linkedin"] as const;
type Provider = typeof providers[number];
const env = (k: string) => Deno.env.get(k) || "";
const redirectUri = () => env("SOCIAL_MEDIA_CALLBACK_URL") || `${SUPABASE_URL}/functions/v1/social-media-oauth?action=callback`;
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });
const redirect = (url: string) => new Response(null, { status: 302, headers: { Location: url, "Cache-Control": "no-store" } });
const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, "0")).join("");
async function digest(s: string) { return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s))); }
function b64url(bytes: Uint8Array) { return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, ""); }
async function encrypt(value: string) {
  const secret = env("SOCIAL_TOKEN_ENCRYPTION_KEY");
  if (!secret) throw new Error("SOCIAL_TOKEN_ENCRYPTION_KEY is not configured");
  const keyBytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  const key = await crypto.subtle.importKey("raw", keyBytes, "AES-GCM", false, ["encrypt"]);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(value));
  return `v1.${b64url(iv)}.${b64url(new Uint8Array(ciphertext))}`;
}
function credentials(p: Provider) {
  if (p === "facebook" || p === "whatsapp") return { id: env("META_APP_ID"), secret: env("META_APP_SECRET") };
  if (p === "x") return { id: env("X_CLIENT_ID"), secret: env("X_CLIENT_SECRET") };
  return { id: env("LINKEDIN_CLIENT_ID"), secret: env("LINKEDIN_CLIENT_SECRET") };
}
function missing(p: Provider) {
  const c = credentials(p);
  const names = p === "facebook" || p === "whatsapp" ? ["META_APP_ID", "META_APP_SECRET"] : p === "x" ? ["X_CLIENT_ID", "X_CLIENT_SECRET"] : ["LINKEDIN_CLIENT_ID", "LINKEDIN_CLIENT_SECRET"];
  return names.filter(n => !env(n));
}
async function getUser(req: Request) {
  const h = req.headers.get("Authorization") || "";
  const token = h.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await db.auth.getUser(token);
  return error ? null : data.user;
}
function authUrl(p: Provider, state: string, challenge?: string) {
  const c = credentials(p);
  const uri = redirectUri();
  const common = new URLSearchParams({ client_id: c.id, redirect_uri: uri, response_type: "code", state });
  if (p === "facebook") {
    common.set("scope", "pages_show_list,pages_read_engagement,pages_manage_posts");
    return "https://www.facebook.com/v23.0/dialog/oauth?" + common;
  }
  if (p === "whatsapp") {
    const configId = env("META_WHATSAPP_CONFIG_ID");
    if (!configId) throw new Error("META_WHATSAPP_CONFIG_ID is required for Meta WhatsApp Embedded Signup. Configure the approved Embedded Signup flow before connecting.");
    common.set("config_id", configId);
    common.set("response_type", "code");
    common.set("override_default_response_type", "true");
    common.set("extras", JSON.stringify({ setup: {} }));
    common.set("scope", "whatsapp_business_management,whatsapp_business_messaging,business_management");
    return "https://www.facebook.com/v23.0/dialog/oauth?" + common;
  }
  if (p === "x") {
    common.set("scope", "tweet.read tweet.write users.read offline.access");
    common.set("code_challenge", challenge || "");
    common.set("code_challenge_method", "S256");
    return "https://twitter.com/i/oauth2/authorize?" + common;
  }
  common.set("scope", "openid profile w_member_social");
  return "https://www.linkedin.com/oauth/v2/authorization?" + common;
}
async function exchange(p: Provider, code: string, verifier?: string) {
  const c = credentials(p);
  const form = new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: redirectUri(), client_id: c.id });
  if (p === "x" && verifier) form.set("code_verifier", verifier);
  if (p === "facebook" || p === "whatsapp") {
    form.set("client_secret", c.secret);
    const r = await fetch("https://graph.facebook.com/v23.0/oauth/access_token", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: form });
    const j = await r.json();
    if (!r.ok || !j.access_token) throw new Error("Meta token exchange failed: " + JSON.stringify(j).slice(0, 400));
    return j;
  }
  const headers: Record<string,string> = { "Content-Type": "application/x-www-form-urlencoded" };
  if (p === "x") headers.Authorization = "Basic " + btoa(`${c.id}:${c.secret}`);
  else form.set("client_secret", c.secret);
  const url = p === "x" ? "https://api.x.com/2/oauth2/token" : "https://www.linkedin.com/oauth/v2/accessToken";
  const r = await fetch(url, { method: "POST", headers, body: form });
  const j = await r.json();
  if (!r.ok || !j.access_token) throw new Error("Provider token exchange failed (" + p + "): " + JSON.stringify(j).slice(0, 400));
  return j;
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = new URL(req.url);
  const action = url.searchParams.get("action") || "status";
  try {
    if (action === "callback") {
      const code = url.searchParams.get("code") || "";
      const state = url.searchParams.get("state") || "";
      if (!code || !state) return redirect(SITE_URL + "?social_error=invalid_callback");
      const stateHash = await digest(state);
      const { data: saved, error } = await db.from("social_media_oauth_states").select("*").eq("state_hash", stateHash).gt("expires_at", new Date().toISOString()).maybeSingle();
      if (error || !saved) return redirect(SITE_URL + "?social_error=state_expired");
      const p = saved.provider as Provider;
      if (!providers.includes(p)) return redirect(SITE_URL + "?social_error=invalid_provider");
      await db.from("social_media_oauth_states").delete().eq("state_hash", stateHash);
      if (url.searchParams.get("error")) return redirect(SITE_URL + "?social_error=provider_denied");
      const tokens = await exchange(p, code, saved.code_verifier || undefined);
      const access = await encrypt(tokens.access_token);
      const refresh = tokens.refresh_token ? await encrypt(tokens.refresh_token) : null;
      const expiry = tokens.expires_in ? new Date(Date.now() + Number(tokens.expires_in) * 1000).toISOString() : null;
      const { error: saveError } = await db.from("social_media_connections").upsert({ user_id: saved.user_id, provider: p, encrypted_access_token: access, encrypted_refresh_token: refresh, token_expires_at: expiry, scopes: typeof tokens.scope === "string" ? tokens.scope.split(/[ ,]+/).filter(Boolean) : [], updated_at: new Date().toISOString() }, { onConflict: "user_id,provider" });
      if (saveError) throw saveError;
      return redirect(SITE_URL + "?social_connected=" + encodeURIComponent(p));
    }
    const user = await getUser(req);
    if (!user) return json({ error: "Authentication required" }, 401);
    if (action === "status") {
      const { data, error } = await db.from("social_media_connections").select("provider,account_name,account_id,scopes,token_expires_at,connected_at").eq("user_id", user.id);
      if (error) throw error;
      return json({ providers: providers.map(p => ({ provider: p, configured: missing(p).length === 0 && !!env("SOCIAL_TOKEN_ENCRYPTION_KEY"), missing_credentials: missing(p), connected: (data || []).some(x => x.provider === p), callback_url: redirectUri() })) });
    }
    if (action === "disconnect" && req.method === "POST") {
      const body = await req.json();
      const p = body.provider as Provider;
      if (!providers.includes(p)) return json({ error: "Unsupported provider" }, 400);
      const { error } = await db.from("social_media_connections").delete().eq("user_id", user.id).eq("provider", p);
      if (error) throw error;
      return json({ ok: true, provider: p });
    }
    if (action === "start" && req.method === "POST") {
      const body = await req.json();
      const p = body.provider as Provider;
      if (!providers.includes(p)) return json({ error: "Unsupported provider" }, 400);
      const absent = missing(p);
      if (!env("SOCIAL_TOKEN_ENCRYPTION_KEY")) absent.push("SOCIAL_TOKEN_ENCRYPTION_KEY");
      if (p === "whatsapp" && !env("META_WHATSAPP_CONFIG_ID")) absent.push("META_WHATSAPP_CONFIG_ID");
      if (absent.length) return json({ error: "Provider setup incomplete", provider: p, missing_credentials: absent }, 409);
      const state = b64url(crypto.getRandomValues(new Uint8Array(32)));
      let verifier = "";
      let challenge = "";
      if (p === "x") {
        verifier = b64url(crypto.getRandomValues(new Uint8Array(48)));
        challenge = b64url(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier)));
      }
      const { error } = await db.from("social_media_oauth_states").insert({ state_hash: await digest(state), user_id: user.id, provider: p, code_verifier: verifier || null, expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString() });
      if (error) throw error;
      return json({ authorization_url: authUrl(p, state, challenge), expires_in_seconds: 600 });
    }
    return json({ error: "Unsupported action" }, 400);
  } catch (e) {
    console.error("social-media-oauth error", String(e));
    return json({ error: "Social media integration request failed", detail: String(e).slice(0, 250) }, 500);
  }
});
