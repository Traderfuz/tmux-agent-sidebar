<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/no-commit-trailers.md and re-run profile-sync. -->
# No Commit Trailers Standard

## Overview

Git commit trailers (`Co-Authored-By:`, `Signed-off-by:`, etc.) are machine-readable footer fields parsed by changelog generators, CI tooling, and release scripts. Adding AI tool attribution trailers pollutes this semantic layer with no machine-readable benefit, discloses tool usage in public repository history, and violates the principle that commit authorship reflects the human responsible for the change.

## Scope

This standard covers `Co-Authored-By:` trailers and any AI tool attribution in git commit message footers. It does NOT cover `Signed-off-by:` DCO trailers used for legal contributor sign-off, nor does it govern commit message type, scope, body, or subject format.

## Principles

1. **Authorship is human:** A commit records the human who is accountable for the change. AI tools are instruments, not co-authors.
2. **Trailers are machine-readable contracts:** Per the Conventional Commits spec, footers are parsed by tooling. Unrecognised trailers add noise; AI attribution fields have no tooling consumer.
3. **History is permanent:** Commit trailers are immutable once pushed. Attribution that is wrong or unwanted cannot be easily removed from shared history.

## Rules

### Prohibited trailers

- **`Co-Authored-By: Claude …`** — MUST NOT appear in any commit message (`MUST NOT`)
- **`Co-Authored-By: GPT …`** — MUST NOT appear (`MUST NOT`)
- **`Co-Authored-By: Copilot …`** — MUST NOT appear (`MUST NOT`)
- **`Co-Authored-By: Gemini …`** — MUST NOT appear (`MUST NOT`)
- Any trailer containing an AI tool name, model name, or `noreply@anthropic.com` / `noreply@openai.com` style addresses (`MUST NOT`)

```
# OFF-STANDARD
fix(auth): guard against undefined session token

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

# ON-STANDARD
fix(auth): guard against undefined session token
```

### Permitted trailers

- `Closes #N` — issue/PR reference (`MAY`)
- `BREAKING CHANGE: …` — Conventional Commits breaking change marker (`MUST` when applicable)
- `Signed-off-by: Human Name <email>` — DCO legal sign-off for open-source projects (`MAY`)

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` | AI tool is not a human author; pollutes changelog tooling | Omit entirely |
| Any `noreply@anthropic.com` address in trailers | Discloses tool usage in permanent public history | Omit entirely |
| AI model version in commit body ("Generated with Claude") | Commit bodies are indexed; this is noise with no actionable value | Omit entirely |

## Deviation guidance

There are no legitimate deviations. AI tools are instruments that assist the human author — the human's name and email are the correct and complete authorship record.

## Compliance test

- [ ] No `Co-Authored-By:` line references an AI tool, model name, or AI provider email?
- [ ] No `noreply@anthropic.com`, `noreply@openai.com`, or equivalent AI provider address in any trailer?
- [ ] Commit message footer contains only `Closes #N`, `BREAKING CHANGE:`, `Signed-off-by:` (human), or nothing?

If any check fails: amend the commit before pushing (`git commit --amend`), or force-push the branch if already pushed to a non-main branch.

## References

- [Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/) — defines footer/trailer semantics; trailers are parsed by tooling, not humans
- [git-interpret-trailers](https://git-scm.com/docs/git-interpret-trailers) — the mechanism being governed; AI tool names have no registered trailer token
