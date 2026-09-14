<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/test-writing.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/testing/test-writing.md and re-run profile-sync. -->
# Test Writing Standards

## Overview

Tests are a verification tool, not a parallel implementation track. Writing tests before a feature's
boundary is understood often leads to tests that couple to intermediate implementation decisions
rather than final behavior, producing brittle suites that require rewriting when the design settles.
Test-at-completion — writing strategic tests once the feature is fully working — produces coverage
signals that reflect the real contract of the code, not the contract of a draft.

## Scope

This standard covers unit test structure, naming conventions, mocking discipline, coverage
philosophy, and test execution speed.

It does NOT cover:
- End-to-end testing (see `e2e.md`)
- CI/CD test pipeline configuration
- Load testing, performance testing, or stress testing
- Integration test topology (service-level boundary testing)

## Principles

1. **Behavior over implementation:** Tests describe what the unit does from the outside, not which
   internal methods it calls or which branch it takes. A test that breaks on refactoring without a
   behavior change is a failing test by design.

2. **Minimal and strategic:** Do not test every line. Test every contract. A contract is a
   promise the function makes to its caller: given these inputs, produce this output or side effect.
   Edge cases and error states are only tested when they are business-critical.

3. **Fast feedback loop:** Unit tests must run in milliseconds. A suite that takes seconds to run
   is a suite developers stop running. Speed is not a nice-to-have; it is a prerequisite for tests
   to provide value during active development.

## Rules

### Rule 1: Feature-first, test-at-completion

Complete the feature implementation before writing tests. This is the "test last" discipline,
which is valid and intentional when the feature boundary is clear.

Writing tests during intermediate implementation steps binds tests to decisions that will change.
Once the feature works end-to-end, the contract is known — write tests against that contract.

**Exception:** If you are adding a function whose interface is fully specified in advance (e.g.,
parsing a known wire format), test-first is appropriate. The trigger is "do I know the full
interface?" — not "is TDD fashionable?"

---

### Rule 2: Test names describe behavior

Test names are the first documentation a future developer reads. They must encode the scenario and
the expected result, not the method under test.

**OFF-STANDARD**

```typescript
// Vague — tells you nothing about scenario or expectation
it("getUserById test", async () => {
  const result = await getUserById("abc");
  expect(result).toBeDefined();
});

// Implementation-centric — breaks on any internal rename
it("calls db.findOne with correct id", async () => {
  await getUserById("abc");
  expect(mockDb.findOne).toHaveBeenCalledWith({ id: "abc" });
});
```

**ON-STANDARD**

```typescript
// Behavior-first: scenario + expected outcome
it("returns null when user is not found", async () => {
  mockDb.findOne.mockResolvedValue(null);
  const result = await getUserById("nonexistent-id");
  expect(result).toBeNull();
});

it("returns the user object when a matching id exists", async () => {
  const user = { id: "abc", name: "Alice" };
  mockDb.findOne.mockResolvedValue(user);
  const result = await getUserById("abc");
  expect(result).toEqual(user);
});
```

Pattern: `it("[verb] [outcome] when [condition]")` — readable as a plain English sentence.

---

### Rule 3: Mock external dependencies

Unit tests must not touch real databases, real APIs, real file systems, or real clocks. External
calls make tests slow, order-dependent, and environment-sensitive. Always inject or intercept
the dependency boundary.

**OFF-STANDARD**

```typescript
// Hits a real database — slow, flaky, requires seed state
it("saves the user", async () => {
  const user = await createUser({ name: "Bob" });
  const found = await db.query("SELECT * FROM users WHERE id = $1", [user.id]);
  expect(found.rows[0].name).toBe("Bob");
});
```

**ON-STANDARD**

```typescript
import { vi, describe, it, expect, beforeEach } from "vitest";
import { createUser } from "../user-service";
import { db } from "../db";

vi.mock("../db");

describe("createUser", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("inserts a user record and returns the created user", async () => {
    const mockUser = { id: "uuid-1", name: "Bob" };
    vi.mocked(db.insert).mockResolvedValue(mockUser);

    const result = await createUser({ name: "Bob" });

    expect(db.insert).toHaveBeenCalledWith(
      expect.objectContaining({ name: "Bob" })
    );
    expect(result).toEqual(mockUser);
  });
});
```

Boundaries to always mock: database clients, HTTP clients, file system (`fs`), `Date`, `Math.random`,
and any external SDK (Stripe, Twilio, SendGrid, etc.).

---

### Rule 4: One assertion per logical outcome

A test verifies one logical outcome. This does not mean one `expect()` call — it means one
scenario with one verdict. Multiple `expect()` calls are fine if they all verify facets of the
same outcome. Separate tests for separate behaviors.

**OFF-STANDARD**

```typescript
// Two unrelated behaviors in one test — failure message is ambiguous
it("processes the order", async () => {
  const order = await processOrder({ items: ["a"] });
  expect(order.status).toBe("confirmed");      // behavior 1
  expect(mailer.send).toHaveBeenCalledTimes(1); // behavior 2 — unrelated
  expect(inventory.decrement).toHaveBeenCalled(); // behavior 3 — unrelated
});
```

**ON-STANDARD**

```typescript
it("sets order status to confirmed on success", async () => {
  const order = await processOrder({ items: ["a"] });
  expect(order.status).toBe("confirmed");
});

it("sends a confirmation email when order is processed", async () => {
  await processOrder({ items: ["a"] });
  expect(mailer.send).toHaveBeenCalledTimes(1);
});

it("decrements inventory for each ordered item", async () => {
  await processOrder({ items: ["a"] });
  expect(inventory.decrement).toHaveBeenCalledWith("a", 1);
});
```

---

### Rule 5: Fast tests — no sleeps, no network, no disk I/O

Unit tests run in milliseconds. Any test that takes more than 50ms is not a unit test; it is an
integration test and belongs in a separate suite.

**Prohibited in unit tests:**

```typescript
// No timers
await new Promise((r) => setTimeout(r, 1000));

// No real network
const res = await fetch("https://api.example.com/data");

// No real file system writes
fs.writeFileSync("/tmp/test-output.json", JSON.stringify(data));
```

**Correct alternatives:**

```typescript
// Mock timers
vi.useFakeTimers();
vi.advanceTimersByTime(1000);

// Mock fetch
vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ json: async () => ({}) }));

// Mock fs
vi.mock("fs");
vi.mocked(fs.writeFileSync).mockImplementation(() => {});
```

If a test legitimately needs the network or disk, label it as an integration test and run it in
a separate `vitest` workspace or with a separate `npm run test:integration` script.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Testing internal method calls (`expect(spy).toHaveBeenCalled()` on private helpers) | Couples test to implementation; breaks on every refactor even when behavior is unchanged | Test the public output or side effect, not the internal call path |
| No mocks on external dependencies (real DB, real HTTP) | Tests are slow, order-dependent, and fail in CI without live services | Mock at the dependency boundary using `vi.mock()` or dependency injection |
| Vague test names (`it("works")`, `it("test 1")`) | Failure message provides no diagnostic information; developer must read the test body to understand what broke | Use `it("[verb] [outcome] when [condition]")` pattern |
| One monolithic test per function covering all branches | A single failure masks which branch failed; test output is not actionable | One test per scenario; split branches into separate `it()` blocks |
| Writing tests during active feature churn | Tests bind to intermediate decisions, require constant rewriting, and add noise rather than signal | Complete the feature first; write tests once the contract is stable |
| `expect(result).toBeDefined()` as the only assertion | Passes for any non-undefined value including error objects; catches nothing meaningful | Assert the specific value, shape, or type expected |
| Shared mutable state between tests (module-level `let` without reset) | Tests pass or fail depending on execution order; intermittent failures in CI | Use `beforeEach` to reset mocks and state; prefer local `const` inside each `it()` |

## Test Deletion Lifecycle

Tests must be removed when they are no longer valid. Keeping dead tests adds maintenance burden
and hides real failures by adding noise to the suite.

### When to delete a test

| Signal | Classification | Action |
|--------|---------------|--------|
| The behavior being tested no longer exists (feature removed, function deleted) | **Orphan** | Delete immediately |
| Test file is older than its library; library's function signature changed in a backwards-incompatible way | **Stale** | Update to match current contract, or delete if behavior is gone |
| Test is testing an internal implementation path that was refactored away, but behavior is unchanged | **Stale (coupling)** | Delete; the behavior is covered by other tests |
| Test was written for a bug that was intentionally reverted or accepted as by-design | **Regression (voided)** | Delete with a comment in the commit message |

### Deletion process

1. **Classify** before deleting — use the table above.
2. **Search for dependents** — verify no other test or fixture imports the test helper being removed.
3. **Delete the test** — do not comment it out.
4. **Commit message format:**
   ```
   test(<suite>): remove orphan test for <function/behavior>
   
   Deleted because: <one sentence — what changed and why this test is no longer valid>
   ```
5. **Capture in learnings** — if the deletion reveals a test-writing process gap (e.g., tests were written for a behavior that should have been kept), log it via `learnings`.

### What not to do

- Do NOT comment out failing tests to make the suite green — classify and fix or delete.
- Do NOT add `skip()` or `@test.skip` without a `TODO: re-enable when X` comment and a linked issue.
- Do NOT silently delete tests that are failing because of a regression (that is not an orphan — fix the implementation).

## Deviation guidance

**MAY write tests before implementation when:**
- The function's full interface is specified in advance and will not change during implementation
  (e.g., implementing a parser for a fixed wire format, satisfying an explicit API contract)
- A regression test is needed to document a confirmed bug before applying the fix

**MUST NOT skip mocking when:**
- The code under test makes any network call, even to localhost
- The code under test reads or writes to the file system
- The code under test queries any database, cache, or message queue
- The code under test calls `Date.now()`, `Math.random()`, or any non-deterministic primitive

**MAY use one `expect()` call per test when:**
- The outcome is a single scalar value with no related side effects to verify

**MUST NOT combine unrelated behaviors** in a single `it()` block regardless of how short each
assertion is.

## Compliance test

- [ ] All test names follow the `[verb] [outcome] when [condition]` pattern and read as plain English sentences
- [ ] No test in the unit suite touches a real database, real HTTP endpoint, real file system, or real clock
- [ ] Each `it()` block verifies one logical outcome (multiple `expect()` calls are acceptable if they describe the same outcome)
- [ ] The full unit test suite completes in under 5 seconds on developer hardware
- [ ] Tests were written after the feature was functionally complete, or a documented deviation reason is present in the test file header

## References

- [Growing Object-Oriented Software, Guided by Tests](https://www.goodreads.com/book/show/4268826-growing-object-oriented-software-guided-by-tests) (Freeman / Pryce) — the authoritative source for behavior-based testing and the distinction between unit tests that test contracts vs. tests that test implementations. The "Don't Mock Value Objects" and "Only Mock Types You Own" rules originate here.
- [Kent Beck — Test Isolation](https://tidyfirst.substack.com/) — the principle that each test must be able to run independently and in any order; shared state between tests is a design smell, not a test smell.
- [Vitest documentation](https://vitest.dev/guide/) — the test runner used in all TypeScript/JavaScript projects in this framework; `vi.mock()`, `vi.stubGlobal()`, and fake timers are the canonical mocking primitives.
- `e2e.md` — companion standard covering end-to-end test structure, Playwright conventions, and when to promote a unit test scenario to an E2E test.
