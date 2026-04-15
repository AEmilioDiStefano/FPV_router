# Git Workflow (`main` Source Of Truth + Optional Snapshot Tags)

Use this workflow from any directory:

```bash
FPV_ROUTER_BOOTSTRAP_ENV="$(find "${FPV_ROUTER_SEARCH_ROOT:-$HOME}" -maxdepth 8 -type f -path "*/scripts/fpv_router_bootstrap_env.sh" 2>/dev/null | sort | head -n1)"
if [[ -z "${FPV_ROUTER_BOOTSTRAP_ENV:-}" ]]; then
  echo "[FAIL] Could not locate FPV_router bootstrap helper under ${FPV_ROUTER_SEARCH_ROOT:-$HOME}." >&2
  return 1 2>/dev/null || exit 1
fi
source "$FPV_ROUTER_BOOTSTRAP_ENV" --interactive
unset FPV_ROUTER_BOOTSTRAP_ENV

cd "$FPV_ROUTER_ROOT"
```

This bootstrap exports `FPV_ROUTER_ROOT`, `FPR`, and `FPV_ROUTER_REPO_NAME`.
If the repo is not somewhere under `$HOME`, set `FPV_ROUTER_SEARCH_ROOT` before running the snippet.

Current GitHub remote:

```bash
git remote -v
```

Expected `origin`:

```text
https://github.com/AEmilioDiStefano/FPV_router.git
```

`FPV_router` is a single GitHub repo.
`main` is the primary source of truth.

For small, direct updates you can work on `main`.
For larger or riskier changes, use a feature branch and merge it back into `main` after review.

## Model

- Keep `main` fast-forwardable and in a deployable state.
- Pull `main` before starting work and again before pushing.
- Use feature branches for grouped work when the change is more than a tiny edit.
- Use immutable tags for known-good snapshots you may want to return to later.

This repo is mostly documentation and configuration, so there is no workspace rebuild step here like there is in `swarm_control_core` or `swarm_control_pro`.

## 1) Normal Development Push (`main`)

Use this when you are making a straightforward update directly on `main`.

```bash
cd "$FPV_ROUTER_ROOT"
git fetch origin --prune --tags
git switch main
git pull --ff-only origin main

git add -A
if git diff --cached --quiet --ignore-submodules --; then
  echo "[SKIP] No local changes to commit."
else
  git commit -m "updates"
  git push origin main
fi

git status --short
```

Expected:
- `git status --short` is empty after a successful push.

## 2) Normal Development Pull (`main`)

Use this on another machine, or before you start work locally.

```bash
cd "$FPV_ROUTER_ROOT"
git fetch origin --prune --tags
git switch main
git pull --ff-only origin main

git status --short
git log --oneline -n 5
```

Expected:
- `git status --short` is empty.
- `main` matches GitHub `main`.

## 3) Start A Feature Branch

Use this when you want an isolated branch for a focused change.

```bash
cd "$FPV_ROUTER_ROOT"
git fetch origin --prune --tags
git switch main
git pull --ff-only origin main

export BRANCH_NAME="feature/short-description"
git switch -c "$BRANCH_NAME"

git status --short
```

Examples:
- `feature/router-doc-cleanup`
- `feature/git-workflow-doc`
- `fix/readme-command-order`

## 4) Push Work On A Feature Branch

Use this while the branch is in progress or when you want to open a PR.

```bash
cd "$FPV_ROUTER_ROOT"
: "${BRANCH_NAME:?Set BRANCH_NAME first}"
git switch "$BRANCH_NAME"

git add -A
if git diff --cached --quiet --ignore-submodules --; then
  echo "[SKIP] No local changes to commit."
else
  git commit -m "updates"
fi

git push -u origin "$BRANCH_NAME"
git status --short
```

After the first push, later updates can use:

```bash
cd "$FPV_ROUTER_ROOT"
git switch "$BRANCH_NAME"
git add -A
git commit -m "updates"
git push
```

## 5) Update A Feature Branch From `main`

Use this if `main` moved forward while your branch was open.

```bash
cd "$FPV_ROUTER_ROOT"
: "${BRANCH_NAME:?Set BRANCH_NAME first}"

git fetch origin --prune --tags
git switch main
git pull --ff-only origin main

git switch "$BRANCH_NAME"
git merge --ff-only main || git merge main

git status --short
```

If Git reports conflicts, resolve them, then run:

```bash
git add -A
git commit
git push
```

## 6) Return To `main` After A Branch Merges

Use this after the feature branch is merged on GitHub, or after you merge it locally.

```bash
cd "$FPV_ROUTER_ROOT"
: "${BRANCH_NAME:?Set BRANCH_NAME first}"

git fetch origin --prune --tags
git switch main
git pull --ff-only origin main

git branch -d "$BRANCH_NAME"
git status --short
```

Optional remote cleanup after the branch is fully merged:

```bash
git push origin --delete "$BRANCH_NAME"
```

## 7) Create And Publish A Snapshot Tag

Use this when you decide "this exact state is known-good and I may want to recover or share it later".

```bash
cd "$FPV_ROUTER_ROOT"
git fetch origin --prune --tags
git switch main
git pull --ff-only origin main

export SNAPSHOT_REF="fpv-router-$(date +%Y%m%d-%H%M)"
# Optional explicit name:
# export SNAPSHOT_REF="fpv-router-2026-04-15-a"

git tag -a "$SNAPSHOT_REF" -m "Snapshot $SNAPSHOT_REF"
git push origin "$SNAPSHOT_REF"

git show -s --format='SNAPSHOT_REF=%h %d %s' "$SNAPSHOT_REF"
```

Important:
- Do not force-push tags.
- If a tag name is wrong, create a new tag instead of rewriting the old one.

## 8) Sync A Clone To An Exact Snapshot Tag

Use this to make another machine match an exact tagged state.

```bash
cd "$FPV_ROUTER_ROOT"
: "${SNAPSHOT_REF:?Set SNAPSHOT_REF first}"

git stash push -u -m "pre-snapshot-sync-$(date +%F-%H%M%S)" || true
git fetch origin --prune --tags
git show-ref --verify --quiet "refs/tags/$SNAPSHOT_REF" || {
  echo "[ERROR] Missing tag on this clone: $SNAPSHOT_REF" >&2
  exit 1
}

git switch --detach "$SNAPSHOT_REF"
git restore --staged --worktree .
git clean -fd

git status --short
git show -s --format='SNAPSHOT_REF=%h %d %s' "$SNAPSHOT_REF"
```

Expected:
- `git status --short` is empty.
- `HEAD` is detached at `SNAPSHOT_REF`.

To go back to normal development afterwards:

```bash
cd "$FPV_ROUTER_ROOT"
git switch main
git pull --ff-only origin main
```

## 9) Rules

1. Run Git commands from the repo root unless a command clearly says otherwise.
2. Prefer `git pull --ff-only origin main` on `main` so history stays clean.
3. Do not force-push `main`.
4. Do not commit real Wi-Fi passwords, SSH keys, private tokens, or other secrets.
5. Keep generated or local-only artifacts out of the repo when possible.
6. If `git status --short` is not clean before a pull, either commit your work or stash it first:

```bash
cd "$FPV_ROUTER_ROOT"
git status --short
git stash push -u -m "temp-$(date +%F-%H%M%S)"
git pull --ff-only origin main
```

7. If you used a snapshot tag with detached `HEAD`, switch back to `main` before doing normal development work:

```bash
cd "$FPV_ROUTER_ROOT"
git switch main
git pull --ff-only origin main
```
