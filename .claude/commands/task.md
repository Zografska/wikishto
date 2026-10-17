---
description: Run one task brief from docs/briefs
argument-hint: <brief id, e.g. P3.2>
---
Run brief $ARGUMENTS.

1. Read `docs/briefs/$ARGUMENTS.md` and the last 30 lines of `docs/STATUS.md`. Nothing else yet.
2. If the brief's **Depends** briefs are not marked done in STATUS.md, stop and say which are missing.
3. Follow "How you work" in CLAUDE.md exactly. Read only the files in the brief's **Read** list.
4. End with the final message format from CLAUDE.md.
