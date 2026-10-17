#!/usr/bin/env bash
# Runs briefs one after another in their own git worktree, headless, and checks each one itself.
# Usage:   scripts/run-track.sh <track> <ID:model> [<ID:model> ...]
# Example: scripts/run-track.sh worker P3.1:sonnet P3.2:sonnet P3.3:sonnet
# Stops the track on: a BLOCKED reply, a failed done-check, or the turn cap.
set -euo pipefail

track=$1; shift
root=$(git rev-parse --show-toplevel)
wt="$(dirname "$root")/wikishto-$track"
branch="track/$track"
logs="$root/.runs/$track"
mkdir -p "$logs"

if [ ! -d "$wt" ]; then
  git -C "$root" worktree add "$wt" -b "$branch" main
  (cd "$wt" && [ -f pnpm-lock.yaml ] && pnpm install --frozen-lockfile >/dev/null || true)
  (cd "$wt/pipeline" 2>/dev/null && uv sync >/dev/null || true)
fi
cd "$wt"

for item in "$@"; do
  id=${item%%:*}; model=${item##*:}
  brief="docs/briefs/$id.md"
  [ -f "$brief" ] || { echo "✗ no brief $id"; exit 1; }
  echo "▶ $id on $model — $(date +%H:%M)"

  claude -p "Run brief $id exactly as .claude/commands/task.md describes. Headless run: nobody can answer, so skip the plan wait, stay on the current branch and commit there. If you are blocked, make BLOCKED the first word of your final message." \
    --model "$model" --permission-mode acceptEdits --max-turns 60 --output-format json \
    > "$logs/$id.json" || true

  python3 - "$logs/$id.json" "$logs/$id.md" <<'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: d = {}
open(sys.argv[2], "w").write(d.get("result", "") or "")
print(f"  cost ${d.get('total_cost_usd', 0):.2f} · turns {d.get('num_turns', '?')}")
PY

  if head -c 40 "$logs/$id.md" | grep -q BLOCKED; then echo "■ $id blocked — read $logs/$id.md"; exit 2; fi

  line=$(grep -m1 '^\*\*Done-check:\*\*' "$brief" || true)
  if grep -q '(owner)' <<<"$line"; then echo "… $id needs your manual check"; continue; fi
  check=$(sed -E 's/^[^`]*`([^`]*)`.*/\1/' <<<"$line")
  if bash -c "$check" > "$logs/$id.check.log" 2>&1; then
    echo "✓ $id"
  else
    echo "✗ $id done-check failed — read $logs/$id.check.log"; exit 3
  fi
done

echo "Track $track done. Review with: git log --oneline main..$branch  (in $wt)"
