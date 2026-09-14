# Shared Workflow Snippets

This directory contains reusable workflow snippets that can be included in other workflows using the `{{include}}` directive.

## When to Use

Use this guide when creating, auditing, or updating reusable workflow snippets under `profiles/general/workflows/_shared/`.

Do not use this directory as a public workflow entrypoint, a command catalog, or a place for skill execution logic. Avoid adding snippets for one-off workflow details that are unlikely to be reused.

## Include Syntax

To include a shared snippet in a workflow:

```markdown
{{include workflows/_shared/path/to/snippet}}
```

## Directory Structure

- `git/` - Git-related patterns (commit formats, status checks, branch operations)
- `recovery/` - Recovery workflow patterns (provider detection, session metadata, routing)
- `error-handling/` - Error handling patterns (tables, return codes, edge cases)
- `status-checking/` - Status validation patterns (git state, progress calculation, timestamps)
- `specification/` - Spec pipeline patterns (product context check, design approach library)
- `tasks/` - Task authoring templates (TDD, Walking Skeleton, Integration, Refactor, Migration)
- `quality/` - QA and release gates (data reset safety checklist, pre-launch verification)

## Available Snippets by Category

### Git Snippets (`git/`)

| Snippet | Description | Usage |
|---------|-------------|-------|
| `commit-message-format.md` | Conventional commit format | Creating git commits |
| `git-status-check.md` | Git status verification for working directory cleanliness | Before git operations |
| `branch-operations.md` | Branch creation, naming, and verification patterns | Creating feature branches |
| `changelog-update.md` | CHANGELOG.md update process and format | Before committing changes |

### Recovery Snippets (`recovery/`)

| Snippet | Description | Usage |
|---------|-------------|-------|
| `provider-detection.md` | Provider-based source type detection | Detecting plan sources |
| `session-metadata.md` | Session metadata extraction and formatting | Session discovery |
| `error-table-format.md` | Standard error table format for documentation | Documenting error cases |
| `recovery-routing.md` | Session type parsing and handler routing | Executing recovery |

### Error Handling Snippets (`error-handling/`)

| Snippet | Description | Usage |
|---------|-------------|-------|
| `error-handling-table.md` | Standard error case table format | Documenting workflow errors |

### Status Checking Snippets (`status-checking/`)

| Snippet | Description | Usage |
|---------|-------------|-------|
| `git-state-validation.md` | Branch detection, dirty state, feature branch verification | Validating git state |
| `progress-calculation.md` | Task counting, percentage calculation, completion status | Computing progress |
| `timestamp-formatting.md` | ISO 8601 format, time-ago strings, file mtime | Working with timestamps |

## Naming Conventions

- Use lowercase, hyphenated names (e.g., `commit-message-format.md`)
- Be descriptive but concise
- Group related snippets in subdirectories
- Use category subdirectories: `git/`, `recovery/`, `error-handling/`, `status-checking/`

### Specification Snippets (`specification/`)

| Snippet | Description | Usage |
|---------|-------------|-------|
| `product-context-check.md` | Product context stub check for `mission.md` and `roadmap.md` | Entry gate for `shape-spec` and `write-spec` |
| `design-approaches.md` | Six named design approach patterns for spec authoring | Approach selection in `shape-spec` workflow |

### Task Snippets (`tasks/`)

| Snippet | Description | Usage |
|---------|-------------|-------|
| `task-templates.md` | Five task type templates: TDD, Walking Skeleton, Integration, Refactor, Migration | Task authoring in `create-tasks` command |

### Quality Snippets (`quality/`)

| Snippet | Description | Usage |
|---------|-------------|-------|
| `data-reset-gate.md` | Pre-flight safety checklist before resetting test DB — backup confirm, test gates, protected table verification, point-of-no-return prompt | Before any TRUNCATE / reset-account in QA → dogfood cycle |

### MCP Snippets (`mcp/`)

| Snippet | Description | Usage |
|---------|-------------|-------|
| `registry-check-step.md` | Check MCP registry + deferred tool list before proposing a manual verification step; includes service→server→tool-prefix table and preference rule | Before any workflow step that would ask the user to manually verify something in an external service |

## When to Create a Snippet

Create a shared snippet when:

1. The same content appears in 3 or more workflows
2. The content is a self-contained logical unit
3. The content is likely to need consistent updates across workflows
4. The content represents a standard pattern or convention

## When to Inline

Keep content inline when:

1. It's workflow-specific and unlikely to be reused
2. It's tightly coupled to the workflow's context
3. It's only used in one other place

## Snippet Guidelines

- Snippets should be plain markdown without frontmatter
- Keep snippets focused on a single concept or pattern
- Document any variables or placeholders that need replacement
- Avoid including workflow-specific context in shared snippets
- Use H2 (##) as the top-level header within snippets
- Include usage examples in each snippet

## Include Processing

The template processor handles includes in this order:

1. **Conditionals** - Process `{{IF}}` and `{{UNLESS}}` blocks
2. **Includes** - Process `{{include}}` directives recursively
3. **Workflows** - Process `{{workflows/}}` references
4. **Standards** - Process `{{standards/}}` references

### Include Features

- **Recursive processing** - Snippets can include other snippets (max 10 levels deep)
- **Circular detection** - Circular includes are detected and warned
- **Profile inheritance** - Child profiles can override parent snippets
- **Missing file handling** - Missing includes insert a warning message

## Output Format

Shared snippets should be plain markdown fragments with stable H2 sections and no YAML frontmatter:

```markdown
## Snippet Title

Short reusable guidance.

1. First deterministic step.
2. Second deterministic step.
```

## Examples

### Basic Include

```markdown
# My Workflow

## Process

{{include workflows/_shared/git/git-status-check}}

## Implementation
```

### Nested Includes

A snippet can include other snippets:

```markdown
{{include workflows/_shared/recovery/provider-detection}}
{{include workflows/_shared/recovery/session-metadata}}
```

### With Workflow References

Includes work alongside existing workflow references:

```markdown
{{include workflows/_shared/git/branch-operations}}

{{workflows/git/update-changelog}}
```

## Validation

The `validate-profile.sh` script validates include references:

```bash
bash scriptsvalidate-profile.sh --profile general
```

This checks:
- All `{{include}}` references point to existing files
- No circular include references exist
- Snippets are valid markdown

## Migration Guide

To migrate existing workflows to use shared snippets:

1. **Identify shared content** - Look for repeated patterns across workflows
2. **Extract to snippet** - Create a new file in `_shared/` with the shared content
3. **Replace with include** - Use `{{include}}` syntax in source workflows
4. **Test compilation** - Verify the template processor correctly expands includes
5. **Validate** - Run `validate-profile.sh` to check references

See `MIGRATION.md` for detailed migration instructions.
