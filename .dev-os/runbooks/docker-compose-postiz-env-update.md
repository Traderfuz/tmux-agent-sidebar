# Runbook: Postiz Stack — Apply Environment Variable Changes

**Trigger:** Any change to OAuth credentials, API keys, or service configuration for the Postiz self-hosted stack on Unraid (tower).

**Severity:** Low (configuration change) / Medium (service disruption if steps followed incorrectly)

**Estimated time:** 5–10 minutes

**Last validated:** 2026-04-06

---

## Metadata

| Field | Value |
|---|---|
| Service | Postiz + Temporal stack |
| Host | `root@tower` (Unraid) |
| Compose file | `/mnt/user/appdata/postiz/docker-compose.yaml` |
| Env file | `/mnt/user/appdata/postiz/.env` |
| Doppler project | `boxi-postiz` / config: `prd` |
| Containers affected | `postiz`, `temporal`, `temporal-admin-tools`, `temporal-ui` |
| Containers NOT affected | `postiz-postgres`, `postiz-redis`, `temporal-postgresql` (stateful — do not recreate unless explicitly required) |

---

## Prerequisites

- SSH access to `root@tower`
- Doppler CLI authenticated (`doppler whoami` returns the correct account)
- New secret values confirmed correct (App ID, App Secret, etc.)
- No active user sessions posting/scheduling content (check Postiz dashboard briefly)

---

## Triage: Is a force-recreate actually needed?

Answer these questions before running anything:

| Question | Yes | No |
|---|---|---|
| Is the key declared in the compose `environment:` block (even as empty string)? | Must edit compose file AND force-recreate | Can edit .env only — but force-recreate still recommended |
| Did you already run `docker restart` and the value still isn't live? | Compose block is overriding — go to Step 3 | — |
| Is this a Doppler-managed secret (`${VAR_NAME}` syntax in compose)? | Inject via Doppler run prefix — see Step 2b | Set value directly in compose |

---

## Step 1 — SSH to tower

```bash
ssh root@tower
```

Expected output: shell prompt `root@Tower:~#`

---

## Step 2 — Set the secret in Doppler

```bash
doppler secrets set FACEBOOK_APP_ID="<value>" FACEBOOK_APP_SECRET="<value>" \
  --project boxi-postiz --config prd
```

Expected output:
```
┌────────────────────┬───────────────────────────┐
│ NAME               │ VALUE                     │
├────────────────────┼───────────────────────────┤
│ FACEBOOK_APP_ID    │ <value>                   │
│ FACEBOOK_APP_SECRET│ <value>                   │
└────────────────────┴───────────────────────────┘
```

If Doppler project doesn't exist:
```bash
doppler projects create boxi-postiz
# Then re-run the secrets set command above
```

---

## Step 3 — Check and edit the compose file

```bash
cd /mnt/user/appdata/postiz
grep -n "FACEBOOK_APP" docker-compose.yaml
```

**If the key is hardcoded (not using `${VAR}` syntax):**

```bash
# Edit directly — replace empty or stale value
sed -i "s/FACEBOOK_APP_ID: '.*'/FACEBOOK_APP_ID: '<value>'/" docker-compose.yaml
sed -i "s/FACEBOOK_APP_SECRET: '.*'/FACEBOOK_APP_SECRET: '<value>'/" docker-compose.yaml
```

Verify the change took:
```bash
grep -n "FACEBOOK_APP" docker-compose.yaml
```

Expected: lines show the new values, not empty strings.

**If using `${VAR}` Doppler reference syntax:** No compose edit needed — Doppler injection handles it. Skip to Step 4.

---

## Step 4 — Apply changes with force-recreate

**ONLY recreate the app containers — NOT the stateful DB/Redis containers.**

```bash
cd /mnt/user/appdata/postiz
docker-compose up -d --force-recreate postiz
```

Expected output:
```
Recreating postiz ... done
```

Do NOT run `docker-compose up -d --force-recreate` (without service name) unless you intentionally want all containers recreated including Temporal.

---

## Step 5 — Verify the env var is live

```bash
docker exec postiz env | grep FACEBOOK_APP_ID
```

Expected: `FACEBOOK_APP_ID=2364001710741694` (or your new value)

If output is empty or shows old value → the compose `environment:` block still has a conflicting declaration. Return to Step 3.

---

## Step 6 — Health check all services

```bash
docker-compose ps
```

Expected: all containers show `Up` status. If any show `Exit`:

| Container | Common cause | Fix |
|---|---|---|
| `temporal` | temporal-postgresql not ready when temporal started | `docker restart temporal` (after confirming postgres is healthy) |
| `postiz` | Bad env var value (e.g. invalid App ID format) | Check logs: `docker logs postiz --tail 50` |
| `temporal-admin-tools` | One-shot init container — normal to show Exited 0 | No action needed |

Check temporal-postgresql health before restarting temporal:
```bash
docker exec temporal-postgresql pg_isready -U temporal
# Must return: /var/run/postgresql:5432 - accepting connections
docker restart temporal
```

---

## Step 7 — Functional verification

1. Open `https://postiz.boximarketing.com` in browser
2. Navigate to Settings → Channels
3. Attempt to add a Facebook channel — should redirect to Facebook OAuth (not "Invalid App ID" error)
4. If OAuth completes → change confirmed working end-to-end

---

## Rollback

If the new values break functionality and you need to revert:

```bash
# Restore previous Doppler values
doppler secrets set FACEBOOK_APP_ID="<old_value>" FACEBOOK_APP_SECRET="<old_value>" \
  --project boxi-postiz --config prd

# Restore compose file value
sed -i "s/FACEBOOK_APP_ID: '.*'/FACEBOOK_APP_ID: '<old_value>'/" /mnt/user/appdata/postiz/docker-compose.yaml

# Force-recreate to apply rollback
cd /mnt/user/appdata/postiz
docker-compose up -d --force-recreate postiz

# Verify
docker exec postiz env | grep FACEBOOK_APP_ID
```

---

## ⚠️ Confirmation gate — destructive operations

**Before running `docker-compose down` for any reason:**

1. State explicitly: "This will REMOVE containers and networks. Volumes are preserved unless `-v` is also passed."
2. Confirm the user understands and approves — do not proceed on ambiguous language ("shutdown", "stop", "bring it down").
3. If volumes would be affected (`-v` flag), additionally confirm no customer data is present.

`docker-compose stop` is always the safe alternative when the intent is to pause.

---

## Escalation

| Condition | Action |
|---|---|
| Temporal exits repeatedly after postgres health confirmed | Check temporal logs: `docker logs temporal --tail 100`; check temporal-postgresql disk space |
| Postiz auth broken after correct env applied | Check Facebook App is in Development mode and your account is a test user |
| postgres or redis containers won't start | Check Unraid array status and disk health before touching compose |
| Environment variable confirmed correct but OAuth still fails | Clear browser cache; check Facebook App redirect URI matches exactly (including trailing slash) |

---

## Validation criteria

This runbook is complete when:

- [ ] `docker exec postiz env | grep <VAR_NAME>` returns the expected new value
- [ ] `docker-compose ps` shows all expected containers as `Up`
- [ ] Functional OAuth flow completes without "Invalid App ID" or equivalent error
- [ ] Doppler secret matches the compose file value (no drift)
