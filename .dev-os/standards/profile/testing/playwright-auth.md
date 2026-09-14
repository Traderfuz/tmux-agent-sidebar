<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/playwright-auth.md and re-run profile-sync. -->
# Playwright Authenticated Session Setup

## Overview

Canonical three-layer pattern for Playwright auth session management. Each layer trades speed for flexibility. Pick the lightest layer that covers your auth surface.

## Layer 1 — auth.setup.ts + Project Dependencies

The official Playwright approach. A setup project logs in via UI, persists storage state, and browser projects depend on it.

**auth.setup.ts:**

```ts
import { test as setup, expect } from '@playwright/test';
import fs from 'node:fs';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  // Skip re-auth if state is fresh (< 30 min)
  if (fs.existsSync(authFile)) {
    const age = Date.now() - fs.statSync(authFile).mtimeMs;
    if (age < 30 * 60 * 1000) return;
  }

  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill(process.env.TEST_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('**/dashboard');

  await page.context().storageState({ path: authFile });
});
```

**playwright.config.ts:**

```ts
export default defineConfig({
  projects: [
    { name: 'setup', testMatch: /.*\.setup\.ts/ },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },
  ],
});
```

## Layer 2 — API Login

Use when the backend exposes a direct login endpoint. 5-10x faster than UI login.

```ts
import { test as setup } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate via API', async ({ request }) => {
  await request.post('/api/auth/login', {
    data: {
      email: 'user@example.com',
      password: process.env.TEST_PASSWORD!,
    },
  });

  await request.storageState({ path: authFile });
});
```

Config stays identical to Layer 1. The setup project just runs faster.

## Layer 3 — playwright-cli Agent Sessions

For AI agent browser work. Saves state after manual or scripted login, restores it in subsequent sessions. Skips OAuth flows entirely.

```bash
# After logging in manually
playwright-cli state-save .playwright-cli/auth-state.json

# At next session start
playwright-cli state-load .playwright-cli/auth-state.json
```

Agent skills that need auth SHOULD load state before navigation and re-save after any session refresh.

## CDP Escalation

Follow `global/browser-review-policy.md`: storage state is the normal auth path. Escalate to `browser-cdp` only when the target requires CAPTCHA/2FA/OAuth co-work, browser extensions, a real existing profile, or a saved Playwright state is missing/expired and cannot be refreshed automatically. Log the escalation reason in the review report.

## Multiple Roles

Save separate state files per role from a single setup:

```ts
import { test as setup } from '@playwright/test';

setup('admin auth', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(process.env.ADMIN_EMAIL!);
  await page.getByLabel('Password').fill(process.env.ADMIN_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('**/dashboard');
  await page.context().storageState({ path: 'playwright/.auth/admin.json' });
});

setup('user auth', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(process.env.USER_EMAIL!);
  await page.getByLabel('Password').fill(process.env.USER_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('**/dashboard');
  await page.context().storageState({ path: 'playwright/.auth/user.json' });
});
```

**Per-test role override:**

```ts
test.use({ storageState: 'playwright/.auth/admin.json' });

test('admin can delete users', async ({ page }) => {
  await page.goto('/admin/users');
  // ...
});
```

**Multi-role within a single test** via POM fixtures:

```ts
test('admin invites user who accepts', async ({ browser }) => {
  const adminCtx = await browser.newContext({
    storageState: 'playwright/.auth/admin.json',
  });
  const userCtx = await browser.newContext({
    storageState: 'playwright/.auth/user.json',
  });
  const adminPage = await adminCtx.newPage();
  const userPage = await userCtx.newPage();
  // ...
});
```

## Gotchas

- **`storageState` does NOT capture `sessionStorage`.** `sessionStorage` is tab-scoped and cleared on page load. If your app stores auth tokens there, restore manually:

  ```ts
  await page.evaluate((token) => {
    sessionStorage.setItem('auth_token', token);
  }, process.env.SESSION_TOKEN);
  ```

- **UI mode skips setup projects.** In `--ui` mode the setup project does not auto-run. Re-run `auth.setup.ts` manually when state expires.
- **Auth JSON files contain tokens.** Add `playwright/.auth/` and `.playwright-cli/` to `.gitignore`. Never commit state files.
- **Setup failure skips dependents.** If the setup project fails, all dependent browser projects are skipped (not failed). This is correct Playwright behavior. Treat setup failure as a hard blocker — fix auth before running tests.

## Related Standards

- `e2e-testing-standards.md` for behavior-based E2E expectations
- `browser-review-policy.md` for driver/target/auth/backend routing
- `agent-browser.md` for `agent-browser` verification rules
- `verification-scope.md` for when browser verification is required

## Compliance Test

- [ ] Auth state is persisted to a file via `storageState`, not re-logged per test
- [ ] Auth state files are listed in `.gitignore`
- [ ] Session expiry guard prevents stale auth (mtime check or equivalent)
- [ ] Setup project failure blocks dependent test execution
- [ ] `sessionStorage` auth tokens are restored manually if the app uses them
- [ ] Multiple roles use separate state files, not shared credentials
- [ ] Credentials are sourced from environment variables, not hardcoded
- [ ] CDP escalation is used only for hard-auth cases and records the reason
