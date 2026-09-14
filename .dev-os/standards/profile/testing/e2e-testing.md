<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/e2e-testing.md and re-run profile-sync. -->
<!-- source: profile:webapp -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/webapp/standards/testing/e2e-testing.md and re-run profile-sync. -->
# E2E Testing Standards

Standards for end-to-end testing of web applications using Playwright.

## Stack

| Tool | Purpose |
|------|---------|
| **Playwright** | Browser automation and E2E testing |
| **@clerk/testing** | Clerk authentication bypass for tests |
| **Doppler** | Secrets injection for test environments |

## Directory Structure

```
project-root/
├── e2e/
│   ├── global.setup.ts              # Clerk setup (required)
│   ├── site-audit.spec.ts           # Unauthenticated tests
│   ├── site-audit-authenticated.spec.ts  # Authenticated tests
│   └── helpers.ts                   # Shared test utilities
├── scripts/
│   └── e2e-test.sh                  # Test runner (dev/ci/prod/debug modes)
├── playwright.config.ts             # Playwright configuration
└── test-results/                    # Artifacts (gitignored)
```

## Playwright Configuration

```typescript
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: [
    ["html", { open: "never", outputFolder: "test-results/report" }],
    ["json", { outputFile: "test-results/results.json" }],
    ["list"],
  ],

  use: {
    baseURL: process.env.BASE_URL || "http://localhost:3000",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    actionTimeout: 10000,
    navigationTimeout: 30000,
  },

  projects: [
    {
      name: "setup",
      testMatch: /global\.setup\.ts/,
    },
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
      dependencies: ["setup"],
    },
  ],

  outputDir: "test-results/artifacts",
});
```

## Global Setup (Clerk)

Required for `@clerk/testing` to work. Must be referenced as a Playwright project dependency.

```typescript
// e2e/global.setup.ts
import { clerkSetup } from "@clerk/testing/playwright";
import { test as setup } from "@playwright/test";

setup.describe.configure({ mode: "serial" });

setup("global setup", async () => {
  await clerkSetup();
});
```

## Test Patterns

### Unauthenticated Tests

Test public routes, redirects, API endpoints, and UI elements without logging in.

```typescript
import { expect, test } from "@playwright/test";

test.describe("Public Routes", () => {
  test("homepage loads", async ({ page }) => {
    const response = await page.goto("/");
    expect(response?.status()).toBe(200);
  });

  test("protected route redirects to login", async ({ page }) => {
    await page.goto("/dashboard");
    await page.waitForURL("**/login**");
    expect(page.url()).toContain("/login");
  });
});

test.describe("API Webhook Routes", () => {
  test("webhook is accessible (not blocked by auth)", async ({ request }) => {
    const response = await request.post("/api/webhook", {
      data: { test: true },
      headers: { "Content-Type": "application/json" },
    });
    // Should NOT be a 307 redirect to auth
    expect(response.status()).not.toBe(307);
  });
});
```

### Authenticated Tests

Use `@clerk/testing` to bypass Clerk UI and authenticate programmatically.

```typescript
import { clerk, setupClerkTestingToken } from "@clerk/testing/playwright";
import { expect, type Page, test } from "@playwright/test";

const TEST_EMAIL = process.env.CLERK_TEST_USER_EMAIL || "e2e-test@example.com";
const TEST_PASSWORD = process.env.CLERK_TEST_USER_PASSWORD || "test-password";

test.describe.serial("Authenticated Features", () => {
  let page: Page;

  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext();
    page = await context.newPage();

    // Bypass Clerk bot detection
    await setupClerkTestingToken({ page });

    // Navigate first (required before clerk.signIn)
    await page.goto("/");
    await page.waitForTimeout(5000);

    // Sign in programmatically (no UI interaction needed)
    await clerk.signIn({
      page,
      signInParams: {
        strategy: "password",
        identifier: TEST_EMAIL,
        password: TEST_PASSWORD,
      },
    });

    // Navigate to authenticated page
    await page.goto("/dashboard");
    await page.waitForTimeout(3000);
  });

  test.afterAll(async () => {
    await page.context().close();
  });

  test("dashboard loads for authenticated user", async () => {
    expect(page.url()).not.toContain("/login");
    await expect(page.locator("body")).toBeVisible();
  });
});
```

## Test Runner Script

Copy `scripts/templates/e2e-test.sh` from DevOS to your project's `scripts/` directory.

### Modes

| Mode | Command | Purpose |
|------|---------|---------|
| `dev` | `./scripts/e2e-test.sh dev` | Start local dev server, run tests |
| `ci` | `./scripts/e2e-test.sh ci` | Run against already-running server |
| `prod` | `./scripts/e2e-test.sh prod` | Run against production URL |
| `debug` | `./scripts/e2e-test.sh debug` | Headed browser for debugging |

### Package.json Scripts

```json
{
  "scripts": {
    "test:e2e": "./scripts/e2e-test.sh dev",
    "test:e2e:ci": "./scripts/e2e-test.sh ci",
    "test:e2e:prod": "./scripts/e2e-test.sh prod",
    "test:e2e:debug": "./scripts/e2e-test.sh debug",
    "test:e2e:ui": "playwright test --ui"
  }
}
```

### Production Mode

The `prod` mode requires `PROD_URL` or `BASE_URL` to be set:

```bash
# Via environment variable
PROD_URL=https://myapp.vercel.app bun run test:e2e:prod

# Via Doppler (if PROD_URL is in your prd config)
bun run test:e2e:prod
```

## Required Dependencies

```json
{
  "devDependencies": {
    "@clerk/testing": "^1.13.35",
    "@playwright/test": "^1.58.2"
  },
  "dependencies": {
    "playwright": "^1.58.2"
  }
}
```

After installing, run: `bunx playwright install chromium`

## Required Environment Variables

For authenticated tests, these must be available (via Doppler or `.env`):

| Variable | Required | Purpose |
|----------|----------|---------|
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Yes | Clerk frontend key |
| `CLERK_SECRET_KEY` | Yes | Clerk backend key (for `@clerk/testing`) |
| `CLERK_TEST_USER_EMAIL` | No | Test user email (has default) |
| `CLERK_TEST_USER_PASSWORD` | No | Test user password (has default) |
| `BASE_URL` | No | Override default `localhost:3000` |
| `PROD_URL` | For prod mode | Production URL to test against |

## Test User Setup

Create a dedicated test user in Clerk for E2E tests:

```bash
# Via Clerk Backend API
curl -X POST https://api.clerk.com/v1/users \
  -H "Authorization: Bearer $CLERK_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email_address": ["e2e-test@yourapp.dev"],
    "password": "your-secure-test-password",
    "first_name": "E2E",
    "last_name": "Test"
  }'
```

Store the credentials in Doppler under the `prd` config.

## Test Categories

Every webapp should have these E2E test categories:

### Unauthenticated (site-audit.spec.ts)
- [ ] Public routes load (homepage, login, privacy, terms)
- [ ] Protected routes redirect to login
- [ ] API webhook routes are accessible (not blocked by auth)
- [ ] CLI/API routes return proper status codes
- [ ] Navigation and UI elements render
- [ ] No console errors on public pages
- [ ] Performance (page load times)
- [ ] Meta tags and favicon

### Authenticated (site-audit-authenticated.spec.ts)
- [ ] Login succeeds and reaches authenticated page
- [ ] Core CRUD operations (create, read, update, delete)
- [ ] Form submissions work
- [ ] Settings pages and tabs are interactive
- [ ] Navigation between authenticated pages
- [ ] No console errors on authenticated pages
- [ ] Data persists after page reload
- [ ] Cleanup (delete test data after tests)

## Common Pitfalls

### Empty SelectItem value
Radix UI `<Select.Item>` requires non-empty `value` prop. Use a sentinel like `"none"` instead of `""`.

### BASE_URL not set for production tests
Tests default to `localhost:3000`. Always set `BASE_URL` or use the `prod` mode script.

### Clerk bot detection
`setupClerkTestingToken()` must be called before `clerk.signIn()`. The `global.setup.ts` with `clerkSetup()` must run first as a Playwright project dependency.

### Serial vs parallel tests
Authenticated tests sharing a single page/session must use `test.describe.serial()`. Unauthenticated tests can run in parallel.

### Wait times after navigation
Clerk auth state takes time to propagate. Add `waitForTimeout(3000-5000)` after `clerk.signIn()` and after navigating to authenticated pages.

## Doppler Integration for Tests

### Local Development

Use `doppler-test.sh` to inject secrets when running tests locally:

```bash
# E2E tests (uses preview config by default)
./scripts/doppler-test.sh --e2e bun run test:e2e

# Integration tests (uses dev config)
./scripts/doppler-test.sh --integration bun run test:integration

# Override config
./scripts/doppler-test.sh --config prd bun run test:e2e:prod

# Skip Doppler (use .env.test mocks)
./scripts/doppler-test.sh --no-doppler bun run test:e2e

# Preview what would run
./scripts/doppler-test.sh --dry-run --e2e bun run test:e2e
```

### Package.json Scripts

Add Doppler-aware test commands alongside existing ones:

```json
{
  "scripts": {
    "test": "vitest --run",
    "test:e2e": "./scripts/e2e-test.sh dev",
    "test:e2e:ci": "./scripts/e2e-test.sh ci",
    "test:e2e:doppler": "./scripts/doppler-test.sh --e2e bun run test:e2e",
    "test:integration": "vitest --run --config vitest.integration.config.ts",
    "test:integration:doppler": "./scripts/doppler-test.sh --integration bun run test:integration"
  }
}
```

### CI/CD

Create a Doppler service token for your project and add it as a GitHub Actions secret:

```bash
# Create service token (one-time setup)
doppler configs tokens create ci-token \
  --project my-project \
  --config preview \
  --max-age 0

# Add to GitHub repo secrets
gh secret set DOPPLER_TOKEN --body "dp.st.xxx..."
```

Then copy the e2e workflow template from DevOS to your project:
`profiles/webapp/workflows/ci/e2e-with-doppler.yml` → `.github/workflows/e2e.yml`

### Environment Strategy for Tests

| Test Type | Doppler Config | Why |
|-----------|---------------|-----|
| Unit tests | None (mocked) | Fast, no external deps |
| Integration tests | `dev` | Tests against local/dev services |
| E2E tests (local) | `preview` | Tests against staging services |
| E2E tests (CI) | `preview` | Same as local, via service token |
| E2E tests (prod) | `prd` | Smoke tests against production |

### Secrets Required for E2E

Store these in your Doppler `preview` config:

| Variable | Purpose | Used By |
|----------|---------|---------|
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | Clerk frontend key | `@clerk/testing` |
| `CLERK_SECRET_KEY` | Clerk backend key | `@clerk/testing` |
| `CLERK_TEST_USER_EMAIL` | E2E test user | Test login flow |
| `CLERK_TEST_USER_PASSWORD` | E2E test user | Test login flow |
| `CONVEX_DEPLOYMENT` | Convex backend URL | Convex client |
| `BASE_URL` | App URL for tests | Playwright config |
