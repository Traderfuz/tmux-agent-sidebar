```bash
# Validate repository state before checkpointing or committing
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
  echo "Repository has tracked changes"
else
  echo "Repository is clean"
fi
```
