# Rollback to Checkpoint

Safely restore a prior recovery checkpoint.

## When to Use

- Implementation went in the wrong direction
- You need to return to a known-good state



Do not use this workflow to undo committed and pushed changes — it is for local checkpoint rollback only. For reverting pushed commits, use `git revert`.

## Process

## Process

1. List available checkpoints from `product/runtime/` checkpoint records.
2. Confirm rollback target with user.
3. Restore files to checkpoint state using git reset or file restoration.
4. Update session state to reflect rollback.

### Step 1: Locate Checkpoints

```bash
source scripts/lib/recovery.sh
list_checkpoints <spec-name>
```

### Step 2: Confirm Rollback Target

Ask the user to confirm the checkpoint timestamp.

### Step 3: Roll Back Safely

```bash
source scripts/lib/rollback.sh
rollback_to_checkpoint <spec-name> <checkpoint-timestamp>
```

### Step 4: Report Outcome

Show the restored checkpoint and active branch.

## Display Format

```
Rollback to Checkpoint: [checkpoint-name]
  Files restored: [N]
  Git state:      [clean | reset to SHA [abc1234]]
  Session state:  [updated]
  Status:         [complete | failed — [reason]]
```
