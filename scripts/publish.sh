#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gh >/dev/null || { echo 'Install GitHub CLI and run gh auth login first.' >&2; exit 1; }
gh auth status
[[ -d .git ]] || git init -b main
git add .
if ! git diff --cached --quiet; then git commit -m 'Add Eclipse BPEL Designer and Apache ODE development environment'; fi
if git remote get-url origin >/dev/null 2>&1; then
 git push -u origin HEAD
else
 # Private by default; pass --public explicitly to publish source publicly.
 visibility="${1:---private}"
 [[ "$visibility" == --private || "$visibility" == --public ]] || exit 2
 gh repo create BPELDesigner "$visibility" --source=. --remote=origin --push
fi
