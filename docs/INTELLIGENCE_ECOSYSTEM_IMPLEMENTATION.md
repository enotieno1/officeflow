# OfficeFlow Intelligence & Ecosystem Strategy — Implementation Specification

**Status:** phased implementation specification; only features explicitly marked implemented below are available. This document is not evidence of provider onboarding, regulatory certification, or production rollout.

## Product principle
Make OfficeFlow an accountable operating system, not a collection of disconnected AI demos. Every recommendation must show source data, confidence/coverage, the reason for the recommendation, and a human approval path. Financial, payroll, identity, and access-control decisions remain server-authoritative.

## 1. Predictive operations

### Procurement forecasting
- Begin with per-item consumption history, current on-hand quantity, open purchase orders, lead time, supplier, minimum order quantity and safety stock.
- Forecast daily/weekly demand only when there is sufficient history; show a low-confidence state when data is sparse.
- Calculate reorder point from observed demand during lead time plus approved safety stock. Show inputs and the calculation.
- Generate a draft purchase order for review; never auto-sign, submit to a vendor, or move money without explicit authorization.
- Acceptance: backtest forecasts on held-out historical periods; compare against simple moving-average baseline; log overrides and forecast error.

### Bottleneck diagnostics
- Derive cycle time from immutable request/step timestamps and status transitions, segmented by workflow, step, unit and time period.
- Display median and 90th-percentile time, overdue share, sample size and comparison window. Avoid naming an individual as a bottleneck without sufficient sample size and role-authorized access.
- Suggest rerouting only as a proposed configuration change; require workflow owner approval and retain before/after audit records.
- Acceptance: KPIs reconcile to source rows; small samples are suppressed; no invented cycle times.

## 2. Cross-border and FinTech readiness

### Multi-currency
- Store money as integer minor units plus ISO 4217 currency; never sum currencies without an explicit conversion.
- Keep transaction currency, functional/reporting currency, FX rate, rate timestamp/source and converted amount separately. Preserve historical rates for audit.
- Start with KES; add NGN, GHS and ZAR through a tested currency configuration and verified rate provider.
- Tax, payroll, statutory deductions, wage rules and e-invoicing must be country modules reviewed by qualified local specialists. No claim of automatic compliance until country tests are passed.
- Stablecoin support is not enabled by this plan. Treat it as a separately gated future integration requiring jurisdictional, custody, sanctions, accounting, and provider review.

### Opt-in SME credit data export
- Off by default and tenant-admin enabled only after explicit authorization and a clear data-sharing agreement.
- Share minimum necessary aggregates (for example, invoice aging, cash-flow regularity and verified transaction counts), not raw employee records or unrestricted audit logs.
- Preview exact fields, purpose, recipient, retention and revocation before export. Log consent, exports and revocation. Never make credit eligibility decisions inside OfficeFlow.
- Conduct privacy impact assessment and local legal review before launch.

## 3. Mobile-first field work

### WhatsApp interactive approvals
- Use the official WhatsApp Business Platform and supported interactive templates/flows only.
- Every action link/token must be short-lived, single-use, audience-bound, signed, replay-protected and verified server-side. High-risk actions require login/step-up authentication; a chat tap alone is not sufficient authorization.
- Validate webhook signatures, idempotency, rate limits, delivery status and fallback path. Never expose secrets in the browser.
- Start with low-risk task acknowledgements and read-only summaries; payout approval is later, after security review and dual control.

### Voice-to-task
- Start as a draft composer: browser speech recognition where supported, with language choice (English and Swahili where the browser offers it), manual correction, and explicit submit.
- Treat Sheng and code-switching as unvalidated until tested with representative speakers and consented evaluation data. Show the raw transcript and formatted draft side by side.
- Do not record in the background. Request microphone access only after a deliberate user action. Provide a typing fallback.
- Acceptance: test on low-end Android devices and weak networks; measure word error rate by language, accent and noise; do not claim support for a language without evaluation.

## 4. Device/session risk controls
- Prefer secure session lifecycle, server-side step-up verification, and risk signals over invasive or brittle fingerprinting. Browser fingerprints are probabilistic and can be spoofed; do not use them as identity proof.
- For sensitive actions, combine recent authentication, role/tenant checks, amount/risk thresholds, new-session signals and server-side policy. Use verified OTP channels only after provider delivery is configured.
- Apply transaction-specific holds for review rather than indiscriminately locking an entire account. Provide recovery, support, audit trail and appeal path.
- Never store raw fingerprint data unnecessarily. Publish purpose/retention and complete a privacy assessment before collecting device signals.

## Delivery phases and release gates
1. **P0 — data and access audit:** map source tables, RLS, timestamps, event coverage, roles, storage and current provider state. Test tenant isolation.
2. **P1 — bottleneck insights:** source-reconciled cycle-time analytics with sample sizes and explainable recommendations.
3. **P2 — procurement draft forecast:** inventory/consumption data model, backtest, editable draft PO, approval and audit.
4. **P3 — voice draft capture:** browser-supported transcription, editable draft and keyboard fallback; evaluate English/Swahili before launch.
5. **P4 — currency foundation:** integer minor units, currency-safe ledger, rate provenance; no tax/payroll automation until country-specific review.
6. **P5 — secure messaging actions:** official provider onboarding, webhook verification, signed one-time actions and replay tests.
7. **P6 — risk-based step-up:** session-risk events, OTP adapter, review holds and recovery flows.
8. **P7 — opt-in credit export:** data minimization, consent/revocation, partner contract, privacy review and sandbox certification.

## Global release gates
- No simulated payment success; provider result is verified server-side and reconciled.
- No automatic purchase-order signing or financial approval.
- All high-risk state transitions are server-authoritative, version-checked and audited.
- Tests cover tenant isolation, role authorization, retries/idempotency, replay attempts, stale versions, offline/reconnect, low bandwidth and mobile usability.
- Show feature status honestly: available, partial, provider setup required, or not enabled. Never equate database row counts with successful delivery.
