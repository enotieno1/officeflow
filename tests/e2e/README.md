# Billing E2E tests

These are launch-gate tests, not a substitute for a real provider sandbox payment.

## Prerequisites
- Node.js and a browser-supported test environment.
- Install Playwright in a disposable checkout: `npm install --no-save @playwright/test`, then `npx playwright install chromium`.
- The billing page and Edge Functions must be deployed to the same test environment.
- Use an organization administrator test account and IntaSend sandbox keys only. Never run the optional checkout test against live keys.

## Run
Set:
- `OFFICEFLOW_BASE_URL` to the deployed test/preview URL.
- `OFFICEFLOW_E2E_EMAIL` and `OFFICEFLOW_E2E_PASSWORD` to a dedicated administrator test account.
Then run:
`npx playwright test tests/e2e/billing.spec.ts`

Optional tests:
- `RUN_BILLING_SANDBOX_HANDOFF=1` opens the sandbox card checkout; the test intentionally stops before payment completion.
- `RUN_BILLING_WEBHOOK_E2E=1` checks that an invalid webhook challenge is rejected. Set the webhook secret first.

## Manual provider end-to-end gate
1. Complete a sandbox card payment or M-Pesa STK prompt.
2. Confirm IntaSend sends collection_event to the deployed webhook URL.
3. Verify the provider-status API call succeeds and matches the stored API reference, invoice ID, amount and KES currency.
4. Verify exactly one paid attempt and an active subscription period are written.
5. Replay the same webhook and verify no duplicate payment/period extension.
6. Test failed/canceled payments and wrong challenge/reference/amount/currency; none may activate a subscription.
7. Test with two organization identities and verify neither can read the other's billing rows.
8. Do not switch to live keys until every required case passes.

This session did not run authenticated browser E2E or a provider sandbox payment because the provider account secrets and a dedicated test account are not configured here.
