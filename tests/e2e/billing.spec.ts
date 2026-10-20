import { test, expect } from "@playwright/test";

const baseURL = (process.env.OFFICEFLOW_BASE_URL || "").replace(/\/$/, "");
const supabaseURL = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
test.beforeEach(() => {
  test.skip(!baseURL, "Set OFFICEFLOW_BASE_URL to the deployed branch-preview URL; tests must not guess which deployment is live.");
});
const email = process.env.OFFICEFLOW_E2E_EMAIL;
const password = process.env.OFFICEFLOW_E2E_PASSWORD;

async function signIn(page: import("@playwright/test").Page) {
  test.skip(!email || !password, "Set OFFICEFLOW_E2E_EMAIL and OFFICEFLOW_E2E_PASSWORD for authenticated E2E tests.");
  await page.goto(baseURL + "/dashboard/auth.html");
  await page.locator("#signInEmail").fill(email!);
  await page.locator("#signInPassword").fill(password!);
  await page.locator("#signInForm button[type=submit]").click();
  await expect(page).not.toHaveURL(/auth\.html/, { timeout: 15000 });
}

test("public landing page avoids false trial claims and routes the Starter plan to sign-up", async ({ page }) => {
  await page.goto(baseURL + "/");
  await expect(page.getByText(/free 14-day trial/i)).toHaveCount(0);
  await expect(page.locator('[data-plan-id="starter_monthly"]')).toBeVisible();
  await page.locator('[data-plan-id="starter_monthly"]').click();
  await expect(page).toHaveURL(/auth\.html\?mode=signup/);
  const url = new URL(page.url());
  expect(url.searchParams.get("next")).toBe("/dashboard/billing.html?plan=starter_monthly");
});

test("pricing is public and its Starter CTA preserves the selected plan through sign-up", async ({ page }) => {
  await page.goto(baseURL + "/dashboard/pricing.html");
  await expect(page.getByRole("heading", { name: "Simple, Transparent Pricing" })).toBeVisible();
  await expect(page.getByText(/14-day free trial/i)).toHaveCount(0);
  await page.getByRole("link", { name: "Get Started" }).first().click();
  await expect(page).toHaveURL(/auth\.html\?mode=signup/);
  const url = new URL(page.url());
  expect(url.searchParams.get("next")).toBe("/dashboard/billing.html?plan=starter_monthly");
  await expect(page.locator("#signUpForm")).toBeVisible();
});

test("billing page redirects unauthenticated visitors and preserves the return path", async ({ page }) => {
  await page.goto(baseURL + "/dashboard/billing.html");
  await expect(page).toHaveURL(/auth\.html/);
  const url = new URL(page.url());
  expect(url.searchParams.get("next")).toBe("/dashboard/billing.html");
});

test("checkout endpoint refuses unauthenticated requests", async ({ request }) => {
  test.skip(!supabaseURL, "Set SUPABASE_URL to a dedicated staging project; endpoint tests never default to production.");
  const response = await request.post(supabaseURL + "/functions/v1/billing-checkout", {
    data: { plan_id: "starter_monthly", payment_method: "card" }
  });
  expect([401, 403]).toContain(response.status());
  const body = await response.text();
  expect(body.toLowerCase()).not.toContain('"status":"paid"');
});

test("signed-in organization administrator sees database-backed published plans", async ({ page }) => {
  await signIn(page);
  await page.goto(baseURL + "/dashboard/billing.html");
  await expect(page.getByRole("heading", { name: "Subscription & billing" })).toBeVisible();
  await expect(page.getByText("Starter", { exact: true })).toBeVisible();
  await expect(page.getByText("Professional", { exact: true })).toBeVisible();
  await expect(page.getByText(/10,000/)).toBeVisible();
  await expect(page.getByText(/no subscription prices have been published/i)).toHaveCount(0);
});

test("optional sandbox card checkout redirects to IntaSend and does not claim payment success", async ({ page }) => {
  test.skip(process.env.RUN_BILLING_SANDBOX_HANDOFF !== "1" || /(^|\.)officeflow\.co\.ke$|(^|\.)office-sort\.vercel\.app$/.test(new URL(baseURL).hostname), "Opt-in only on a dedicated preview/staging app with sandbox merchant credentials.");
  await signIn(page);
  await page.goto(baseURL + "/dashboard/billing.html");
  const cardSelect = page.locator("select").first();
  await cardSelect.selectOption("card");
  const checkout = page.getByRole("button", { name: "Continue to secure payment" }).first();
  await checkout.click();
  await expect(page).toHaveURL(/intasend\.com/, { timeout: 20000 });
  // This deliberately stops at provider-hosted sandbox checkout. It never asserts
  // payment success from the browser redirect; complete a provider sandbox payment
  // and verify the webhook/database state separately before enabling live keys.
});

test("webhook rejects an invalid challenge once provider secrets are configured", async ({ request }) => {
  test.skip(process.env.RUN_BILLING_WEBHOOK_E2E !== "1" || !supabaseURL, "Enable only against a dedicated staging Supabase project after setting sandbox secrets.");
  const response = await request.post(supabaseURL + "/functions/v1/intasend-webhook", {
    data: { topic: "collection_event", challenge: "deliberately-wrong", invoice_id: "not-a-real-invoice", api_ref: "not-a-real-reference", state: "COMPLETE" }
  });
  expect(response.status()).toBe(401);
  expect((await response.text()).toLowerCase()).not.toContain('"status":"paid"');
});
