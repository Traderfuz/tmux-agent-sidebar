<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/infrastructure/docker-compose-operations.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/infrastructure/docker-compose-operations.md and re-run profile-sync. -->
# Docker Compose Operations Standards

## Overview

Misconfigured Docker Compose operations are a silent source of production incidents: environment variables that appear to change but don't, containers that restart without picking up new configuration, and lifecycle commands that delete state when the intent was to pause. This standard governs how environment variable updates are applied, how containers are started/stopped/removed, and what confirmation is required before any destructive action. It applies to all self-hosted services in the Boxi Ops profile (Postiz, Temporal, reverse proxies, and any future Docker Compose stacks on Unraid).

## Scope

This standard covers Docker Compose environment variable management, container lifecycle command selection, and destructive-action confirmation gates. It does NOT cover Docker networking configuration, Dockerfile authoring, volume backup procedures, or Unraid array operations.

---

## Principles

1. **Environment truth lives in the compose file:** The `environment:` block in `docker-compose.yaml` is the canonical source for any key it declares. `.env` files are secondary defaults. If a key exists in both, the compose file wins unconditionally.

2. **State-changing commands require explicit reload:** Process restart (`docker restart`) and configuration reload (`--force-recreate`) are not equivalent. A process restart preserves the environment snapshot from the last `up`. Only `--force-recreate` re-evaluates the compose file.

3. **"Stop" and "down" are not synonyms:** `stop` halts processes; `down` destroys containers and networks. The word "shutdown", "stop", or "pause" from any stakeholder maps to `stop`, never `down`. Removal requires explicit confirmation with the exact command stated.

4. **Confirm before destroy:** Any command that removes a container, volume, or network is irreversible in under 30 seconds and can destroy customer data. A confirmation gate is not optional overhead — it is the last checkpoint before data loss.

---

## Rules

### R1 — Environment variable precedence

**R1.1** Before editing `.env`, check the compose file's `environment:` block. If the key is declared there (even as empty string), editing `.env` alone will have no effect. (`MUST`)

```yaml
# OFF-STANDARD: .env has the value, compose overrides it to empty
# .env
FACEBOOK_APP_ID=2364001710741694

# docker-compose.yaml
environment:
  FACEBOOK_APP_ID: ''    # ← This wins. .env change is silently ignored.

# ON-STANDARD: set the value in the compose environment block
environment:
  FACEBOOK_APP_ID: '2364001710741694'
```

**R1.2** When a secret is managed by Doppler, the compose file `environment:` block MUST either reference the Doppler-injected variable (`${FACEBOOK_APP_ID}`) or be absent from the block. A hardcoded empty string defeats Doppler injection. (`MUST`)

**R1.3** After any environment variable change, apply with `--force-recreate`. Do not use `docker restart`. (`MUST`)

```bash
# OFF-STANDARD — does NOT re-read compose file
docker restart postiz

# ON-STANDARD — re-evaluates compose environment block
docker-compose up -d --force-recreate postiz
```

### R2 — Container lifecycle command selection

Use the correct command for the intended operation:

| Intent | Command | Effect |
|--------|---------|--------|
| Pause a running service | `docker-compose stop <service>` | Process halted, container preserved |
| Resume a stopped service | `docker-compose start <service>` | Process restarted, same config |
| Apply env/config changes | `docker-compose up -d --force-recreate <service>` | Container recreated with new config |
| Apply changes to full stack | `docker-compose up -d --force-recreate` | All containers recreated |
| Remove containers + networks | `docker-compose down` | **DESTRUCTIVE** — requires confirmation |
| Remove + delete volumes | `docker-compose down -v` | **DESTRUCTIVE + DATA LOSS** — requires confirmation |

**R2.1** "Shutdown", "stop", "pause", "bring down" from any stakeholder → `docker-compose stop`. Never interpret ambiguous language as authorization for `down`. (`MUST`)

**R2.2** `docker-compose down` MUST be preceded by explicit user confirmation that states the command and its effect: "This will remove containers and networks. Confirm?" (`MUST`)

**R2.3** `docker-compose down -v` MUST be preceded by a separate confirmation that explicitly names which volumes will be deleted and confirms no customer data is present. (`MUST`)

### R3 — Dependency startup ordering

**R3.1** `depends_on: service_started` is not a health gate — it only waits for the process to start, not to be ready. For services with initialization time (PostgreSQL, Redis, Temporal), wait for a healthy state before starting dependents. (`SHOULD`)

```bash
# Pattern: wait for healthy, then start dependent
docker-compose up -d temporal-postgresql
docker-compose exec temporal-postgresql pg_isready -U temporal
# (only after pg_isready returns success)
docker-compose up -d temporal
```

**R3.2** If a Temporal container exits with code 1 on startup, the root cause is almost always that `temporal-postgresql` was not fully accepting connections. Fix: `docker restart temporal` after verifying postgres is healthy — do not recreate the entire stack. (`SHOULD`)

### R4 — Verification after changes

**R4.1** After any environment variable update, verify the running container has the correct value before declaring the change complete. (`MUST`)

```bash
# Verify env var is live in the running container
docker exec <container_name> env | grep FACEBOOK_APP_ID
# Must return: FACEBOOK_APP_ID=2364001710741694
```

**R4.2** After a force-recreate, check `docker-compose ps` to confirm all services are in `running` state and no containers have exited unexpectedly. (`MUST`)

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Editing `.env` without checking compose `environment:` block | Compose block silently wins; change has no effect | Check compose file first, edit the compose block if key is declared there |
| `docker restart <container>` to apply env changes | Restarts process with same config snapshot; new env not loaded | `docker-compose up -d --force-recreate <service>` |
| Running `docker-compose down` when user says "stop" | Removes containers and networks; data risk | `docker-compose stop` unless destruction is explicitly confirmed |
| Starting Temporal immediately after starting temporal-postgresql | Race condition — postgres may not be ready yet | Wait for `pg_isready` before starting Temporal |
| Declaring `service_started` health gate in compose and assuming it means "ready" | `service_started` only means the process spawned, not that it accepts connections | Use `healthcheck:` + `condition: service_healthy` in depends_on |
| Hardcoding empty strings in compose `environment:` for secrets managed by Doppler | `''` overrides Doppler-injected value; secret never loads | Use `${VAR_NAME}` reference or omit the key from the environment block |

---

## Deviation guidance

**MAY** run `docker-compose down` without prior confirmation when all of the following are true: (1) the environment is a local dev machine, (2) all data is ephemeral or easily regenerated, and (3) the operation is part of a scripted reset sequence explicitly reviewed by the engineer. MUST NOT apply this exception to Unraid production stacks.

**MAY** use `docker restart` for a quick process restart when only a transient failure occurred (e.g., network blip) and no configuration has changed. MUST NOT use it after any environment variable or compose file edit.

---

## Compliance test

- [ ] Before editing `.env`, did you check the compose `environment:` block for conflicting declarations?
- [ ] After any environment variable change, did you use `docker-compose up -d --force-recreate` (not `docker restart`)?
- [ ] Did you verify the live value with `docker exec <container> env | grep VAR_NAME` before claiming the change took effect?
- [ ] If the user said "stop" or "shutdown", did you use `docker-compose stop` (not `down`)?
- [ ] Before running `docker-compose down`, did you confirm explicitly with the user, naming the command and its effect?

If any check fails: stop, revert the incomplete action if possible, and run the correct procedure from the runbook before continuing.

---

## References

- [Docker Compose reference — environment variables](https://docs.docker.com/compose/environment-variables/set-environment-variables/) — precedence rules: environment block > env_file > shell env
- [Docker Compose `depends_on` conditions](https://docs.docker.com/compose/compose-file/05-services/#depends_on) — `service_started` vs `service_healthy`
- Procedural memory: `docker-compose-env-var-update` — 5-step env change recipe (Memory MCP)
- Procedural memory: `destructive-infrastructure-confirm-gate` — confirm-before-destroy gate (Memory MCP)
- Runbook: `docker-compose-postiz-env-update.md` — step-by-step procedure for Postiz stack env changes
