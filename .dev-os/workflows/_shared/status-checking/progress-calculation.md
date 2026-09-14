# Calculate task progress from tasks.md

Parses a DevOS `tasks.md` file and sets three shell variables — `$progress_percent`, `$completed_tasks`, and `$total_tasks` — so the calling workflow can render a progress display without re-implementing the counting logic.

**Pattern:** Detect → Repair → Revalidate (Phase 1: detect file existence; Phase 2: count tasks; Phase 3: compute percentage, fallback to zero on error)

## When to Use

Include this snippet inside any workflow step that needs to report task completion status for an active spec. Do not invoke this on arbitrary markdown files — it is valid only for DevOS `tasks.md` files using `- [ ]` / `- [x]` checkbox syntax. Do not use this to render output; pass the variables to the caller's display step instead.

## Process

1. Set `tasks_file` to the path of the spec's `tasks.md` before including this snippet.

2. Run the counting logic — filters out legend annotation lines (containing `= todo`, `= done`, `= skipped`) and arrow lines containing `→` that annotate group headers, not real task items:

```bash
# Calculate task progress from tasks.md
# Exclude legend lines (e.g. "- [ ] = todo  - [x] = done") and lines containing "→"
total_tasks=$(grep "^- \[[ x]\]" "$tasks_file" 2>/dev/null | grep -v "= todo\|= done\|= skipped\|→" | wc -l || echo 0)
completed_tasks=$(grep "^- \[x\]" "$tasks_file" 2>/dev/null | grep -v "= todo\|= done\|= skipped\|→" | wc -l || echo 0)

if [[ "$total_tasks" -gt 0 ]]; then
  progress_percent=$((completed_tasks * 100 / total_tasks))
else
  progress_percent=0
fi
```

3. After this snippet, use `$progress_percent`, `$completed_tasks`, and `$total_tasks` in the caller's display step. The snippet sets no other state.

## Output Format

This snippet sets variables only — it produces no terminal output itself. The calling workflow renders progress using the three exported variables:

```
Progress: 14/20 tasks (70%)
```

Example caller rendering:

```bash
echo "Progress: ${completed_tasks}/${total_tasks} tasks (${progress_percent}%)"
```
