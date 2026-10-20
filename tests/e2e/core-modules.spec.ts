import { test, expect } from "@playwright/test";

const baseURL = (process.env.OFFICEFLOW_BASE_URL || "").replace(/\/$/, "");
const email = process.env.OFFICEFLOW_E2E_EMAIL;
const password = process.env.OFFICEFLOW_E2E_PASSWORD;

test.beforeEach(() => {
  test.skip(!baseURL, "Set OFFICEFLOW_BASE_URL to the deployed branch-preview URL.");
});

async function signIn(page: import("@playwright/test").Page) {
  test.skip(!email || !password, "Set dedicated OFFICEFLOW_E2E_EMAIL and OFFICEFLOW_E2E_PASSWORD credentials.");
  await page.goto(baseURL + "/dashboard/auth.html");
  await page.locator("#signInEmail").fill(email!);
  await page.locator("#signInPassword").fill(password!);
  await page.locator("#signInForm button[type=submit]").click();
  await expect(page).not.toHaveURL(/auth\.html/, { timeout: 15000 });
}

test("protected task page redirects a signed-out visitor", async ({ page }) => {
  await page.goto(baseURL + "/dashboard/tasks-management.html");
  await expect(page).toHaveURL(/auth\.html/);
});

test("authenticated user can create, update and delete their own task", async ({ page }) => {
  test.skip(process.env.RUN_MUTATING_E2E !== "1" || /(^|\\.)officeflow\\.co\\.ke$|(^|\\.)office-sort\\.vercel\\.app$/.test(new URL(baseURL).hostname), "Mutating tests are allowed only against a dedicated staging/preview app and test organization.");
  await signIn(page);
  await page.goto(baseURL + "/dashboard/tasks-management.html");
  await expect(page.getByRole("heading", { name: "Tasks" })).toBeVisible();
  const title = "OfficeFlow E2E task " + Date.now();
  await page.getByRole("button", { name: "+ New task" }).click();
  await page.locator("#taskTitle").fill(title);
  await page.locator("#taskDescription").fill("Temporary record created by the automated regression suite.");
  await page.locator("#saveTask").click();
  const task = page.locator("article.task-card").filter({ hasText: title });
  await expect(task).toBeVisible({ timeout: 10000 });
  await task.getByRole("button", { name: "Start" }).click();
  await expect(task.getByText("In progress", { exact: true })).toBeVisible();
  page.once("dialog", dialog => dialog.accept());
  await task.getByRole("button", { name: "Delete" }).click();
  await expect(task).toHaveCount(0, { timeout: 10000 });
});

test("authenticated user can upload and delete a private document", async ({ page }) => {
  test.skip(process.env.RUN_MUTATING_E2E !== "1", "Set RUN_MUTATING_E2E=1 only for a dedicated test organization.");
  await signIn(page);
  await page.goto(baseURL + "/dashboard/document-management.html");
  await expect(page.getByRole("heading", { name: "Documents" })).toBeVisible();
  const title = "OfficeFlow E2E document " + Date.now();
  await page.getByRole("button", { name: "+ Upload document" }).click();
  await page.locator("#docName").fill(title);
  await page.locator("#docFolder").selectOption("General");
  await page.locator("#docFile").setInputFiles({
    name: "officeflow-e2e.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("Temporary OfficeFlow private storage regression file.")
  });
  await page.getByRole("button", { name: "Upload securely" }).click();
  const doc = page.locator("article").filter({ hasText: title });
  await expect(doc).toBeVisible({ timeout: 15000 });
  page.once("dialog", dialog => dialog.accept());
  await doc.getByRole("button", { name: "Delete" }).click();
  await expect(doc).toHaveCount(0, { timeout: 10000 });
});
