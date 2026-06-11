# INIT — map the whole skill system

Produce / refresh `<repo>/.agents/skill-system-map.md`: a free-form, notes-friendly inventory that answers **"what is our skill system, and what workflow orchestrates it?"** It records **everything**, with **no scores and no rigid schema**.

## What to record
1. **Orchestrator(s) / workflow file(s).** The file that drives the run (e.g. `.claude/workflows/lesson-build.js`) and any production executor (e.g. `pi-runner/`). Note its phases/waves in order, and the shared discipline preamble it injects into every node.
2. **Nodes / waves / subagents.** Each step the orchestrator spawns, in order, with a one-line job.
3. **The wiring — which node relies on what.** For each node: the skill(s) it reads, the docs/registry it consults, the artifacts it writes. This is the most valuable column; it's how routing finds the owner.
4. **The skills**, grouped by where they're owned (this repo, a shared kit, a global skill). One line each.
5. **The governing constitution** (e.g. `CLAUDE.md`) and **architecture docs** — they are owners too (laws and facts often belong here, not in a wave skill).
6. **The capability/asset registry** if there is one (e.g. `.agents/CAPABILITIES.md` + a generated catalog) — note it's drift-gated/generated where applicable.
7. **Responsibilities — what is responsible for what.** One crisp line per owner (node, skill, doc, the orchestrator). This is the column the diagnostic loop reads to assign a problem to an owner — keep it sharp.
8. **Runtime observability — where a run leaves evidence.** This is what makes diagnosis read *real data* instead of guessing. Record every place a run writes: per-node logs, the run-status file, the raw agent transcripts, the aggregated structured returns/findings, and the product artifacts (renders, contact sheets, manifests, gate reports, verification docs) — both the dev executor and any production executor. At minimum, **every intermediate artifact + log path** so a diagnosis always has context to pull.
9. **Diagnostics log — what past diagnoses concluded.** A short append-only section. Each entry: date — owner — the rule/fix — its `skillsys(...)` commit. Seed it with any existing post-mortem/fix-log docs. This is how the map **gets more certain with every run** — repeat-flaws become visible and the next diagnosis starts ahead.

10. **Per-node output expectations (acceptance criteria) — a SEPARATE fixture file alongside this map** (e.g. `<repo>/.agents/skill-system-criteria.md`), one entry per producing node, (re)generatable by a per-node criteria-drafting workflow — typically seeded when the workflow's harness is created (the `transform-workflow-to-pi` adoption step) and MAINTAINED by this loop (seed it here if a repo adopted hermes without it). For each producing node, a short STANDING rubric of what a *good* output artifact looks like — the human-judged quality bar, distinct from the mechanical Output Contract (which only checks the artifact EXISTS in its lane). 3–8 observable expectations per node ("`pedagogy.md` names the whole a relation decomposes and plans complete utterances"; "the rendered MP4's teaching object fills the frame and a split reads at a glance"), each phrased to GENERALIZE across all future lessons (never hard-code the one in front of you), plus the node's known failure modes as red flags. This is BOTH the improvement target (sharpen it as the system matures) AND the **reference the human's eye judges every future run against**. It is NOT an auto-graded test (law 3) — expectations a human checks, never a reward-hackable checklist. **It is a JUDGING FIXTURE, NOT a node input: NEVER inject these criteria into the producing node's prompt.** Doing so makes the executor teach-to-the-test (it optimizes to the rubric, not to the skill) and voids the clean-room signal that tells you whether the SKILL ITSELF — not the rubric — produces good output. The criteria live in THAT fixture file (not embedded in this map, and not inside any node prompt), are read by the human/steward to judge a run and to aim the next skill edit, and never travel into the run that is being judged. Seed from each node's skill ("Wave output" / audit sections) + the real artifacts on disk; sharpen it every run alongside the Diagnostics log.

## How to gather it (no guessing)
- Read the orchestrator file: its `meta.phases`, the node prompts, and any `SK.*`/skill-path map give you nodes→skills directly.
- Read the constitution (`CLAUDE.md`) "Skills" / "Skill ownership" sections for the canonical home of each skill.
- `ls` the skills dir(s) and the docs dir.
- Where a skill is owned in another repo/kit, record the owning location (don't copy it in).

## Format
Plain Markdown. Sections + tables or bullets, whatever carries it. **Notes are encouraged** ("this node also owns the intro card", "mechanical, no skill"). **Do not** add precedence numbers, status scores, or a fixed JSON shape — the moment it becomes a strict data model it stops being honest and starts being gamed. If you want to flag something, write a note.

## Refresh
Re-run when the system's shape changes (a node added, a skill split, the orchestrator re-wired). The map is cheap; keeping it true is what makes routing (OPERATE step 2) reliable. A stale map is the one real failure mode here — if routing ever feels wrong, refresh the map first.

## Emit the trackers + the ambient hook (first-time setup)
INIT is not just the map. When you stand the Hermesian system up in a project, leave the project **aware of the pattern** so feedback auto-triggers it without anyone re-explaining:
1. **Write the map** → `<repo>/.agents/skill-system-map.md` (above).
2. **Inject the ambient hook** into the project's agent constitution (`CLAUDE.md`, or `AGENTS.md`) — a short "Skill-system stewardship" section so every session knows the pattern is live and treats **user feedback on an artifact as a stewardship trigger**. Minimal template:
   > **## Skill-system stewardship** — We continuously evolve this skill system at dev speed. Treat any flaw, recurring finding, or user feedback on an artifact as a trigger: run the `hermes-skill-system` skill to capture→route→edit→verify→commit a durable, *generalizing* fix. Map = `.agents/skill-system-map.md`; prefer fixing the workflow over a single skill; one `skillsys(<owner>):` commit each; the human is the eye for visuals.
3. **Install the convention:** the `skillsys(<owner>): <rule>` commit format + `scripts/review-edits.sh` span review. No new infra — git is the tracker.

Keep all three concise. The whole point of the hook: nobody should ever have to say "remember to update the skills" — the project already knows, so a single line of feedback is enough to invoke the right pattern.
