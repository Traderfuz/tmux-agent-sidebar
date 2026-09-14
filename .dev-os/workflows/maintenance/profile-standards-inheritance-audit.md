# Profile Standards Inheritance Audit Workflow

## When to Use

Run this workflow before merging any branch that modifies `profiles/*/standards/` files, or during a periodic maintenance session to detect inheritance drift.

Do not run this workflow in response to unrelated code changes — it is scoped to `profiles/*/standards/` only and will produce noise if run on unrelated diffs.

## Purpose

Detect profile-standards drift in the inheritance tree before duplicate child files and stale forks accumulate again.

## Scope

This workflow audits `profiles/*/standards/**` against each profile's inheritance chain. It does not rewrite or delete files; it reports inheritance defects so the owning profile can normalize them.

## Behavior

1. Enumerate child profiles and resolve each inheritance chain from `profile-config.yml`
2. Compare child standards against the first inherited parent file at the same relative path
3. Flag exact duplicate child copies of inherited standards
4. Flag markdown child extensions that shadow parent standards without an `Extends:` link
5. Emit a markdown report suitable for maintenance review or parity gating

## Report Output

`product/runtime/reports/profile-standards-inheritance-audit-latest.md`

## Severity Model

| Severity | Condition |
|----------|-----------|
| High | Child standard exactly duplicates inherited parent file |
| Medium | Child standard shadows a parent file without an explicit extension contract |

## Integration

- Supports the maintenance standard `profiles/general/standards/maintenance/profile-standards-inheritance.md`
- Can be run ad hoc as `profile-standards-inheritance-audit`
- Can be enforced through `scripts/lib/command-surface-parity.sh` to stop duplicate standards from re-entering the tree

## Display Format

```
Profile Standards Inheritance Audit
  Profiles scanned: [N]
  Standards checked: [N]
  DUPLICATE (no delta): [N files] ← should be deleted
  MISSING Extends link: [N files] ← should be fixed
  PASS:  [N files]
```
