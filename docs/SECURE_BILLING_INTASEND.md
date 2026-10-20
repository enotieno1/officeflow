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


## Subscription behavior in this branch

- **Cards:** OfficeFlow creates an IntaSend recurring subscription plan, customer and subscription server-side. The customer adds a card on the provider-hosted setup page. The subscription is not marked active until a provider-verified invoice is reconciled. Each subscription event is checked against the provider's subscription record, plan amount/currency and payment-status API. Invoice IDs and event keys are idempotent.
- **M-Pesa:** Initial subscription and renewals use customer-confirmed STK prompts. A renewal is available during the final seven days of the current paid period; this flow does not claim silent automatic M-Pesa debits.
- **Cancellation:** The billing UI requests cancellation server-side. For cards it calls IntaSend's unsubscribe endpoint and checks the provider status; if the final status is not yet verified, the UI reports cancellation as pending. For M-Pesa it stops future manual renewals and preserves the recorded paid-period end.
- **Release requirements:** apply `20261020210000_intasend_recurring_card_subscriptions.sql`, deploy the latest `billing-checkout`, `intasend-webhook` and `billing-cancel` functions, set sandbox secrets and register `collection_event` and `subscription_event` webhooks. Run all sandbox payment, renewal, cancellation, replay, failure and two-tenant tests before live keys.
