# hermes-skill-system

A [Claude Code](https://claude.com/claude-code) **skill** for setting up and continuously evolving a
skill/agent system the disciplined way. It does **not** grade the artifacts a system produces — the
human is the eye. Its whole job is to make every *change to the system* land in the right place,
generalize across all future runs, and stay trackable as one atomic, revertible commit.

> Informed by Nous Research's "Hermes Agent" research (2026-06-08).

## The model — a registry of tracked systems, each mapped completely

A project may steward **many** skill systems. They're indexed in a per-project **registry**
(`<repo>/.agents/tracked-systems.md`) — one lean row each: what it does, pointers to its map /
criteria / judge, its git iteration-log pointer, and a tiny open-threads block. The iteration log is
**git** (`skillsys(<id>)` commits) — the registry points at it, never copies it.

Each tracked system is **not a pile of skills**; it's a workflow that orchestrates skills. A central
orchestrator (e.g. `.claude/workflows/lesson-build.js`) calls each node, and each node reads part of
the system. So the per-system **map records everything** — skills, the orchestrator/workflow file(s),
nodes, subagents, kits, the capability registry, the governing `CLAUDE.md`, and *which node relies on
what* — and is also the **diagnostic surface** (what is responsible for what, where each run's real
logs + artifacts live). It **gets more certain with every run** — a stale map is the one real failure
mode of this method.

## The three modes

| Mode | File | When |
| --- | --- | --- |
| **DEFINE** — register & map | `references/init.md` | Standing the pattern up in a repo, adding a tracked system, or when a system's shape changes. Writes the registry + each system's map/criteria, injects the ambient stewardship hook into `CLAUDE.md`/`AGENTS.md`, and installs the `skillsys(<id>)` convention. |
| **OBSERVE** — passive status | `references/observe.md` | "What do we track, and where does each stand?" Reads the registry + git; drives no change. A surfaced flaw hands off to OPTIMIZE. |
| **OPTIMIZE** — the daily loop | `references/operate.md` (+ `node-validation-loop.md`, `debug-tuning-loop.md`) | A flaw was spotted, a node misbehaved, or a finding recurred. capture → route → edit → verify → approve → commit → rerun-decision. `CONSOLIDATE` (`references/consolidate.md`) is its on-demand drift cleanup. |

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
7. **Every change is one atomic, revertible commit** — `skillsys(<id>): <rule>` with
   why/lesson/rejected/verify trailers. The commit IS the record: the iteration log is git, not a file.
8. **Immediate, on demand — no timers.** Fix flaws the moment they're spotted.
9. **Concise.** A lean system is a usable one.
10. **Shared/upstream changes are local-first, then promoted** — build + verify a shared-component fix in
    the product, promote upstream only after a real run proves it; never author unverified upstream.

## Contents

| Path | What it is |
| --- | --- |
| `SKILL.md` | The skill — the model, the laws, the three modes. |
| `references/init.md` | DEFINE: build/refresh the registry + each system's map/criteria and inject the ambient hook. |
| `references/observe.md` | OBSERVE: passive "what do we track, where does each stand?" read; drives no change. |
| `references/operate.md` | OPTIMIZE: the capture → route → edit → verify → approve → commit → rerun loop. |
| `references/node-validation-loop.md` | OPTIMIZE for executor-produced systems: clean-room single-node re-run + independent judge. |
| `references/debug-tuning-loop.md` | The evidence-first root-cause craft inside the loop. |
| `references/consolidate.md` | CONSOLIDATE: merge drift into the canonical owner; regenerate the open-threads block. |
| `scripts/review-edits.sh` | Lists every `skillsys(...)` commit in a span, grouped, with its why-line — the periodic review. |
| `references/hermes-agent-research-2026-06-08.md` | The full multi-source research brief on Hermes Agent — the provenance for the laws. |
| `research/agent-memory-without-bloat-2026-06-18.md` | The memory-design brief — git-as-log, exclusion list, capped registry, autonomy-needs-curation. |

The per-repo registry + maps (`<repo>/.agents/`) are **data** that live in each consuming
repo; this repo is the portable **method**.

## Provenance — the Hermes research & how we extracted this

This skill is a deliberate adaptation of **Nous Research's "Hermes Agent"** — the self-improving agent
whose differentiator is a closed loop that writes, prunes, and *offline-evolves* its own `SKILL.md`
files. On **2026-06-08** we ran a multi-source study of it and distilled the laws above. The full
record — verbatim mechanisms, exact thresholds, ready-to-paste scaffolds, a practitioner reality-check,
and a practice→source table — lives in
[`references/hermes-agent-research-2026-06-08.md`](references/hermes-agent-research-2026-06-08.md).
Read it when deciding whether a proposed change to *this method* is sound.

**Sources (multi-source fan-out).** The Hermes docs + GitHub repos (`hermes-agent`,
`hermes-agent-self-evolution`) + the GEPA paper (ICLR 2026) `[web/Exa]`; 14 curated creator
walkthroughs ingested into a local transcript RAG — Akshay Pachaar, NVIDIA Developer, NetworkChuck,
Weaviate "GEPA Explained", SkillOpt, Google Antigravity, DSPy/GEPA `[YouTube]`; and practitioner
reports across r/AI_Agents, r/LocalLLaMA, r/AgentsOfAI, r/LLMDevs `[Reddit]`.

**What Hermes does (the subject we mined).** Skills = procedural memory under `~/.hermes/skills/`,
loaded by *progressive disclosure* (only name+description at session start, full body on match); a
`skill_manage` CRUD tool (prefer `patch`); a background **Curator** (stale→archive→umbrella-consolidate,
never deletes, snapshots first); **GEPA** offline trace-driven evolution, gated on tests/size/semantics
and shipped as PRs not commits; a memory-vs-skills split (facts vs procedures); and "no silent
learning" (the agent proposes, the human approves).

**What we KEPT.** Progressive disclosure · patch > edit > new-skill · one-canonical-home / no
duplication · "benchmarks are gates, not fitness" · no silent learning (propose→approve→commit) ·
git-revert as the archive.

**What we deliberately DROPPED — and why.** This is the ledger for future iteration:

| Hermes mechanism | We dropped it because | What we do instead |
| --- | --- | --- |
| 30/90-day Curator timers + idle daemon | we iterate at dev speed | fix the moment a flaw is spotted; consolidate on demand |
| agent-vs-user provenance split | every edit here is human-approved | one human-reviewed `skillsys()` commit per lesson |
| reward-hackable auto-tests | LLM-written tests are untrustworthy | **verify by intent** for the next session; human is the eye for visuals |
| precedence *scores* in the map | one orchestrated system — everything is needed, ranking is meaningless | the single formal rule "fix the chain over a single skill"; map keeps notes, no scores |
| GEPA-style *model* judging of visual artifacts | the model can't be trusted on visuals | human eye for visuals; a model+human judge loop is a **future extension**, scoped to verbal/plan phases only |

When revisiting a law, check it against the brief to see whether it's a Hermes principle we adopted, an
inversion we chose for velocity, or something still open (the deferred verbal/plan judge loop).

## License

MIT
