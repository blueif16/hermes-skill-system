---
name: hermes-skill-system
description: Set up and continuously evolve a skill/agent system the disciplined way. Tracks MANY skill systems per project in a registry (`.agents/tracked-systems.md`). Three modes — DEFINE maps each tracked system (every skill + the orchestrating workflow + which node relies on what) and registers it; OBSERVE answers "what do we track, and where does each stand?" from the registry + git, changing nothing; OPTIMIZE turns a spotted flaw into one atomic, revertible `skillsys(<id>)` change via capture→route→edit→verify→approve→commit (human approves before it lands, decides whether to rerun after). The iteration log is git, not a file. Use when you spot a flaw in a skill or workflow, when a finding recurs across runs, when bootstrapping the convention into a repo, or when reviewing/consolidating recent edits. The human is the quality eye; every edit must generalize across ALL future runs — never hard-code one case, never write reward-hackable tests.
version: 0.2.0
author: animation-test (informed by Nous Research "Hermes Agent" research, 2026-06-08)
metadata:
  hermes:
    tags: [meta, skill-system, self-improvement, governance, workflow]
    related_skills: [transform-workflow-to-pi, capability-registry-harness, capability-gap-filler]
---

# hermes-skill-system

The method for stewarding the skill systems that produce real artifacts. It does **not** grade those artifacts — **the human is the eye**. Its whole job: make every *change to a system* land in the right place, generalize across all future runs, and stay trackable as one atomic, revertible commit.

## When to use
- Spotted a flaw, a node misbehaved, or a finding recurred → **OPTIMIZE**.
- Standing the convention up in a repo, or adding / re-shaping a tracked system → **DEFINE**.
- "What do we track, and where does each stand?" → **OBSERVE**. Cleaning recent drift → CONSOLIDATE + `scripts/review-edits.sh`.

**Do NOT** use it to judge a rendered artifact, predict next outputs, or write pass/fail tests — it governs edits to the *system*, not the product.

## The model — a registry of tracked systems, each mapped completely
A project may steward **many** skill systems. **DEFINE** registers each in a per-project **registry** (`<repo>/.agents/tracked-systems.md`) — one lean row per system: what it does, pointers to its map / criteria / judge, its git iteration-log pointer, and a tiny open-threads block. The registry is the index **OBSERVE** reads. The iteration log itself is **git** (`skillsys(<id>)` commits) — the registry points at it, never copies it (most rot is duplicating what `git log` already holds).

Each tracked system is a **workflow that orchestrates skills**, not a pile of skills. Per system, the **map** records *everything* — skills, the orchestrator/workflow file(s), nodes, subagents, kits, the capability registry, the governing `CLAUDE.md`, and **which node relies on what** — with no scores and no rigid schema (free-form Markdown + notes). It is also the **diagnostic surface**: what is responsible for what, and where each run's real logs + artifacts live (so a diagnosis reads evidence, not a guess). **Alongside it, a per-node criteria fixture** holds the human-judged "what good output looks like" bar — the standing reference the eye judges every run against; it is a JUDGING fixture, **never injected into the producing node's prompt** (that teaches-to-the-test). Both **get more certain with every run**; a stale map is the one real failure mode of this method.

## The laws (read these every time — they are the point)
1. **Diagnose from real evidence, not guesses.** Read the user-surface problem, the skill + workflow composition, and the run's actual logs + artifacts *together* before routing; the map + the live problem name the top candidate. Stale/thin map → refresh (DEFINE) first. *(Craft: `references/debug-tuning-loop.md`.)*
2. **Generalize or don't ship.** Every edit must hold across **all** future runs. A fix that only helps the case in front of you is a bug, not a lesson — never hard-code one instance.
3. **The human gates the change in and out — verify by intent, never a hard-coded test.** *Before commit:* present the diff/plan, get an explicit yes (always for a structural change — new skill/doc, new/reordered wave, changed node contract; atomic-revertibility is not a substitute for a yes). *After commit:* decide *with the human* whether to rerun to re-validate — and the rerun is the **suffix fixed by the FIRST changed node** (resume there, reuse every unchanged upstream artifact). In between, verification is an instruction the next run carries out, never a prediction of the exact output; LLM-written tests are reward-hackable. **The human is the eye for visual artifacts.** *(`references/operate.md`.)*
4. **Prefer fixing the chain over one skill; a declared contract over a reactive guard.** Coordination / wiring / hand-off flaws → edit the workflow/orchestrator, not a single skill. Many "flaws" are an end-product that was never specified — encode it up front as an **Output Contract** (artifacts + owned paths the executor verifies) rather than detect-and-retry downstream. *(`references/operate.md`; `transform-workflow-to-pi`.)*
5. **One canonical home, no duplication.** Grep for the rule already half-stated elsewhere and refine it *in place*, at the altitude where the right node will reload it.
6. **Smallest durable edit.** Patch a section > add a `references/` file > create a new skill. A new skill needs a real, named gap.
7. **Every change is one atomic, revertible `skillsys(<id>)` commit** — `why / lesson / rejected / verify` trailers, one lesson per commit. **The commit IS the record:** the iteration log is git, queried by `<id>` (`git log --grep '^skillsys(<id>)'`). The only conditional in-file write is one line in the registry's **open-threads** block when a pattern stays unresolved — never an in-file diagnostics ledger (that duplicates git and rots). *(`references/operate.md` steps 6–7.)*
8. **Immediate, on demand — no timers.** Fix flaws the moment they're spotted; consolidate when it feels messy or the registry drifts. No 30/90-day cadence, no background daemon.
9. **Concise.** No unrelated info, checks, or scaffolding — this skill included. A lean system is a usable one.
10. **Self-contained by default; promote only to a skill that ALREADY exists upstream.** A product self-contains its own skills/code/content — edit them directly in place; that is the DEFAULT, not a way-station to promotion. Promotion applies ONLY when an upstream canonical skill ALREADY exists that owns the *method* at issue: you improve that shared method — you never export a product-local skill into a new global one (standing up a NEW global skill is a deliberate DEFINE act needing a real named gap per law 6, never a promotion goal). When you do promote: build + VERIFY the fix in the product locally first, promote upstream only after a real run proves it, made robust for ANY environment — never author an unverified change upstream, never patch/hack. *(`references/debug-tuning-loop.md`.)*

## The three modes
- **DEFINE — register & map** → `references/init.md`. Write the registry + each system's map + criteria; **inject the ambient stewardship hook** into the project's `CLAUDE.md`/`AGENTS.md`; install the `skillsys(<id>)` commit convention. Run at setup and whenever a system is added or its shape changes (new node, new skill, re-wired orchestrator).
- **OBSERVE — passive status, drives no change** → `references/observe.md`. Answers "what do we track, and where does each stand?" from the registry + git + native memory (the router), *without* loading the whole `.agents/` tree. It never edits, commits, or reruns; a surfaced flaw hands off to OPTIMIZE.
- **OPTIMIZE — turn one flaw into one durable change** → `references/operate.md`: capture → route → edit → verify → approve → commit → record → rerun-decision. For executor-produced systems, `references/node-validation-loop.md` is the clean-room single-node re-run + independent-judge protocol, and `references/debug-tuning-loop.md` is the evidence-first root-cause craft inside it. **Companion Mode** (continuous dev-time validation; defined in `transform-workflow-to-pi`) and **CONSOLIDATE** (`references/consolidate.md` — on-demand drift cleanup + open-threads regeneration) are part of OPTIMIZE.
  - Standing prerequisite before removing verify nodes for Companion Mode: **a verify node verifies + stabilizes, it NEVER creates a key artifact** — if one does, split it into a producer + a verifier first (law 4 applied to roles).

## Tooling
- `scripts/review-edits.sh [since] [until]` — every `skillsys(...)` commit in a span, grouped, with its why-line. The periodic review and OBSERVE's change view.
- Data lives per-repo under `<repo>/.agents/` (the registry + per-system maps + criteria); this skill is the portable **method**.

## Provenance — why this design
Every law traces to a multi-source study of Nous Research's **Hermes Agent**: `references/hermes-agent-research-2026-06-08.md` (the full record — what we **kept**: progressive disclosure, patch>edit>new, one-canonical-home, benchmarks-as-gates, no-silent-learning; and what we **dropped** for a human-in-the-loop shop: Curator timers, autonomous provenance splits, reward-hackable auto-tests, GEPA-style model judging of visuals). The memory design — **git as the iteration log**, the exclusion list, the capped registry + open-threads block, and *autonomy degrades without curation + a cap* — traces to `research/agent-memory-without-bloat-2026-06-18.md`. Read these when judging whether a change to *this method* is sound.
