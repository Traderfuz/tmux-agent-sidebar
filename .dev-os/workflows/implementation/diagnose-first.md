# Diagnose-First Workflow

Automatically runs a 4-step root cause diagnostic on any task failure, applies the fix, and continues. No user prompt at any point.

## When to Use

Invoked automatically inside the implementation loop whenever a task fails (build error, test failure, or runtime error). Runs before any retry.

## Process

### Step 1: Check Mechanism

Determine what is actually executing — not what you assume is executing.

- Read the actual config file, script, or code path being invoked
- Verify tool version: run `<tool> --version` or equivalent
- Verify path: run `which <tool>` or `type <tool>`
- Verify environment: check relevant env vars with `env | grep <KEY>`

Display:
```
  [Step 1] Checking mechanism... → [one-line finding]
```

Example findings:
- `→ node v18.2.0 at /usr/local/bin/node (expected v20+)`
- `→ bun script references missing env var CONVEX_URL`
- `→ test runner invoking vitest but package.json specifies jest`

### Step 2: Check Layers

List every layer between the input and the failure output. Check each layer independently.

Layers to check (adapt to the stack):
```
Input → Config → Runtime → Build → Test → Output
```

For each layer: is it producing the expected intermediate output?

Identify which specific layer is producing the unexpected result.

Display:
```
  [Step 2] Checking layers...    → [which layer fails and why]
```

Example findings:
- `→ Config layer: wrangler.toml missing compatibility_date`
- `→ Runtime layer: process exits with code 1 before test runner starts`
- `→ Build layer: TypeScript emits to wrong outDir`

### Step 3: Audit Live State

Run diagnostic commands to compare actual state against expected state.

Commands to run as appropriate:
- `which <tool>`, `type <tool>` — confirm binary location
- `<tool> --version` — confirm version
- `env | grep <RELEVANT_KEY>` — confirm env vars
- `ls -la <path>` — confirm file existence and permissions
- `cat <config-file>` — confirm config contents

Record specific discrepancies between actual and expected.

Display:
```
  [Step 3] Auditing live state...→ [specific discrepancy found]
```

Example findings:
- `→ NEXT_PUBLIC_CONVEX_URL is unset in current environment`
- `→ dist/ directory does not exist (build never ran)`
- `→ node_modules/.bin/vitest missing (install needed)`

### Step 4: Isolate Variables

Change exactly one thing, test, and observe. Do not combine multiple fixes.

- Pick the most likely root cause from steps 1–3
- Make the minimal change to address it
- State what the change is and what it is expected to reveal

Display:
```
  [Step 4] Isolating variable...  → [what is being changed and why]
```

Example findings:
- `→ Adding missing NEXT_PUBLIC_CONVEX_URL to test env and retrying`
- `→ Running bun install to restore missing binary`
- `→ Correcting outDir in tsconfig.json from dist/ to .next/`

### Step 5: Record and Apply

After completing all 4 steps:

1. Output a one-line diagnosis:
   ```
   Diagnosis: [root cause in plain language]
   ```

2. Record findings in the task's implementation notes (append to the current task section in the session):
   ```
   [Diagnose-First — attempt N]
   Mechanism: [step 1 finding]
   Layer: [step 2 finding]
   Live state: [step 3 finding]
   Variable: [step 4 finding]
   Root cause: [diagnosis]
   Fix applied: [what changed]
   ```

3. Apply the fix.

4. Output:
   ```
   Applying fix: [what is changing]
   Retrying...
   ```

5. Retry the failed task. If it fails again:
   - **Attempt 2:** run the full 4-step process again with iteration number incremented.
   - **Attempt 3+:** stop. Do not make another fix attempt. Escalate to `systematic-debugging` and complete Phase 1 (read full failure output, confirm reproduction, check recent git changes, write one falsifiable hypothesis) before touching any code. Resume fix attempts only after Phase 1 is complete.

## Display Format (complete example)

```
Task failed — running diagnose-first...
  [Step 1] Checking mechanism...  → bun script references CONVEX_URL but var is unset
  [Step 2] Checking layers...     → config layer passes; runtime layer exits code 1 at env check
  [Step 3] Auditing live state... → CONVEX_URL unset in environment; .env.local missing
  [Step 4] Isolating variable...  → creating .env.local from .env.example and retrying
Diagnosis: missing .env.local causes runtime exit before test execution
Applying fix: copy .env.example → .env.local
Retrying...
```
