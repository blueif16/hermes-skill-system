# Hermes coupling part — tracked-skill-systems registry + DEFINE/OBSERVE/OPTIMIZE split
_status: IMPLEMENTED 2026-06-18 — Part A (registry + OBSERVE) + the git-is-the-log reconciliation shipped (`skillsys(hermes-skill-system)`, feat/define-observe-registry). This doc is the design record; see SKILL.md / init.md / observe.md for the result._
_provenance: conversation 2026-06-18 (user reframe) + `research/agent-memory-without-bloat-2026-06-18.md` (Library Drift, Claude-Code memory, git-as-memory). This doc is the spec the next session builds from._

## The reframe (why this exists)
Hermes was conflating two jobs. Split them:
1. **Hermes is a DOMAIN ENGINE for skill-CONTENT optimization — not a global policy and not an architecture editor.** It fires only when we are actively improving a tracked skill system: **add skills · add classifiers/routing · raise skill quality.** Architecture changes stay **human/manual** — the loop never touches the frame.
2. **Everywhere else (general dev) uses NO Hermes** — just status memory (git history + native memory), fine to run on pi. Hermes is invoked, not ambient.

Why the boundary holds (evidence): Library Drift (arXiv 2605.19576) — fully autonomous skill *authoring* scores **+0.0pp** vs **+16.2pp** human-curated; autonomy only recovers value when the **architecture/meta-skill is frozen** and the loop optimizes *content* under a **judge + a hard cap + retirement**. So: freeze the frame, automate the content. Hermes IS that meta-skill.

## The two coupled parts

### Part A — DEFINE + OBSERVE (the NEW coupling; always-on, low-touch)
A **registry of the skill systems we track.** Generalizes today's single per-repo `.agents/skill-system-map.md` (one system) to **many tracked systems** (we have all kinds). For each tracked system, the registry records:
- `id` — stable name (also the commit scope key).
- `location` — repo/path of the skill set + its orchestrator/workflow.
- `does` — what it produces (its input → output).
- `criteria` — pointer to its per-node quality fixture (the bar).
- `judge` — the separate LM/config that judges its output quality (see Part B).
- `status` — a *pointer*, not a copy: "run `git log --grep '^skillsys(<id>)'` + the system's native-memory notes." (Don't duplicate history into the registry — exclusion list: never store what `git log` already holds.)

**OBSERVE mode = passive.** Hermes watches status (git + native memory) and answers "what systems exist, and where does each stand?" It drives **no** changes in this mode. This is the part to author next session.

### Part B — OPTIMIZE (the existing loop; invoked, autonomous-ish)
When actively improving a tracked system, run the existing **capture → route → edit → verify → judge → approve → commit** loop (`references/operate.md` + `references/node-validation-loop.md`), scoped to skill-content only, judged by **that system's** judge against **its** I/O bar.
- The **judge = a pre-commit review gate** (the imti.co pattern): an adversarial sub-agent reviews the exact diff and must emit a CLEAN verdict before the change is accepted — **mechanical AND calibrated** (a real defect at file:line, not theatre). This is the "separate LM to judge quality" the user wants; node-validation-loop's independent-judge already is this.
- The human approve-gate remains (law 3); the human is the eye on heavy/borderline calls.
- Governance to add (Library Drift "Ratchet"): a per-system **skill cap** + **retirement by measured contribution**, so the library can't drift/bloat.

## Commit marker (resolves the "skillsys feels weird globally" unease)
- **Global git workflow stays generic** (`feat/fix/refactor/chore`) — `skillsys` is NOT a universal type.
- **Hermes owns its optimization-commit marker internally**, scoped per tracked system: `skillsys(<system-id>): <rule>` with `Why:/Lesson:/Rejected:/Verify:/Doc:` git trailers. The registry maps a commit's scope → which system. Its only job: keep optimization commits filterable from product commits *inside that system's repo*. "Covers multi-front" is handled by the **registry + scope**, not a coarse global type.
- Retrieval (the optimization memory): `git log --grep '^skillsys(<id>)'`, `--pretty=...%(trailers:key=Lesson)`, `-S`/`-L` for invariant/region evolution. `scripts/review-edits.sh` is the OBSERVE-mode change view.

## Memory division (settled this session — for reference)
- **git** = episodic ("what changed, when, why, what we rejected") — append-only, queried; never loaded eagerly.
- **native memory** (`~/.claude/projects/<repo>/memory/`) = the Claude-Code orchestrator's auto-recalled reflexes + **router** (lightweight identifiers pointing at git + `.agents/`). Machine-local is FINE — the optimize loop runs only inside Claude Code on good models; **memory never migrates to pi**.
- **`.agents/` (in-repo, committed)** = the semantic layer read by spawned diagnosis/judge subagents; versions in lockstep with the skills it describes. In-repo for git-lockstep + subagent-readability + shareability — NOT because pi needs it (it doesn't).
- **status** = working memory, separate, overwrite-lean — not a Hermes artifact.
- **What migrates to pi = ONLY the finished, optimized skills/schemas/workflow.** Memory is optimization fuel, consumed Claude-Code-side.

## Open questions for next session (decide while implementing)
1. Registry file: shape + location. One `.agents/tracked-systems.md` (or `.json`)? Per-repo, or one global index linking per-system maps?
2. How OBSERVE pulls status without loading everything (git query recipes + native-memory recall as the router).
3. Registration: how a skill system gets added to the registry (manual entry vs an INIT-style scan per system).
4. Judge setup per system: where the judge LM/config + the criteria bar live; how the pre-commit gate is wired.
5. Ratchet: the cap number + the "measured contribution" retirement metric per system.
6. How DEFINE/OBSERVE/OPTIMIZE present in the skill — modes/sections of `SKILL.md`, reusing operate.md/init.md/node-validation-loop.md.

## Next-session task (single occurrence)
Implement Part A (the tracked-systems registry + OBSERVE mode) and wire the DEFINE/OBSERVE/OPTIMIZE split into `hermes-skill-system/SKILL.md` (+ a `references/` file if it earns one), following `agentic-prompt-design`. Part B already largely exists (operate + node-validation-loop); add the per-system judge wiring + the Ratchet cap/retirement. One `skillsys(hermes-skill-system)` commit per coherent unit, human-approved.
