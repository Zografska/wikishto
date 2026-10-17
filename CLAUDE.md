# WikiShto — agent rules

Daily Macedonian word game (Pedantle-style): reveal a hidden Wikipedia intro word by word.

## Map

- `shared/` contracts: `api-types.ts`, `puzzle.ts`, `puzzle-format.md`, `function-words.mk.json`, `normalize-cases.json`, `fixtures/`
- `pipeline/` Python CLI (`uv`, package `wikishto`). Data in `pipeline/data/`, outputs in `pipeline/out/` (both gitignored)
- `worker/` Cloudflare Worker (Hono, TS). Puzzles in KV, vocab + logs in D1
- `web/` React + Vite + shadcn on GitHub Pages, HashRouter, base `/wikishto/`
- `docs/briefs/` one file per task · `docs/STATUS.md` progress log · `docs/SPEC.md` full spec (don't read by default)

## Project facts (owner fills in)

- GitHub user: Zografska
- LAUNCH_DATE: unset until the first public puzzle. Only used for puzzle #N and the archive start; read it from the `LAUNCH_DATE` var, never hardcode it
- Cloudflare account id `47fff1d6ee5e294b203ff8ab6a8e2947`
- KV binding `WIKISHTO_KV` · id `45901336fc8b4664b716dbb7cd9ba725` · preview_id `7e12b3a0e0e341c098b21c4623989b25`
- D1 binding `DB` · database_name `wikishto` · database_id `fc0146c0-6b43-41c6-b22c-85b4ce919d2c`

## How you work

1. Your task is one brief: `docs/briefs/<ID>.md`. Read only the files under its **Read** list.
   Don't explore the repo. Open `docs/SPEC.md` only if the brief is impossible without it, and say which section and why.
2. Unless the brief says `autogo`, reply first with a plan of 10 lines or fewer and wait.
3. Write the tests from **Acceptance** first, then the code.
4. Run **Done-check**. At most 3 fix rounds; then stop and report the blocker.
5. Run the `reviewer` subagent on `git diff main`. Fix real issues only.
6. Append 15 lines or fewer to `docs/STATUS.md`. Commit on branch `task/<ID>`.

## Rules

- `shared/` is the source of truth. Don't change it unless the brief says so; if it looks wrong, stop and say why.
- Touch only files under **Touch** (plus their tests). No new dependencies unless the brief allows them.
- Never print whole data files. Inspect `pipeline/data` and `pipeline/out` with small summaries (`wc`, a 5-line `python -c`).
- UI text lives only in `web/src/strings.mk.ts`. Copy the owner writes stays `TODO_MK`.
- Use the language code `mk` in KV keys and function params; never hardcode it elsewhere.
- Never log or store IP, user agent or location.
- Never deploy, push, or write to remote KV/D1. The owner does that.

## Commands (quiet by default)

- TS tests: `pnpm -r test -- --reporter=dot` · one package: `pnpm -C worker test -- --reporter=dot`
- Types: `pnpm -r typecheck` · Lint: `pnpm -r lint`
- Python: `cd pipeline && uv run pytest -q -x` · `uv run ruff check .`
- Worker local: `pnpm -C worker dev`

## Final message format

Changed: files · Decisions: up to 3 bullets · Open: blockers/questions · Next: suggested brief. No code recaps.
