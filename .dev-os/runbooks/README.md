# DevOS Operational Runbooks

Quick reference index. Accessible via `help runbooks`.

**Create or audit a runbook:** `runbook`

---

## Runbooks by Severity

### P1 — Service-Breaking

| Runbook | Trigger | Last Updated |
|---------|---------|-------------|
| [token-rotation.md](token-rotation.md) | Barrier JWT near expiry (< 14d), 401/403 on MCP tools | 2026-04-08 |
| [symlink-repair.md](symlink-repair.md) | `*` commands invisible, `~/.dev-os` broken symlink | — |

### P2 — Workflow-Breaking

| Runbook | Trigger | Last Updated |
|---------|---------|-------------|
| [mcp-sync-failure.md](mcp-sync-failure.md) | `mcp-sync.sh` exits non-zero, CLIs show wrong server count, Antigravity "serverURL" error | 2026-04-08 |
| [mcp-failure-recovery.md](mcp-failure-recovery.md) | MCP tool call fails, `mcp-ops` reports server issues | — |
| [autonomous-session-recovery.md](autonomous-session-recovery.md) | Autonomous session stalled, failed, or stuck in loop | — |
| [version-upgrade-rollback.md](version-upgrade-rollback.md) | Version upgrade needed or upgrade caused regressions | — |
| [pipeline-interruption-recovery.md](pipeline-interruption-recovery.md) | Pipeline interrupted mid-session (context exhausted, tool error) | — |
| [install-failure.md](install-failure.md) | `scripts/install.sh` exits with error, symlink not created, command count < 100 | 2026-04-08 |
| [hook-failure.md](hook-failure.md) | Discipline hooks not firing, legacy `flowstate` git hook error, hook exits non-zero | 2026-04-08 |
| [profile-corruption.md](profile-corruption.md) | Profile schema invalid, inheritance broken, command surface wrong or missing | 2026-04-08 |

### P3 — Degraded

| Runbook | Trigger | Last Updated |
|---------|---------|-------------|
| [design-verify-recovery.md](design-verify-recovery.md) | `design-verify` fails or FAIL score below threshold | — |
| [context-drift.md](context-drift.md) | Context ledger stale/wrong project, Memory MCP returning wrong context, DEVOS_CONTEXT_BUNDLE outdated | 2026-04-08 |

---

## Runbooks by Domain

| Domain | Runbooks |
|--------|---------|
| **MCP / Tools** | token-rotation, mcp-sync-failure, mcp-failure-recovery |
| **DevOS Framework** | symlink-repair, install-failure, version-upgrade-rollback, profile-corruption |
| **Hooks & Discipline** | hook-failure |
| **Autonomous Sessions** | autonomous-session-recovery, pipeline-interruption-recovery |
| **Context & Memory** | context-drift |
| **Design Pipeline** | design-verify-recovery |

---

## Also See

- `profiles/default/runbooks/docker-compose-postiz-env-update.md` — Postiz stack env update on Unraid
- `docs/runbooks/oauth-provider-setup.md` — OAuth provider configuration and dev/prod separation

---

## Gaps (open)

All identified runbook gaps are now closed. To add a new runbook: `runbook` → Mode 1: New.
