# Product Context Check

Before any spec work begins, verify that product context files have been filled in.

## When to Use

Use this shared check inside spec-writing or planning workflows before drafting product requirements.

Do not use this as a standalone gate for projects without a `product/` directory, CI jobs, or non-interactive automation.

## Process

1. Check whether this project should skip product-context validation.
2. Inspect `product/mission.md` and `product/roadmap.md` for missing or stub content.
3. Warn and prompt before continuing when either context file is missing or stubbed.

**Skip this check entirely if any of the following are true:**
- `product/` directory does not exist in the project root
- `$CI` environment variable is set
- stdin is not an interactive terminal

**Check:** Read `product/mission.md` and `product/roadmap.md`. A file is a stub if it is
missing or has fewer than 5 non-empty lines (the `product_is_stub()` definition).

**If either file is a stub or missing**, display this warning and prompt:

```
WARNING: product/mission.md appears to be empty or a placeholder.
WARNING: product/roadmap.md appears to be empty or a placeholder.

These files help align specs with your product goals.
Run plan-product to fill them in, or continue anyway.

Continue without product context? (Y/n)
```

Default on Enter: **Y** (proceed). This is a warning, not a gate.
If the user types "n": stop and display `Run plan-product to define your product context first.`

## Output Format

When context is missing or stubbed, display the warning block and prompt shown above. When context is present or the check is skipped, continue silently.
