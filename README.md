# hermes-skill-system

A [Claude Code](https://claude.com/claude-code) **skill** for setting up and continuously evolving a
skill/agent system the disciplined way. It does **not** grade the artifacts a system produces — the
human is the eye. Its whole job is to make every *change to the system* land in the right place,
generalize across all future runs, and stay trackable as one atomic, revertible commit.

> Informed by Nous Research's "Hermes Agent" research (2026-06-08).

## The model — one orchestrated system, mapped completely

A skill system is **not a pile of skills**; it's a workflow that orchestrates skills. A central
orchestrator (e.g. `.claude/workflows/lesson-build.js`) calls each node, and each node reads part of
the skill system. So the **map records everything** — skills, the orchestrator/workflow file(s),
nodes, subagents, kits, the capability registry, the governing `CLAUDE.md`, and *which node relies on
what*. The map is also the **diagnostic surface**: it records what is responsible for what, where each
run's real logs + artifacts live, and a running diagnostics log of what past fixes concluded. Read
together with the live problem, it points at the top candidate to fix. It **gets more certain with
every run** — a stale map is the one real failure mode of this method.

## The three procedures

| Command | File | When |
| --- | --- | --- |
| **INIT** — map the system | `references/init.md` | Once per repo, and whenever the system's shape changes (new node, new skill, re-wired orchestrator). Also injects the ambient stewardship hook into the project's `CLAUDE.md`/`AGENTS.md` and installs the `skillsys(...)` commit convention. |
| **OPERATE** — the daily loop | `references/operate.md` | A flaw was spotted, a node misbehaved, or a finding recurred. capture → route → edit → verify → commit. |
| **CONSOLIDATE** — on demand | `references/consolidate.md` | Merge duplicated/conflicting guidance into the canonical owner; keep skills inside their disclosure budget. |

## Install

This is a Claude Code skill. Make it discoverable by placing (or symlinking) the folder under your
skills directory:

```bash
ln -s "$(pwd)" ~/.claude/skills/hermes-skill-system
```

Claude Code will surface it when you spot a flaw in a skill or workflow, when a finding recurs across
runs, when bootstrapping the convention into a repo, or when reviewing/consolidating recent edits.

## The laws (the point)

1. **Diagnose from real evidence, not guesses.** Read the user-surface problem, the skill
   composition, the workflow composition, and the actual runtime logs + artifacts together.
2. **Generalize or don't ship.** Every edit must be reliable across *all* future runs. A fix that
   only helps the case in front of you is a bug, not a lesson learned.
3. **Verify by intent, never by hard-coded test.** Verification is an instruction the next session
   carries out — never a prediction of the exact next output. The human is the eye for visuals.
4. **Prefer fixing the chain over fixing one skill.** Improve a wave by editing its SKILL; improve
   the chain by editing the workflow/orchestrator.
5. **One canonical home, no duplication.** Refine the rule in place; don't restate it.
6. **Smallest durable edit.** Patch a section > add a `references/` file > create a new skill.
7. **Every change is one atomic, revertible commit** — `skillsys(<owner>): <rule>` with
   why/lesson/verify in the body. Record it in the map's diagnostics log.
8. **Immediate, on demand — no timers.** Fix flaws the moment they're spotted.
9. **Concise.** A lean system is a usable one.

## Contents

| Path | What it is |
| --- | --- |
| `SKILL.md` | The skill — the model, the laws, the three procedures. |
| `references/init.md` | INIT: build/refresh `<repo>/.agents/skill-system-map.md` and inject the ambient hook. |
| `references/operate.md` | OPERATE: the capture → route → edit → verify → commit loop. |
| `references/consolidate.md` | CONSOLIDATE: merge drift into the canonical owner. |
| `scripts/review-edits.sh` | Lists every `skillsys(...)` commit in a span, grouped, with its why-line — the periodic review. |

The per-repo map (`<repo>/.agents/skill-system-map.md`) is **data** that lives in each consuming
repo; this repo is the portable **method**.

## License

MIT
