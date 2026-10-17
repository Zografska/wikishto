# WikiShto — MVP Spec

Oct 16, 2026 · @ao

## Overview

WikiShto is a daily Macedonian word game modeled on Pedantle: a hidden Wikipedia intro that players uncover word by word until they reveal the title. The MVP is Macedonian only, free to run, and built so Serbian can be added later without a rewrite.

How the pieces fit, in data order:

1. **Pipeline (Python, your machine):** picks articles, lemmatizes them, and precomputes every possible hit and near miss for each day's puzzle.
2. **Cloudflare KV and D1:** KV holds scheduled puzzles and the vocabulary; D1 holds guess logs. Puzzle answers never touch the public repo.
3. **Cloudflare Worker (TypeScript + Hono):** answers guesses by lookup, decides what "today" is, verifies wins, and logs guesses.
4. **Frontend (React + Vite + shadcn on GitHub Pages):** renders the hidden article and keeps the player's progress in localStorage.

The Worker never needs embeddings or a lemmatizer at runtime. Everything expensive happens once, offline, which is what keeps hosting at €0.

## Revision notes

This pass fixed two real gaps, simplified the data release, and pinned down several loose definitions. Only the first row changes a decision you made; revert it if you prefer the original.

| Area | Change | Why |
| --- | --- | --- |
| Puzzle release (**changed decision**) | Upload puzzles straight from your machine into Cloudflare KV, about 60 days ahead. The Worker only serves dates up to today. No puzzle files in git, no encryption, no nightly data Action. A weekly Action just checks that at least 14 days remain scheduled. | Removes the encryption key, the decrypt step, and the nightly job. The Worker's date check already does the "release". |
| Guess lemmatization (**gap**) | The pipeline builds a form → lemma table for the whole vocabulary and stores it in D1. The Worker looks guesses up there. | CLASSLA can't run inside a Worker, so guesses had no way to be lemmatized at runtime. |
| Rare article words (**gap**) | Every word in today's article is always an accepted guess, even outside the top 100k. | Otherwise some article words could never be revealed. |
| Ambiguous forms | A form with several possible lemmas maps to the most frequent one. | Keeps lookup to one row per form. |
| Numbers | Near misses for numbers are computed in the Worker, not precomputed. A decimal like 2,1 is one block with the comma visible, and input accepts a comma between digits. | Numeric closeness is simple math; splitting 2,1 into two blocks was confusing. |
| Streaks | A streak is consecutive days on which today's puzzle was solved. | Same outcome as "unfinished at midnight breaks it", one rule instead of two. |
| % revealed | Defined as revealed word blocks ÷ all word blocks, title included. | It was undefined. |
| Short-word rule | Dropped "single-letter words never hint". | Superseded by your decision that function words do give near misses. |
| Routing | HashRouter, e.g. `/#/2026-10-20`. | GitHub Pages has no SPA fallback; this avoids the 404.html trick. |
| Logging | Two tables: one row per guess, one row per solve. | Solve data no longer repeats on every guess row. |
| Nice-to-haves | Latest-guess pulse and tap-to-cycle matches are marked as can-slip. | They're polish, not core loop. |

Two more changes came up while writing the backend: puzzle data lives in KV instead of D1, because D1's free tier caps daily row writes, and similarity pairs are stored down to 0.30 so thresholds can be retuned from Worker config without rerunning the pipeline.

## Gameplay rules

One shared puzzle per day, plus an open archive of past days. You win by revealing every word of the title.

- **The text:** the intro of a Macedonian Wikipedia article, cut at a sentence boundary at roughly 200–350 words, shown under its hidden title.
- **Shown from the start:** whitespace, punctuation, hyphens, the comma or separator inside numbers, and any Latin-script tokens left after cleanup. Everything else is a gray block.
- **Letter count:** tapping a block shows its length. Free, unlimited, and it stays visible until the word is revealed.
- **A guess** reveals exact hits everywhere they appear and paints near misses into other slots (see Input and matching).
- **Win:** every title word revealed. The whole article and its Wikipedia link then appear.
- **Score:** number of accepted guesses. Secondary stat: % revealed, defined as revealed word blocks ÷ all word blocks, title included.
- **No give-up button and no hints** in the MVP.
- **Streak:** consecutive days on which that day's puzzle was solved. Archive solves get a checkmark but never affect the streak.
- **Puzzle number:** #1 is launch day, then +1 per day.
- **Share:** one tap copies `WikiShto #N — решено во X обиди, Y% откриено` plus the game link, and the streak when it's above 1. No spoilers.

## Input and matching

Every guess is resolved by table lookups in the Worker, in this order:

1. **Character check (client and server):** either Cyrillic letters only, or digits with at most one comma or period between them. Anything else is blocked at the input. Hyphens are never typed; a hyphenated compound is two blocks.
2. **Normalize:** trim, lowercase, ѐ → е, ѝ → и. The pipeline applies the same rules to the article.
3. **Numbers** skip vocabulary checks. Exact hit = same value. Near miss = within ±10 for year-like numbers (four digits, 1000–2100), otherwise within ±10%. Computed in the Worker.
4. **Words** are accepted if they're in the vocabulary table or in today's article. Otherwise the reply is "Непознат збор" and the guess isn't counted.
5. **Lemma:** look up the guess's lemma in the form → lemma table. A form with several lemmas uses the most frequent one.
6. **Exact hits:** every slot whose lemma equals the guess lemma, so куќа reveals куќата, куќи, куќава.
7. **Near misses:** read today's precomputed list for that lemma: (slot, similarity) pairs. Keep pairs at or above the threshold.

**Thresholds** (starting values, tuned in the soft launch):

| Pair type | Near-miss threshold (cosine) |
| --- | --- |
| Content word ↔ content word | 0.40 |
| Either side is a function word | 0.60 |

The pipeline stores every pair down to 0.30, and the Worker applies the thresholds from its config. That way retuning is a config change, not a rerun of the pipeline.

**Function words** come from one curated list of about 100 Macedonian words (и, на, во, се, е, од, со, за, да, ...) kept in the repo. The Worker tags each near miss as `content` or `function` so the client can color them differently.

**Client side:** each slot keeps only its best near miss so far; a closer guess replaces it. Title slots get near misses like any other slot.

**Fallback:** if CLASSLA proves too slow or inaccurate, swap lemmas for a suffix-stripping stemmer (-от, -та, -то, -ов, -ва, -во, -он, -на, -но, plurals). Only the pipeline changes; the Worker still just looks up "lemma".

## Visual design and UX

Color carries hint strength and type, and a second cue (italics, underline) makes every state readable without color.

| State | Default palette | Colorblind palette | Non-color cue |
| --- | --- | --- | --- |
| Hidden | Gray block sized to letter count | Same | Block shape |
| Exact hit | Plain text, brief flash on reveal | Same | Normal weight |
| Content near miss | Gray → orange, stronger = more saturated | Light → dark blue | Regular style |
| Function-word near miss | Muted teal/green | Orange | Italics |

The colorblind toggle sits in settings, swaps CSS variables only, and is saved in localStorage. Both palettes need light and dark mode values.

**Layout:**

- Title on top, article below, each word as a block or revealed text.
- Input pinned to the bottom of the screen on mobile, with a hint line for rejections and the rate-limit message ("Полека, размисли малку 😛").
- Guess list in a drawer on mobile and a side panel on desktop. Newest first, each with its exact-hit count, e.g. "куќа — 3".
- Win screen: full article, Wikipedia link, score, % revealed, streak, share button.

**Can slip past MVP:** the one-time pulse on the latest guess's matches, and tapping a guess to cycle through its matches in the article.

## Content pipeline

A Python CLI on your machine turns the Macedonian Wikipedia dump into about 60 days of ready puzzles per run, then uploads them to Cloudflare KV.

1. **Inputs:** the mk.wikipedia articles dump, the Wikimedia pageviews data for the last 12 months, and fastText `cc.mk.300`.
2. **Candidate pool:** the top \~3,000 articles by pageviews, minus disambiguation pages, lists, date and year articles, and stubs.
3. **Clean the intro:** strip templates, references, IPA, and parenthetical foreign-language glosses. Remove title disambiguators ("Охрид (град)" → "Охрид"). Cut at a sentence boundary at 200–350 words. Drop articles under 120 words after cleanup.
4. **Review:** write candidates to a CSV with an `approved` column. You skim and approve, skipping politically or ethnically charged topics.
5. **Lemmatize:** run CLASSLA over each approved article in context. Normalize case and ѐ/ѝ.
6. **Vocabulary:** the top 100k Cyrillic tokens from fastText, each mapped to a lemma (most frequent lemma when ambiguous). Exported once as a single form → lemma blob.
7. **Similarities:** for each puzzle, compute cosine similarity between every vocabulary lemma and every unique article lemma (a 100k × \~200 matrix, seconds with numpy). Keep pairs ≥ 0.30, expanded to slot indexes.
8. **Schedule:** assign approved articles to dates with a fixed random seed. An `overrides.csv` pins specific articles to holidays or notable dates.
9. **Upload:** one KV key per puzzle date, written with `wrangler`. Re-running a date overwrites it.

**Before building the rest:** run steps 3–7 on 10 sample articles and measure the per-puzzle blob size. If it's over a few MB, raise the storage floor from 0.30 to 0.35.

The pipeline lives in the public repo, but its outputs (articles, schedule, similarity blobs) are gitignored. Answers exist only on your machine and in KV.

## Backend

One Cloudflare Worker (TypeScript + Hono) with four stateless endpoints. Puzzle data is read from KV, logs go to D1.

| Endpoint | Input | Returns |
| --- | --- | --- |
| `GET /puzzle/today` | none | Date, puzzle number, and the skeleton: per token its type (word, number, punctuation, Latin), letter count, whether it's in the title, and shown text for punctuation and Latin tokens |
| `GET /puzzle/:date` | date | Same, for archive dates. Dates after today return 404 |
| `POST /guess` | date, guess, anonymous player ID, guess number | `accepted`, `unknown`, or `invalid`; exact-hit slots; near misses as (slot, similarity, `content` or `function`) |
| `POST /solve` | date, all guesses, anonymous player ID | Full article text, title, and Wikipedia link, but only if the guesses cover every title lemma; otherwise 403 |

**Storage:**

- **KV** `vocab:mk`: the form → lemma blob. `puzzle:mk:<date>`: article tokens, lemmas, and the similarity pairs. The Worker caches both in memory between requests.
- **D1** `guesses` and `solves` tables (see Logging and privacy). Nothing else lives in D1.

**Why KV for puzzles:** a similarity list can run to tens of thousands of rows per puzzle. Written as D1 rows, 60 days would blow through the free tier's daily write limit (about 100k rows/day). As KV blobs it's one write per day of puzzles. Check current Cloudflare free-tier limits before relying on these numbers.

**Rules in the Worker:**

- **Today** = the Europe/Skopje calendar date at the moment the request arrives. The client's clock is never used.
- **Rate limit:** about 30 guesses per minute per IP via Cloudflare's rate-limiting binding. Over the limit → 429 with "Полека, размисли малку 😛". The IP is used only for this and never stored.
- **CORS:** only `https://<username>.github.io` is allowed.
- **Config** (`wrangler.toml` vars): thresholds, numeric ranges, rate limit. Retuning needs a redeploy, not a pipeline run.

## Frontend

A static React + Vite + shadcn app on GitHub Pages that talks only to the Worker and stores everything else in localStorage.

- **Routes (HashRouter):** `/#/` today, `/#/archive` the calendar of past days, `/#/<YYYY-MM-DD>` one archive puzzle, `/#/about` rules and attribution.
- **localStorage, per puzzle date:** guesses in order, best near miss per slot, revealed slots, solved yes/no, final score. Also the anonymous player ID (random UUID), streak, stats, and settings (colorblind mode, theme). Every read and write is wrapped in try/catch so a blocked or empty storage still lets the game load.
- **Game state is rebuilt from the guess list.** On reload the client replays stored guess results, so there's one source of truth.
- **API client:** one small module with the four calls, typed from a shared `api-types.ts` that the Worker also imports.
- **UI strings** live in one Macedonian strings file, not inline in components. This is the "keep it open for Serbian" rule.
- **Footer:** "Содржина од Википедија, CC BY-SA" with the article link after solving, "Not affiliated with Wikipedia", and one line saying anonymous guesses are recorded to improve the game.

## Deployment and operations

One public GitHub monorepo, three GitHub Actions workflows, and one manual step every \~6 weeks: running the pipeline.

**Repo layout:**

- `pipeline/` Python CLI (dump parsing, CLASSLA, fastText, schedule, KV upload). Outputs gitignored.
- `worker/` Cloudflare Worker (Hono, `wrangler.toml`).
- `web/` React + Vite + shadcn app.
- `shared/` `api-types.ts` and the function-word list, used by both web and worker.

**Workflows:**

| Workflow | Trigger | Does |
| --- | --- | --- |
| `deploy-web` | Push to `main` touching `web/` or `shared/` | Builds Vite with base path `/wikishto/` and publishes to GitHub Pages |
| `deploy-worker` | Push to `main` touching `worker/` or `shared/` | Runs `wrangler deploy` with a `CLOUDFLARE_API_TOKEN` secret |
| `schedule-check` | Weekly cron | Asks the Worker's `GET /health` how many future dates exist in KV; opens a GitHub issue if fewer than 14 |

**Your routine:** when the issue appears (or every \~6 weeks), run the pipeline for the next 60 days, skim the review CSV, and upload. The Worker releases each puzzle at Skopje midnight on its own.

## Logging and privacy

The Worker writes one row per guess and one per solve to D1, tied to a random player ID and nothing that identifies a person.

| Table | Columns |
| --- | --- |
| `guesses` | puzzle date, player ID, guess number, normalized guess, result (`hit`, `near`, `miss`, `unknown`, `invalid`), exact-hit count, best near-miss similarity, timestamp |
| `solves` | puzzle date, player ID, total guesses, % revealed (sent by the client), whether it was played as today's puzzle, timestamp |

- **Never stored:** IP address, user agent, location.
- **Player ID:** a random UUID created in the browser. Clearing storage makes a new one.
- **Notice:** one footer line that anonymous guesses are recorded to improve the game. North Macedonia's data protection law is GDPR-aligned; this is not legal advice, so check it before scaling or monetizing.
- **Free-tier headroom:** one D1 write per guess, so roughly 100k guesses/day before hitting the free write limit.

## Soft launch and tuning

Two weeks with 5–15 friends on the `github.io` URL, then retune from the logs before any public launch.

Saved D1 queries to run weekly:

- **Solve rate and median guesses** per puzzle. Too hard or too easy shows up here first.
- **Near-miss usefulness:** guesses whose near misses lit up many slots but were followed by no related guesses. That points at thresholds that are too loose, especially for function words.
- **Unknown-word rate** and the most common rejected guesses. These reveal vocabulary gaps or normalization bugs.
- **Drop-off:** players with guesses but no solve, and the guess number where they stopped.

Knobs to turn, cheapest first: thresholds and numeric ranges (Worker config), article length (pipeline), the pageviews cutoff for the pool (pipeline).

- [ ] Pipeline size test on 10 articles
- [ ] Pick 14 days of puzzles and upload
- [ ] Invite testers
- [ ] Week 1 query review and retune
- [ ] Week 2 query review, go/no-go for public launch

## Out of scope for the MVP

- **Serbian:** a second language with Cyrillic and Latin scripts. The MVP only keeps strings in one file and `mk` in KV key names so this stays possible.
- **Image share card** for social posts.
- **Custom domain** (e.g. `wikishto.com`), once the game proves useful. Moving the Worker to `api.<domain>` also removes CORS.
- **Give-up button and hints.** Add only if logs show people quitting.
- **Accounts, leaderboards, cross-device sync.**
- **Stats export** ("copy my stats"), if players ask.
