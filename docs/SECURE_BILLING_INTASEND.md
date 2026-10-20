# OfficeFlow secure billing — IntaSend

IntaSend is the selected first payment adapter for Kenya because its documented KES checkout supports M-Pesa and cards, and its API supports server-side payment-status verification and collection webhooks:
- https://developers.intasend.com/guides/collections/checkout/
- https://developers.intasend.com/guides/webhooks/
- https://developers.intasend.com/guides/collections/overview/

## Secrets
Set in Supabase Dashboard → Edge Functions → Secrets:
- INTASEND_SECRET_KEY (sandbox first; secret key must remain server-side)
- INTASEND_PUBLISHABLE_KEY (matching sandbox/live key)
- INTASEND_WEBHOOK_CHALLENGE (random high-entropy value; configure the same value in the IntaSend webhook dashboard)
- APP_BASE_URL (confirmed canonical OfficeFlow URL)
- APP_ORIGIN (exact browser origin)
Supabase supplies SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY. Never commit secrets.

## Provider setup
1. Create an IntaSend account and start with sandbox keys.
2. Register https://<project-ref>.supabase.co/functions/v1/intasend-webhook for collection_event.
3. Enable KES M-Pesa and Visa/Mastercard methods in the provider account.
4. Add reviewed pricing to billing_plans and set is_active=true only after the plan and seat entitlements are approved.
5. Run the E2E checklist in tests/billing_regression_checks.sql plus the webhook tests below before live keys.

## Safety
Browser redirect is not proof of payment. The webhook handler checks the configured challenge and re-queries IntaSend payment status using the server-side secret; invoice reference, API reference, amount, currency and state must match. Only verified COMPLETE activates a subscription. Browser roles have no write privileges on billing state. OfficeFlow never stores card number or CVV.

## Recurring billing limitation
This integration collects and verifies subscription payments, then records a paid period. It does not claim automatic card-on-file recurring charges or an M-Pesa recurring mandate. IntaSend documents card subscription APIs separately; that explicit card mandate flow, renewal scheduler, failed-renewal grace period and cancellation UX remain launch gates. M-Pesa currently needs a monthly renewal prompt unless the merchant account supports an approved mandate. Do not market automated renewals until those pieces and E2E tests pass.
