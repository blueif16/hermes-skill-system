---
name: hermes-skill-system
description: Set up and continuously evolve a skill/agent system the disciplined way. INIT maps the whole system (every skill + the workflow that orchestrates them + which node relies on what); OPERATE turns a spotted flaw into one atomic, revertible change via capture→route→edit→verify→commit; CONSOLIDATE cleans drift on demand. Use when you spot a flaw in a skill or in the workflow, when a finding recurs across runs, when bootstrapping the convention into a repo, or when reviewing/consolidating recent edits. The human is the quality eye; every edit must generalize across ALL future runs — never hard-code one case, never write reward-hackable tests.
version: 0.1.0
author: animation-test (informed by Nous Research "Hermes Agent" research, 2026-06-08)
metadata:
  hermes:
    tags: [meta, skill-system, self-improvement, governance, workflow]
    related_skills: [transform-workflow-to-pi, capability-registry-harness, capability-gap-filler]
---

# hermes-skill-system

The method for stewarding a skill system that produces real artifacts. It does **not** try to grade those artifacts — **the human is the eye**. Its whole job is to make every *change to the system* land in the right place, generalize, and stay trackable.

## When to use
- You (the human) spotted a flaw, or a wave/node misbehaved, or a `pipelineFindings`-style finding recurred across runs.
- You're standing up the convention in a repo for the first time → **INIT**.
- You want to see / clean up everything that changed recently → **CONSOLIDATE** + `scripts/review-edits.sh`.

**Do NOT** use it to judge a rendered artifact, predict next outputs, or write pass/fail tests. It governs edits to the *system*, not the product.

## The model — one orchestrated system, mapped completely
This skill system is **not a pile of skills**; it's a workflow that orchestrates skills. A central orchestrator (here: `.claude/workflows/lesson-build.js`) calls each node, and each node reads part of the skill system. So:
- The **map records everything** — skills, the orchestrator/workflow file(s), nodes, subagents, the kits, the capability registry, the governing CLAUDE.md, and *which node relies on what*. Not just skills.
- There is **no precedence score** and **no fixed data model**. Everything in the map is *needed* — ranking it is meaningless. The map is free-form Markdown with notes.
- Setup = the **INIT** command (`references/init.md`): "what is our skill system, and what workflow orchestrates it?" → `<repo>/.agents/skill-system-map.md`.
- The map is also the **diagnostic context surface**. Beyond composition it records **what is responsible for what**, **where each run's real logs + artifacts live** (so a diagnosis reads actual evidence, not a guess), and a running **diagnostics log** of what past fixes concluded. Read together with the live problem, the map gives the agent the *top candidate of what to fix*.
- The map **evolves and gets more certain with every run** — append responsibilities, notes, and diagnostics as you learn them; never freeze it. A stale map is the one real failure mode of this whole method.

## The laws (read these every time — they are the point)
1. **Diagnose from real evidence, not guesses.** Before routing any fix, read together: the **user-surface problem**, the **current skill composition**, the **workflow composition**, and the **actual runtime logs + artifacts the run produced** (the map's observability section says where they live — node logs, run status, raw transcripts, the structured returns, and the product artifact itself). The map *and* the live problem, side by side, point at the top candidate to fix. If the map feels stale or thin, refresh it (INIT) first.
2. **Generalize or don't ship.** Every edit must be reliable across **all** future instances and runs. Never solve one specific case by hard-coding it. A fix that only helps the lesson in front of you is a bug, not a lesson learned.
3. **Verify by intent, never by hard-coded test.** LLM-written tests are untrustworthy and reward-hackable. Verification is an *instruction the next session carries out* — what a future run should look for — never a prediction of the exact next output. **The human is the eye for visual artifacts**; the model does not self-grade visuals. (A model+human judge loop for *verbal/plan* phases is a future extension — not in this version.)
4. **Prefer fixing the chain over fixing one skill.** The orchestrator's own rule: *"Improve a wave by editing its SKILL; improve the chain by editing this [workflow] file."* When a flaw is about coordination, wiring, or how nodes hand off, edit the **workflow/orchestrator** before patching a single skill. This is the only global precedence rule — formal knowledge, not a number in the map.
5. **One canonical home, no duplication.** Before writing, grep for the rule already half-stated elsewhere; refine it in place. Encode at the altitude where the right node will actually reload it.
6. **Smallest durable edit.** Patch a section > add a `references/` file > create a new skill. New skills need a real, named gap.
7. **Every change is one atomic, revertible commit.** `skillsys(<owner>): <rule>` with why/lesson/verify in the body. One lesson = one commit, so revert is surgical and a time-span review is just `git log`. **Record it** in the map's diagnostics log so the map gets more certain.
8. **Immediate, on demand — no timers.** Fix flaws the moment they're spotted; consolidate when it feels messy or the map shows drift. No 30/90-day cadence, no background daemon.
9. **Concise.** Don't add unrelated info, checks, or scaffolding. A lean system is a usable one.

## The two procedures
- **INIT / refresh the map** → `references/init.md`. Run once per repo and whenever the system's shape changes (new node, new skill, re-wired orchestrator). INIT also **injects the ambient stewardship hook into the project's CLAUDE.md/AGENTS.md** and installs the `skillsys(...)` commit convention — so the project stays aware of the pattern and user feedback auto-triggers it.
- **OPERATE — the daily loop** → `references/operate.md`: capture → route → edit → verify → commit.
- **CONSOLIDATE — on demand** → `references/consolidate.md`: merge duplicated/conflicting guidance into the canonical owner; keep skills inside their disclosure budget.

## Tooling
- `scripts/review-edits.sh [since] [until]` — every `skillsys(...)` commit in a span, grouped, with its why-line. This is the periodic review.
- The per-repo map lives at `<repo>/.agents/skill-system-map.md` (data); this skill is the method (portable across repos).
