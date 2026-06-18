# CONSOLIDATE — on demand, never on a timer

Run when it feels messy, when INIT/refresh shows drift, or when a skill outgrew its disclosure budget. Fast editing's tax is paid here — deliberately, by a human-triggered pass, not a background daemon.

## What to do
- **De-duplicate:** the same rule stated in two+ owners → keep the canonical one (per the map), cross-reference or remove the rest. (Git is the archive — a tracked removal commit, revert restores.)
- **Resolve conflicts:** two owners that contradict → fix at the governing owner (a law/the chain over a single skill); leave a note in the map.
- **Respect the budget:** a SKILL.md that ballooned → split detail into `references/`, keep the body lean so the discovery surface stays small.
- **Sharpen the map:** as responsibilities become certain across runs, tighten their one-liners.
- **Regenerate the open-threads block (the out-of-band "dream"):** this is where the registry's per-system open-threads block is rebuilt — **drop** any thread now fully absorbed into a rule or skill (git keeps the trail via its `skillsys(<id>)` commits; nothing is lost), **keep** only what is still unresolved or recurring. The block must shrink here, never grow; if it reads like a log, it has drifted back into a ledger — cut it.

## Rules
- **One atomic commit per move:** `skillsys(<id>): consolidate <what>`, revertible.
- **Generalize** — consolidation must never hard-code or narrow a rule.
- **Concise** — the goal is *less* surface, not more. Don't invent structure or a data model.
- No `.archive/` dir, no scores, no timers. Removal is a tracked commit; recovery is `git revert`.
