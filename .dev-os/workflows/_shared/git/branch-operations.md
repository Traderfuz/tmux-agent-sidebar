```bash
# Ensure latest main is available
current_branch=$(git branch --show-current)
git fetch origin

# Update local main
if [[ "$current_branch" != "main" ]]; then
  git checkout main
fi
git pull --ff-only origin main

# Return to feature branch if needed
if [[ "$current_branch" != "main" && -n "$current_branch" ]]; then
  git checkout "$current_branch"
fi
```
