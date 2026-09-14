<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/deployment/cli-distribution.md and re-run profile-sync. -->
# CLI Profile — Distribution Standards

## Overview

A CLI tool is only useful if it reaches users. This standard defines the approved distribution patterns for CLI-profile projects: npm/bun publish, standalone binaries, Homebrew, Docker, and versioning conventions. It does not cover CI/CD pipeline authoring (see global deployment standard) — it covers the *packaging and release artifact* decisions.

---

## Principles

1. **Match distribution to audience.** Developer tools → npm/bun. General users → standalone binary or Homebrew. Server-deployed tools → Docker. Don't use npm for tools that have no Node runtime requirement.
2. **Single-command install.** A user should be able to install the tool in one command without reading a multi-page guide.
3. **Version pinning is the user's right.** Never force auto-update. Publish semver-pinned releases so users can stay on a known version.

---

## Distribution Patterns

### Pattern 1: npm / bun publish (TypeScript/JavaScript tools)

Use when the tool is a TypeScript/JavaScript CLI and target users are developers with Node/Bun installed.

```json
// package.json
{
  "name": "@scope/tool-name",
  "version": "1.0.0",
  "bin": {
    "tool-name": "./dist/cli.js"
  },
  "files": ["dist/", "README.md"],
  "engines": { "node": ">=22.0.0" }
}
```

**Rules:**
- `bin` entry MUST point to the compiled output, not `src/`
- `files` MUST be an explicit allowlist — never ship `node_modules`
- `engines.node` MUST specify the minimum supported version
- Publish with `bun publish` or `npm publish --access public`
- Use `bundleDependencies` for any dependency that must ship with the package

---

### Pattern 2: Standalone Binary (Bun compile / pkg)

Use when the tool targets users who may not have Node/Bun installed or when startup speed matters.

```bash
# Bun compile — produces a self-contained executable
bun build ./src/cli.ts --compile --outfile dist/tool-name

# Cross-compile targets
bun build ./src/cli.ts --compile --target bun-linux-x64 --outfile dist/tool-name-linux-x64
bun build ./src/cli.ts --compile --target bun-darwin-arm64 --outfile dist/tool-name-darwin-arm64
bun build ./src/cli.ts --compile --target bun-windows-x64 --outfile dist/tool-name-win-x64.exe
```

**Rules:**
- Produce binaries for at least `linux-x64`, `darwin-arm64`, `darwin-x64`
- Include binaries as GitHub Release assets (not committed to git)
- Binary filename MUST follow `<tool-name>-<os>-<arch>` convention
- Document checksum verification in README

---

### Pattern 3: Homebrew (macOS/Linux users, general audience)

Use when the tool targets general developers on macOS and Linux who use Homebrew.

```ruby
# Formula stub — lives in a homebrew-tap repo
class ToolName < Formula
  desc "One-line description"
  homepage "https://github.com/org/tool-name"
  url "https://github.com/org/tool-name/releases/download/v1.0.0/tool-name-darwin-arm64"
  sha256 "abc123..."
  version "1.0.0"

  def install
    bin.install "tool-name-darwin-arm64" => "tool-name"
  end
end
```

**Rules:**
- Maintain a `homebrew-<org>` tap repo (e.g. `homebrew-devos`)
- Formula MUST reference a pinned release URL (not `main` branch HEAD)
- SHA256 checksum MUST be included
- Bump formula version as part of the release process

---

### Pattern 4: Docker (server-deployed CLI tools / daemons)

Use when the tool runs as a daemon, server process, or in CI environments.

```dockerfile
FROM oven/bun:1-alpine AS builder
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun build ./src/cli.ts --compile --outfile /app/tool-name

FROM alpine:3.20
RUN addgroup -S tool && adduser -S tool -G tool
COPY --from=builder /app/tool-name /usr/local/bin/tool-name
USER tool
ENTRYPOINT ["tool-name"]
```

**Rules:**
- Use multi-stage build — final image must NOT contain source code or dev deps
- Run as a non-root user
- Image tag MUST be semver-pinned on release (not `latest` in CI)
- Publish to ghcr.io (`ghcr.io/org/tool-name:1.0.0`)

---

## Versioning

All CLI-profile projects MUST follow semver:

| Bump | When |
|---|---|
| `patch` | Bug fix, no behavior change |
| `minor` | New command, new flag, new output field (backwards-compatible) |
| `major` | Breaking change to existing command interface, removed flag, changed output shape |

Version MUST be accessible via `tool-name --version` and output only the semver string (no prefix, no extra text):

```bash
$ tool-name --version
1.2.3
```

---

## Release Checklist

- [ ] `CHANGELOG.md` updated with release notes
- [ ] `package.json` / `VERSION` bumped (semver)
- [ ] Binaries built for all target platforms
- [ ] SHA256 checksums generated and published
- [ ] GitHub Release created with binaries as assets
- [ ] Homebrew formula updated (if applicable)
- [ ] Docker image published and tagged (if applicable)
- [ ] `--version` output verified

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Publishing `src/` to npm | Ships TypeScript source; requires users to transpile | Point `bin` to `dist/` only |
| Committing binaries to git | Bloats repo history | Use GitHub Releases for binary assets |
| `latest` Docker tag in production | Breaks reproducibility | Pin to semver tag |
| No `--version` flag | Users can't verify installed version | Always implement `--version` |
| Auto-update without opt-in | Breaks pinned workflows | Version pinning is user's right |

---

## Compliance Test

- [ ] Tool installs in one command for the target audience?
- [ ] `--version` outputs a bare semver string?
- [ ] npm package `files` is an explicit allowlist (no `node_modules`)?
- [ ] Binaries cover at least linux-x64 + darwin-arm64?
- [ ] Release process includes CHANGELOG + checksum?
- [ ] Docker image uses non-root user and multi-stage build?
