# OfficeFlow Social Media Integrations — Setup and Release Gates

## Implemented
- Social Media Studio page with draft planner and browser-local drafts.
- Supabase tables for OAuth state and social account connections. RLS is enabled and direct access for anon/authenticated is revoked; the Edge Function uses the service role.
- Edge Function `social-media-oauth` with authenticated start/status/disconnect actions, expiring one-time state, X PKCE, AES-GCM encrypted access/refresh tokens, and OAuth callbacks.
- The page has Connect buttons and checks server-side readiness.

## Production environment secrets
Set these in Supabase Edge Function secrets (never in frontend source, GitHub, or chat):
- `SOCIAL_TOKEN_ENCRYPTION_KEY`: long random secret (32+ random bytes encoded as text); changing it will make existing encrypted tokens unreadable.
- `SOCIAL_MEDIA_APP_URL`: `https://office-sort.vercel.app/dashboard/social-media-studio.html`
- `SOCIAL_MEDIA_CALLBACK_URL` (optional; recommended to keep exact): `https://oghowrilrhummzvrljdt.supabase.co/functions/v1/social-media-oauth?action=callback`
- Meta/Facebook/WhatsApp: `META_APP_ID`, `META_APP_SECRET`; WhatsApp Embedded Signup also needs `META_WHATSAPP_CONFIG_ID`.
- X: `X_CLIENT_ID`, `X_CLIENT_SECRET`.
- LinkedIn: `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`.

Supabase provides `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions. Never expose the service role key to a browser.

## Provider configuration and approvals
Register this exact callback URL for Facebook, WhatsApp, X and LinkedIn:
`https://oghowrilrhummzvrljdt.supabase.co/functions/v1/social-media-oauth?action=callback`

- **Facebook / Meta:** create a Meta app, configure Facebook Login and business use cases, add the callback URL, and request Page permissions appropriate to the features. For production access to non-role users, complete Meta App Review and business verification as applicable. Page publishing generally requires a Page access token and approved permissions; account connection alone does not mean publishing is enabled.
- **WhatsApp Business:** configure Meta WhatsApp Embedded Signup and supply `META_WHATSAPP_CONFIG_ID`; complete Meta business verification and WhatsApp Business Platform onboarding, select/verify a business phone number, and configure message templates/opt-in where required. This initial OAuth adapter is not a complete phone-number registration or message-delivery integration.
- **X:** create an X developer project/app, enable OAuth 2.0 Authorization Code with PKCE, register the callback, enable user authentication and request the scopes used by OfficeFlow. Posting access and rate limits depend on X developer plan/policy.
- **LinkedIn:** create a LinkedIn developer app, add the product(s) needed for sign-in and posting, register the callback, and obtain the relevant Community Management / posting permissions. Organisation publishing requires the appropriate product access and organisation role; `w_member_social` alone is member posting, not organisation posting.

## Current limits — do not represent as complete
- OAuth credentials are not yet configured in this environment. Connect buttons remain disabled until required secrets are present.
- The current OAuth flow stores encrypted tokens and connection state. Provider account discovery, Facebook Page token resolution, LinkedIn organisation selection, WhatsApp phone-number/WABA registration, token refresh/revocation, and **actual post/message publishing endpoints** still need provider-specific implementation and end-to-end tests before enabling production publishing.
- Do not send customer messages without consent, approved templates where applicable, and policy-compliant opt-in.
- Browser-local draft storage is not a shared team content calendar and does not sync between devices.
- Production Vercel deployment still needs independent HTTP verification. A GitHub commit is not proof of a successful Vercel deployment.

## Verification checklist
1. Confirm the Vercel deployment includes the latest Social Media Studio commit.
2. Configure secrets in Supabase Edge Function settings.
3. Register the exact callback URL in each provider developer console.
4. Sign in and verify the status endpoint reports configured.
5. Complete OAuth for a test account and verify the connection row contains encrypted—not plaintext—tokens.
6. Test expired/replayed state, wrong user, disconnect, revoked permission, expired token and provider errors.
7. Implement and test publishing separately before advertising auto-publishing.
