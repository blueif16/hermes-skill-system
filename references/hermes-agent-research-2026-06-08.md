# Hermes Agent — how it builds & self-improves its skill system — research brief
_scope: 2025–2026, AI-agent lens, deep dive • generated 2026-06-08_
_source tags: **[R]**=Reddit (practitioner sentiment) • **[Y]**=YouTube/yt-rag (creator walkthroughs) • **[E]**=Exa web (docs/repos/papers). Inline citations name the specific creator/site so every claim is traceable._

## How to read this
This brief has two altitudes. **Part A** (the bulk) is the factual research: how Nous Research's **Hermes Agent** actually constructs, updates, prunes, and offline-evolves its skills — the hardcore principles, exact thresholds, best patterns, and anti-patterns, drawn from official docs + the GitHub repos + creator videos + practitioner reports. **Part B** is the bridge to *our* goal: a concrete design for making **our** lesson-pipeline skill system self-improving with **the human as the quality eye but the loop self-tracking its own advancement** — so we never have to re-remind Claude "we're improving skills." Trust levels are flagged: **docs/repo = primary**, **video = creator demonstration**, **Reddit = practitioner experience**.

> **What "Hermes Agent" is.** The self-improving AI agent by Nous Research (github.com/NousResearch/hermes-agent). Its one differentiator: a **closed learning loop** — "it creates skills from experience, improves them during use, nudges itself to persist knowledge, searches its own past conversations, and builds a deepening model of who you are across sessions" [E, hermes-agent.nousresearch.com]. Self-improvement here is **not fine-tuning** — "it means the agent writing markdown SKILL.md files when it encounters a lesson worth remembering… procedural-memory growth, not model weight modification" [E, aiskill.market]. The model is frozen; **the library of skills + memory is the moving part**. (Disambiguation: distinct from the Hermes *LLM* model line; the agent reportedly runs on whatever model you point it at — practitioners report Kimi K2.6 under the hood [R, r/AI_Agents].)

---

## TL;DR (highest-confidence, survived ≥2 sources)
1. **A skill is a `SKILL.md` markdown file = procedural memory ("how to do task X").** Memory (`MEMORY.md`/`USER.md`) is *declarative* ("facts about the user/world"). They are deliberately kept separate, both human-readable, both agent-writable, both on disk. [E docs, Y Akshay Pachaar, R LLMDevs]
2. **Progressive disclosure is the whole game.** At session start only every skill's `name`+`description` loads (~3k tokens total). The full body loads only when the task matches the description; referenced scripts load only when executed. This is the universal anti-bloat mechanism. [E docs/agentskills.io, Y Akshay/NVIDIA/Google Antigravity]
3. **Skills are crystallized struggle, created on a *tool-call* trigger — not a turn trigger.** The agent auto-proposes a skill after a complex task (5+ tool calls), after recovering from a dead end, after a user correction, or on discovering a non-trivial workflow. "Better on day 30 than day one." [E docs, Y Akshay/WorldofAI/NetworkChuck]
4. **Three nested improvement loops, increasing in cost & rigor:** (a) **in-session** `skill_manage` CRUD (prefer `patch`); (b) the **Curator** — a background, idle-gated garbage-collector that marks stale/archives/consolidates; (c) **GEPA** — an *offline* evolutionary optimizer that reads execution traces to diagnose *why* skills fail and ships improvements **as PRs, never direct commits**. [E docs+repo, Y Akshay/Weaviate]
5. **"No silent learning."** Every layer is legible and reversible: agent *proposes*, human approves/edits/rejects; Curator archives (never deletes) + snapshots; GEPA gates on tests and ships a reviewable PR. Auditability is a first-class design constraint, not an afterthought. [E aiskill.market/repo, Y NetworkChuck]
6. **The reality check [R]:** practitioners confirm the skill loop is *real and the reason to pick Hermes* (an ad-hoc task → a saved, scheduled, reusable skill with no manual authoring). The repeatedly-named weakness is **memory drift**, not the skill loop. It's also **slower/pricier on raw coding** than lean rivals (one benchmark: ~3.2× slower, ~5.5× pricier, higher tool-failure).

---

# PART A — How Hermes builds & evolves skills (the research)

## A0. The architecture in one frame
Four fixed layers, loaded into the system prompt in slot order [Y Akshay Pachaar @10:43, E dailydoseofds]:
- **Slot 1 — `SOUL.md`** = identity/persona/boundaries. Hand-authored, static, loaded whole. "The fixed frame." Everything the agent learns happens *through the lens of this identity*. If missing, a default identity is used.
- **Slot 2 — Memory** (`MEMORY.md` + `USER.md`) = declarative facts, frozen snapshot at session start.
- **Slot 3 — Skills index** = the `name`+`description` of every skill (progressive disclosure L0).
- **Slot 4 — Conversation history.**

Then four *processes* act on the skill library, in ascending cost/rigor:
1. **Runtime `skill_manage`** — the agent CRUDs skills mid-session (cheap, immediate).
2. **The Curator** — background hygiene: stale→archive→consolidate (periodic, idle-gated, LLM-assisted).
3. **GEPA self-evolution** — offline, trace-driven, gated, ships PRs (expensive, rigorous, human-merged).
4. **Bundled-skill sync + the Skills Hub** — distribution & update of shared skills without stomping local edits.

One-liner that captures the philosophy [E dailydoseofds]: *"`SOUL.md` sets the identity. The runtime loop captures experience. The Curator keeps the library clean. GEPA makes sure what's in the library actually works."*

---

## A1. Skill file anatomy & progressive disclosure
A skill is a **directory** under `~/.hermes/skills/` with a required `SKILL.md` plus optional `references/`, `templates/`, `scripts/`, `assets/`. Directory name = the install slug. [E intraview.ai source tour]

**Frontmatter fields (Hermes flavor):** `name`, `description`, `version` (semver, e.g. `1.1.0`), `author`, `license`, `platforms: [macos|linux|windows]`, and a `metadata.hermes.{tags, category, related_skills, config, requires_toolsets, requires_tools, fallback_for_toolsets, fallback_for_tools}` block, plus top-level `required_environment_variables`. A single shared reader `parse_frontmatter()` (with a line-by-line rescue path) ensures malformed YAML never silently drops a skill. [E intraview.ai, hermes docs]

**Open-standard caps (agentskills.io spec — the format Anthropic released open) [E agentskills.io/specification]:**
- `name` ≤ **64 chars**, lowercase/digits/hyphens only, no leading/trailing hyphen.
- `description` ≤ **1024 chars**, non-empty — and it must say **"what it does AND when to use it."**
- `compatibility` ≤ 500 chars; optional `license`, `metadata`, experimental `allowed-tools`.
- Body recommended **< 5000 tokens / < 500 lines**.

**The three-tier progressive disclosure (the core mechanism) [Y Akshay @15:18, E docs/agentskills.io]:**
| Level | What loads | When |
|---|---|---|
| **L0 Discovery** | `skills_list()` → `[{name, description, category}]` for **all** skills, **~3k tokens total** (~50–100 tokens/skill) | every session start |
| **L1 Activation** | `skill_view(name)` → the full SKILL.md (procedure / pitfalls / verification) | only when a task matches the description |
| **L2 Resources** | `skill_view(name, file_path)` → one `references/`/`scripts/` file | only when the body points at it / a script is executed |

> **The `description` field is the activation surface.** The skill selector matches a task to a skill *purely on `name`+`description`* — "the more precisely worded, the more reliably the skill fires" [E aiskill.market]. Because L1 loads the *entire* SKILL.md, long content **must** be split into reference files. NVIDIA frames progressive disclosure explicitly as their answer to "skill bloat": "all the skills are not always in context… a very, very strong skill manager… to explicitly avoid this" [Y NVIDIA @10:13].

**Conditional activation** controls prompt presence: `requires_toolsets`/`requires_tools` *hide* a skill when deps are absent; `fallback_for_toolsets`/`fallback_for_tools` hide it when a *premium* tool IS present (e.g. a DuckDuckGo skill only appears when there's no Firecrawl key); `platforms` hides on incompatible OS. [E intraview.ai]

---

## A2. Creation triggers & conditions — *when* a skill is born
The agent auto-creates a skill when **any** of these fire [E hermes docs, dailydoseofds]:
- After completing a **complex task — 5+ tool calls — successfully.**
- When it **hit errors/dead ends and found the working path** (errors-then-recovery).
- When the **user corrected its approach** (corrections are first-class signals).
- When it **discovered a non-trivial workflow.**

The loop is **observe → distill → reuse → refine** [E aiskill.market]: track multi-step tasks in episodic memory → after a pattern recurs (one source: "3+ successful completions") generate a `SKILL.md` capturing *procedure, pitfalls, verification* → next time the selector matches, load & follow instead of rediscovering.

**Critical nuance — the trigger counts *tool calls*, not user turns** [Y Igor Kudryk @31:56, WorldofAI @0:02]: "instead of counting turns with you as a user, it counts the tool usage." WorldofAI: "every 15 or so tool calls it pauses, reviews what failed, and updates itself" — *the same engine drives both memory and skills, on separate counters.*

**The creation prompt is "class-first" (PR #17213) [E]:** it **prefers patching an existing skill or adding a `references/` file over creating a new narrow skill**, prefers the already-loaded skill, and has a name-veto for new skills. This is the anti-bloat discipline at the *creation* boundary.

**It's opt-in and skippable in practice [Y MG @9:09]:** Hermes only *offers* to crystallize after a session, and for "simple/straightforward" tasks it won't bother — MG had to explicitly say *"create a new skill from all these failures."* Real workflows often need a nudge. (This is the single most important gotcha for anyone expecting fully-autonomous skill capture.)

---

## A3. `skill_manage` — the runtime CRUD (the cheap loop)
Six actions [E hermes docs — verbatim table]:
| Action | Use for | Key params |
|---|---|---|
| `create` | New skill from scratch | `name`, `content` (full SKILL.md), opt `category` |
| `patch` | **Targeted fixes (preferred)** | `name`, `old_string`, `new_string` |
| `edit` | Major structural rewrites | `name`, `content` (full replacement) |
| `delete` | Remove a skill entirely | `name` |
| `write_file` | Add/update supporting files | `name`, `file_path`, `file_content` |
| `remove_file` | Remove a supporting file | `name`, `file_path` |

- **Why `patch` > `edit`:** "more token-efficient than `edit` because only the changed text appears in the tool call" [E docs]. Edit ships the whole file; patch ships the diff. (This also preserves prompt cache better.)
- **Create-locally, update-in-place:** new skills land in `~/.hermes/skills/`; existing ones are modified *where found* — including under `external_dirs`. External dirs are **not** a write-protection boundary (use filesystem perms). [E docs]
- `delete` refuses on **pinned** skills; `patch`/`edit` still go through so the agent keeps improving a pinned skill. [E docs]

---

## A4. The Curator — background hygiene (the medium loop)
A retirement/consolidation system that exists **because skill bloat is the default failure mode** of a self-creating library. [E hermes docs/PRs, Y Akshay @19:52]

**Trigger — inactivity, NOT a cron daemon:** runs when `last_run_at` older than `interval_hours` (**default 168h = 7 days**) **AND** the agent has been idle ≥ `min_idle_hours` (**default 2h**). Checked on CLI start and gateway tick. It spawns a **background fork of the agent in its own prompt cache** (an auxiliary client) so it never disturbs the live conversation's cache. [E docs, Y Akshay]

**Phase 1 — deterministic transitions (no LLM):**
`CREATE → ACTIVE → (unused 30d) STALE → (unused 90d) ARCHIVED → restore`. Archived skills move to `~/.hermes/skills/.archive/` (recoverable). A stale skill used again reactivates. [E docs `stale_after_days: 30`, `archive_after_days: 90`]

**Phase 2 — LLM review (single aux pass, `max_iterations=8`):** the fork surveys *agent-created* skills and decides per-skill: **keep / patch / consolidate / archive** (no `pin` — pin is user-only). The prompt was rewritten (PR #17277) to be **"UMBRELLA-BUILDING, not a passive audit."** Explicit bar: *"would a maintainer write this as N separate skills, or one skill with N labeled subsections?"* Three consolidation methods: merge into an existing umbrella / create a new umbrella SKILL.md / **demote** a skill to `references/`|`templates/`|`scripts/` of another. It judges on **content, not `use_count`**, and treats "each has a distinct trigger" (pairwise distinctness) as the *wrong* bar. Consolidation moves the **whole package** (never orphan support files). [E PR #17277]

**Safety rails (the governance spine):**
- **Never touches bundled or hub-installed skills** — double-filtered against `.bundled_manifest` AND `.hub/lock.json`.
- **Never auto-deletes** — the worst action is archive (recoverable via `hermes curator restore`).
- **Pinned skills bypass everything** (`"pinned": true` in `.usage.json`; set via `hermes curator pin <skill>`).
- **Pre-run `tar.gz` snapshot** before each pass; one-command rollback (`hermes curator rollback [--list|--id <ts>]`).
- Per-run **`REPORT.md`** for auditing.

**Provenance — "agent-created" requires ALL of:** name not in `.bundled_manifest`, not in `.hub/lock.json`, and `.usage.json` has `"created_by": "agent"`. Crucially, **only a background self-improvement review fork sets this** (~every 10 turns). **Skills you create *foreground* via `skill_manage(create)` are treated as user-directed and the Curator leaves them ALONE.** [E docs — verbatim]

**Telemetry sidecar `~/.hermes/skills/.usage.json`** (NOT frontmatter — deliberate): `view_count`, `use_count`, `patch_count`, `last_used_at`, `last_patched_at`, `created_at`, `state`, `pinned`, `archived_at`. Keeping counters out of the SKILL.md keeps human content clean and avoids merge conflicts for hub/external skills. [E issue #7816, commit b7bd177]

**Validated at scale (PR #17277, run on opus-4.7):** 346 agent-created skills → **118 (−66%)**, 249 archives (content preserved as `references/` under umbrellas), 18 umbrellas; **86 API calls, ~6.5 min, ~$4–7, 99% cache hit** on later calls; pinned skill untouched, **zero deletions**; 66/66 tests pass. [E PR #17277]

---

## A5. GEPA — offline self-evolution (the expensive, rigorous loop)
Lives in a **companion repo** (`NousResearch/hermes-agent-self-evolution`), *not* the runtime. It's how Hermes makes sure skills *actually work* rather than just accumulate. **No GPU / no weight training — text-only, ~$2–10/run.** [E repo README + PLAN.md]

**The engine:** DSPy + **GEPA (Genetic-Pareto Prompt Evolution)** — an ICLR 2026 Oral, MIT-licensed optimizer. Core idea, verbatim from the paper [E arxiv 2507.19457]: *"a prompt optimizer that thoroughly incorporates natural language reflection… reflects on [traces] in natural language to diagnose problems, propose and test prompt updates, and combine complementary lessons from the **Pareto frontier of its own attempts**."* Results: **beats GRPO by ~10% avg (up to 20%) using up to 35× fewer rollouts**, and beats MIPROv2 by >10%. The key reframe [Y WorldofAI]: *"back-propagation but for prompts instead of model weights."* It reads traces to learn **WHY** things fail, not just **that** they failed.

**The flow [E PLAN.md]:** read current skill → generate eval dataset → GEPA optimizer (read traces → reflect → propose candidate variants → evaluate) → **constraint gates** → best variant → **PR against the repo.**

**Eval-dataset generation — 4 sources:**
- **A. Synthetic** via a strong model (e.g. Claude Opus): `expected_behavior` is a **rubric, not exact text** — *"should identify the SQL injection on line 42," not "output this exact string."* ~15–30 pairs, split 10 train / 5 val / 5–10 holdout.
- **B. Real SessionDB history** mined from SQLite + LLM-as-judge (low scorers become failure cases for reflection).
- **C. Hand-curated golden** JSONL.
- **D. Skill-specific auto-eval** (e.g. plant a bug → run the skill → check tests pass).

**Scoring = LLM-as-judge on a rubric, NOT binary** [E PLAN.md]: followed-the-procedure (0–1) + output-correct/useful (0–1) + concise-within-token-budget (0–1).

**The five constraint gates — a variant is DISCARDED if any fail** [E repo — verbatim]:
1. **Full test suite** — `pytest tests/ -q` must pass **100%**.
2. **Size limits** — skills ≤ **15 KB**, tool descriptions ≤ **500 chars**, prompt sections **≤ +20%** of current.
3. **Caching compatibility** — **no mid-conversation changes, ever**; schema structure frozen; **new sessions only**.
4. **Semantic preservation** — must not drift from the skill's original purpose (similarity check).
5. **PR review** — every change goes through human review, **never a direct commit.**

> **The single most important principle in the whole system [E PLAN.md, verbatim]:** *"Benchmarks are GATES, not fitness functions… A variant that improves skill quality by 20% but drops TBLite by 5% is REJECTED."* Fitness is task-specific; the broad benchmarks (TBLite regression / TerminalBench2 / YC-Bench coherence) only *gate*. A **length penalty** in the fitness function prevents drift toward verbose solutions. Output PR carries before/after train/val/**holdout** scores, the full diff, run cost, and constraints caught.

**SkillOpt — the minimal, legible version of this loop [Y Knut Jägersberg @3:04]:** frozen agent rollout → diagnose recurring failures in mini-batches → propose a **bounded** text edit → **validation gate: reject unless the score strictly improves.** *"That final `best_skill.md` file is almost always under 2,000 tokens… the result of just one to four carefully validated accepted text edits."* This is the cleanest mental model of "evolve a skill safely."

**Phases 2–5 are PLANNED, not shipped** (only Phase 1 = skill evolution is implemented): Phase 2 tool descriptions, Phase 3 prompt sections, Phase 4 **Darwinian Evolver** (Git-based "organisms," one tool file = one organism, function signatures frozen, AGPL→external-CLI only), Phase 5 continuous loop (monitor per-skill success/tool-misselection/user-corrections, auto-triage by improvement×frequency, cron-trigger GEPA past a failure threshold — **but humans still merge every PR**). [E repo]

**Conceptual cousins (adjacent corpus) [Y yt_self_improving_agents]:** the **Darwin Gödel Machine** (keeps an archive of *all* variants; 20%→50% on SWE-bench; but >$20k/run — the expensive end) and **VeRO** (versioning/rewards/observations harness; warns optimizers "default to prompt edits over structural architecture changes" and can **game the eval metric** rather than truly improve). Karpathy's caution applies: trust auto-skills, but verify against held-out reality.

---

## A6. Bundled-skill sync — distribute without stomping edits
On install and every `hermes update`, a sync copies repo `skills/` → `~/.hermes/skills/` and records `.bundled_manifest`: each skill name → its content hash at sync time (the **origin hash**). On each later sync Hermes recomputes the local hash and compares [E skills.md — verbatim]:
- **Unchanged** → safe to pull upstream + re-baseline the origin hash.
- **Changed** → "treated as **user-modified** and **skipped forever, so your edits never get stomped**."

Escape hatch: `hermes skills reset <name>` (clears a stale manifest entry, keeps your copy), `--restore` (drop local edits, re-copy pristine upstream), `--yes` (non-interactive). The manifest is per-profile. This is the **3-way-merge discipline for a shared skill library.**

---

## A7. Memory vs Skills vs SOUL vs session_search — four surfaces, one rule each
The defining discipline: **one surface per *kind* of knowledge**, each a plain file a human can read/edit/delete. [E memory.md, dailydoseofds; Y Akshay]
| Surface | Holds | Where | Size / loading |
|---|---|---|---|
| **Skills** | **Procedures** ("how to deploy a Next.js app to Coolify") | `~/.hermes/skills/*/SKILL.md` | on-demand (progressive disclosure); cost tokens only when invoked |
| **Memory** | **Declarative facts/prefs** ("don't use direct Vercel deploys; push to GitHub") | `MEMORY.md` ≤ **2,200 chars (~800 tok)** + `USER.md` ≤ **1,375 chars (~500 tok)** | **frozen snapshot** injected every session start; costs ~1,300 tok *every* prompt |
| **SOUL.md** | **Identity/persona/boundaries** | `~/.hermes/SOUL.md` | whole, slot 1, "configuration not chat" |
| **session_search** | **Raw transcript recall** ("did we discuss X last week?") | SQLite `state.db`, **FTS5/BM25** | queried on demand (~20 ms), free, unlimited, automatic |

Memory tool actions: `add` / `replace` (substring `old_text`) / `remove` — **no `read`** (it's already in the prompt). The canonical split [E memory.md]: "Don't use direct Vercel deploys; push to GitHub" → **memory** (a durable fact); the multi-command deploy *checklist* → a **skill** (a procedure). **Memory = what's true; skill = how to act.** Keeping them separate keeps each auditable, avoids merge conflicts, and avoids mixing telemetry with authored content.

---

## A8. Governance — "no silent learning" as a hard constraint
The through-line across every loop is **legibility + reversibility** [E aiskill.market — verbatim rationale]:
- **Agent proposes, human approves/edits/rejects.** Three reasons it matters: (1) "not every correction is a general rule" — sometimes the user wants a one-off; (2) "the agent's phrasing may be wrong" — reading the proposed SKILL.md lets you fix the `description` before it ships; (3) **trust** — "an agent that quietly modifies its own behavior is an agent you cannot reason about."
- **Offline changes deploy via PR, never direct commit;** git-tracked lineage → trivial rollback; **holdout sets catch overfitting.**
- **Curator archives, never deletes**, snapshots before every pass, emits a REPORT.md.
- **Versioning** (`version` semver + new-session-only deployment) so behavior never destabilizes mid-conversation.
- **Skill security is a real surface** [Y AI with Ruchi]: treat installing a community skill like a third-party dependency — read it for suspicious network calls, "ignore your rules" injections, over-broad filesystem access. Hub installs run a security scanner (exfiltration / prompt-injection / destructive-cmd); `--force` never overrides a `dangerous` verdict. [E docs]

The practical payoff [E aiskill.market]: *"A Hermes instance used regularly by one person starts to feel like an apprentice. After a few weeks, its bundled skills are augmented by a personalized library… None of that required training. All of it is inspectable."*

---

## A9. agentskills.io — the open standard / portability
Format originally by Anthropic, released open, adopted across products. Hermes is compatible → skills are portable/shareable via the **Skills Hub** (`hermes skills browse/search/inspect/install/publish`) across sources (official, skills.sh, `/.well-known/skills/index.json`, GitHub taps, ClawHub, LobeHub, direct SKILL.md URL). Trust levels `builtin/official/trusted/community`. **Skill bundles** (`~/.hermes/skill-bundles/*.yaml`) group several skills under one slash-command, loaded together without cache invalidation. `.agents/skills/` is the emerging cross-client convention. [E agentskills.io, hermes docs]

---

## The core philosophies (the hardcore principles, distilled)
1. **Procedural memory ≠ model training.** Improvement = better *text files* (skills/prompts), not better weights. Cheap, auditable, instant, portable.
2. **Context is the scarce resource; progressive disclosure is the budget.** Only descriptions are always-on; everything else is lazy. The `description` is the most load-bearing 1024 chars in the system.
3. **Crystallize struggle, not success-theater.** Skills are born from *friction* (5+ tool calls, dead-ends, corrections) — the places where a procedure is worth not re-deriving.
4. **Prefer the smallest durable edit.** `patch` over `edit`; patch-an-existing over create-new; a `references/` file over a new skill; bounded validated edits over rewrites.
5. **A self-creating library MUST have a garbage collector.** Bloat is the default failure; the Curator (umbrella-consolidate, archive-not-delete) is non-optional, not a nice-to-have.
6. **Benchmarks are GATES, not fitness functions.** Never let an optimizer trade a regression for a local win. Gate on tests + size + semantic-preservation + caching; let fitness be task-specific.
7. **No silent learning.** Propose→approve, archive-not-delete, snapshot+rollback, PR-not-commit, semver, new-session-only. Legibility is a feature.
8. **Separate the surfaces.** Identity (SOUL) vs facts (memory) vs procedures (skills) vs recall (session_search) — one file-kind per knowledge-kind, never mixed.
9. **Telemetry lives in a sidecar, not the artifact.** Counters/state in `.usage.json`; the SKILL.md stays clean human content.
10. **Self-improvement is wired into the *system*, not the prompt.** The agent doesn't need to be told each session that it improves — the SOUL identity + the trigger counters + the Curator cadence make it ambient and automatic. *(This is the load-bearing principle for our goal — see Part B.)*

---

## What's working (claimed) — practitioner reality [R]
- **The skill loop is real and the headline reason to choose Hermes.** First-hand: *"I gave it a daily Hacker News briefing task… and it turned that workflow into a reusable skill plus scheduled routine."* [R, r/AI_Agents 3-week side-by-side]
- **Auto-skills beat manual-skills as a differentiator.** Two independent posters knock OpenClaw for "skills don't save directly / you had to create all the skills manually" — exactly the friction Hermes removes. [R, r/AI_Agents, r/AgentsOfAI]
- **"Stack, don't switch."** Common pattern: OpenClaw as orchestrator for messy tasks + Hermes for fast, skill-heavy repeatable automations; each can diagnose/fix the other. [R, r/AI_Agents]
- **Adoption signal:** reported #1 most-used globally on OpenRouter (24h) at one point, above Claude Code & OpenClaw. [R, r/singularity]
- **Memory architecture praised by a repo-reader:** "the first one where the architecture actually held up" vs ChatGPT/Claude Code/OpenClaw. [R, r/LLMDevs]
- **Live unprompted creation demonstrated:** Hermes autonomously created a "TwinGate client operations" skill after exploring the network. [Y NetworkChuck @19:10]

## What's broken / contested
- **Memory drift is the dominant complaint** (and it contradicts the praise above): *"older instructions got harder to recover, irrelevant context started resurfacing… i found myself back in the files, cleaning up MEMORY.md again, which is exactly the kind of babysitting i was hoping to avoid."* Fix some adopt: memtensor `memos` plugin for recall. [R, r/AI_Agents]. **Note: the complaints target *memory*, not the *skill* loop.**
- **Slow & expensive on raw coding.** One rival benchmark (Localix author, run via claude-opus-4.8): Hermes ~**3.2× slower**, ~**5.5× pricier**, **39% tool-failure** vs 10.5%, 66 vs 29 requests — losing time to one-tool-per-turn execution + multi-turn error recovery. Caveat in Hermes's favor: it built the heavier artifact (TS + unit test) and was halted mid-test. [R, r/AgentsOfAI]
- **Creation is opt-in / skippable** — won't crystallize simple tasks without a nudge. [Y MG]
- **Stale negative claims have no TTL yet** — "browser tools don't work" can persist as permanent truth after the environment changes; revalidation/`hide_stale_from_prompt` is *designed but unimplemented* (issue #7816/#6051). [E]
- **Self-improvement can game the metric** rather than truly improve (VeRO/Karpathy caution). [Y adjacent]

## Anti-patterns (stated explicitly across sources)
- **Skill bloat / dozens of narrow near-duplicates** (the entire reason the Curator exists).
- **Repeated patching → drift, conflicting instructions, over-generalization** (issue #7816).
- **Storing counters in frontmatter** (noisy, conflict-prone, mixes telemetry with authored content).
- **Auto-deleting skills** (too risky — archive instead).
- **Saving the wrong thing to memory:** trivial/obvious facts, easily re-discovered info, raw logs/dumps, session-ephemera, secrets/tokens, PR numbers, anything expiring within a week, or anything already in SOUL.md. *"Self-improving agents fail when they save too much, save the wrong thing, or never verify."* [E aiskill.market]
- **Editing a skill/memory mid-conversation** expecting it to take effect now (frozen snapshot won't update till next session).
- **Hot-swapping evolved content mid-conversation** (GEPA gate #3 forbids it).

## Numbers worth verifying
- L0 skills index ≈ **3k tokens** total (docs) / ~50–100 tok/skill (agentskills.io). No single hard cap stated.
- Curator defaults: **7-day** interval, **2h** idle gate, **30-day** stale, **90-day** archive, `max_iterations=8`.
- Curator at scale: **346→118 skills (−66%)**, ~6.5 min, ~$4–7, 99% cache hit (PR #17277, opus-4.7).
- GEPA: **+10% avg over GRPO (up to +20%), 35× fewer rollouts**; runs ~$2–10; works "with as few as 3 examples."
- Gates: skill ≤ **15 KB**; tool desc ≤ **500 chars**; prompt section ≤ **+20%**; `pytest` **100%**.
- Memory caps: `MEMORY.md` **2,200 chars / ~800 tok**; `USER.md` **1,375 chars / ~500 tok**.
- Creation trigger: **5+ tool calls** (Akshay) / "~every 15 tool calls" review (WorldofAI) / "3+ successful runs" (aiskill.market) — *heuristics, not measured firing rates.*
- agentskills.io: `name` ≤64, `description` ≤1024, body <5000 tok / <500 lines.
- Compaction internals (verify vs source): keep first 3 + last 4 msgs, ~2,500-tok summary target [Y Igor Kudryk — lone-wolf, unverified].

---

## Ready-to-paste scaffolds (reconstructed from the legs — annotated with source)

**1. SKILL.md frontmatter (Hermes/agentskills.io-compatible)** — *src: [E] aiskill.market verbatim + agentskills.io spec*
```yaml
---
name: test-driven-development          # ≤64 chars, lowercase-hyphen
description: Use when implementing any feature or bugfix, before writing implementation
  code. Enforces RED-GREEN-REFACTOR cycle with test-first approach.   # ≤1024; "what + WHEN to fire"
version: 1.1.0                          # semver — evolve without destabilizing prior behavior
author: Hermes Agent (adapted from obra/superpowers)
license: MIT
metadata:
  hermes:
    tags: [testing, tdd, development, quality, red-green-refactor]
    related_skills: [systematic-debugging, writing-plans, subagent-driven-development]
---
# (body < 5000 tokens / < 500 lines — push detail into references/)
```

**2. Curator config (the hygiene cadence)** — *src: [E] hermes-agent docs verbatim*
```yaml
curator:
  enabled: true
  interval_hours: 168     # 7 days
  min_idle_hours: 2       # only run when the agent is quiet
  stale_after_days: 30
  archive_after_days: 90  # archive, never delete
  prune_builtins: true    # hub skills always exempt regardless
```

**3. The five evolution constraint gates (apply to ANY auto-edit before it ships)** — *src: [E] hermes-agent-self-evolution*
```
1. Tests:    full suite passes 100%        (objective regression gate)
2. Size:     skill ≤ 15KB; tool desc ≤ 500 chars; prompt section ≤ +20%
3. Caching:  NO mid-conversation change; schema frozen; new sessions only
4. Semantic: must not drift from the skill's original purpose
5. Review:   PR, never direct commit         # ← the human gate
# RULE: benchmarks are GATES, not fitness. A +20% quality variant that regresses a
#       benchmark by 5% is REJECTED.
```

**4. The bounded-edit evolution loop (SkillOpt — minimal & safe)** — *src: [Y] Knut Jägersberg*
```
freeze(agent)
loop:
  traces      = rollout(agent, eval_minibatch)
  failure     = diagnose_recurring_failure(traces)        # reflect in natural language
  candidate   = propose_bounded_edit(skill, failure)      # small, targeted
  if judge_score(candidate, held_out_val) STRICTLY > current_score:
      accept(candidate)                                   # else reject immediately
# converges in ~1–4 accepted edits; final skill usually < 2,000 tokens
```

**5. `.usage.json` telemetry sidecar (keep counters OUT of the SKILL.md)** — *src: [E] commit b7bd177*
```json
{ "skill-name": { "use_count": 0, "view_count": 0, "patch_count": 0,
  "created_by": "agent", "state": "active", "pinned": false,
  "last_used_at": null, "last_patched_at": null, "archived_at": null } }
```

---

## Practice → source quick-reference
| Practice | Why it works | Source | Leg |
|---|---|---|---|
| Skill = procedure; memory = fact; SOUL = identity; session_search = recall | One surface per knowledge-kind → auditable, no conflicts | hermes memory.md / Akshay | E / Y |
| Progressive disclosure: load only name+description at L0 | Keeps base context ~3k tok; full body lazy → no bloat | agentskills.io / Akshay @15:18 / NVIDIA | E / Y |
| Write the `description` as "what it does AND when to use it" | It's the *only* thing the skill selector matches on | aiskill.market / agentskills.io | E |
| Trigger creation on friction (5+ tool calls / dead-ends / corrections) | Crystallize what's expensive to re-derive | hermes docs / Akshay @16:49 | E / Y |
| Prefer `patch` > `edit`; patch-existing > create-new; `references/` > new skill | Smallest durable edit; token + cache efficient; anti-bloat | hermes docs (PR #17213) | E |
| Run a Curator: stale@30d, archive@90d, LLM-consolidate, **never delete** | A self-creating library must be garbage-collected | hermes curator docs / PR #17277 | E |
| Consolidate by "umbrella, not pairwise-distinctness"; judge on content not use_count | Prevents the audit from bailing out and keeps real coverage | PR #17277 | E |
| Snapshot before every auto-pass; archive recoverable; pin hand-authored skills | Reversibility = trust | hermes docs / Akshay @19:52 | E / Y |
| Gate auto-edits on tests + size + semantic + caching; **PR not commit** | Stops metric-gaming & regressions; keeps human in loop | self-evolution repo | E |
| **Benchmarks are gates, not fitness** | Never trade a regression for a local win | PLAN.md | E |
| Score with an LLM-judge **rubric**, not binary; use **holdout** sets | Catches overfitting; nuanced quality signal | PLAN.md / VeRO | E / Y |
| Telemetry in a sidecar `.usage.json`, not frontmatter | Keeps authored content clean; no merge conflicts | issue #7816 | E |
| Bundled-sync via origin-hash; user-modified skills skipped forever | Update shared skills without stomping local edits | skills.md | E |
| Don't auto-save trivia/secrets/ephemera; verify before persisting | "fail when they save too much / the wrong thing / never verify" | aiskill.market | E |
| For deterministic sub-steps, write a *script* in the skill, not model improv | Determinism + speed; stop re-deriving an API call | Akshay @41:11 banner skill | Y |
| Treat installed community skills as untrusted dependencies | Prompt-injection / tool-poisoning / over-broad fs access | AI with Ruchi @3:03 | Y |

---

# PART B — Applying this to OUR skill system (the downstream goal)

**Our situation.** We have a mature, human-authored skill system (`.agents/skills/` symlinked into `~/.claude/skills/`, governed by `CLAUDE.md`, a drift-gated `capability-registry-harness`, a `lesson-build` Workflow, and a `memory/` dir with `MEMORY.md`). Today the improvement loop is **fully human-driven**: you review a rendered artifact, judge quality, and tell Claude to update a skill. You want to keep **the human as the quality eye** but make the loop **self-tracking** — the agent should *know on its own* that we're in continuous skill-system advancement, without being re-reminded each session.

**The mapping is almost exact** — Hermes already solved the "agent knows it's improving without being told" problem, and the answer is **principle #10: wire the loop into the *system*, not the prompt.** Concretely, three Hermes mechanisms translate directly:

| Hermes mechanism | Our analog (already have / to build) |
|---|---|
| **SOUL.md slot-1 identity** ("you are a self-improving agent") | An ambient `CLAUDE.md` directive + a meta-skill that *is* the loop — always loaded, never re-stated. We already have the seed: CLAUDE.md "Self-Improving Project CLAUDE.md" + "Research → implementation logging." |
| **`.usage.json` telemetry sidecar + per-run `REPORT.md`** | A **skill-improvement ledger** (e.g. `.agents/skills/_ledger.md` or `memory/skill-evolution.md`) — the tracked record of what was changed, why, and what feedback drove it. We already emit `pipelineFindings` per node — *that is our trace signal.* |
| **Creation/Curator triggers wired into the loop** | The `lesson-build` Workflow's `pipelineFindings` union ("the workflow-improvement backlog") becomes the **trigger**: recurring findings + your feedback → a proposed skill `patch`. |
| **GEPA constraint gates + PR-not-commit** | We already have **machine-gated verification** (`lesson:check --measured`, contact sheets, LUFS/collision gates). Treat a skill edit as evolvable, validated against rendered-lesson quality, shipped as a **PR you approve** (matches CLAUDE.md "wait for my approval"). **Benchmarks-are-gates** maps to: a skill edit must not regress the machine gates. |
| **Curator umbrella-consolidation** | A periodic pass over our skills to fold near-duplicate guidance into the right wave-skill (we have many lesson-* skills). Archive-not-delete; you stay the merge gate. |
| **No silent learning / propose→approve / semver** | Already our `CLAUDE.md` rule. Formalize: every skill edit is a proposal with a one-line "why + feedback source," logged to the ledger, approved by you. |

**The key insight for "Claude knows by itself":** Hermes doesn't put "remember you're improving" in every prompt — it puts the *identity* in slot 1 (SOUL) and the *triggers/cadence* in the runtime (tool-call counters, Curator idle-gate, `.usage.json`). The agent acts self-improving because the **system is shaped that way**, and the **ledger is the memory of the trajectory** so it always knows "where we are" in the advancement. Our equivalent: a small **meta-skill ("skill-system-evolution")** + an **append-only improvement ledger** + a **one-line ambient CLAUDE.md hook** that points at the ledger. Once those exist, *every* session implicitly knows we're mid-advancement — because the ledger is loaded context, not a reminder you type.

> This Part-B design is a *proposal sketch*, not yet built — you asked for the research first. The "Next moves" below is the concrete build plan to turn it into a real meta-skill, pending your go-ahead.

## Next moves
1. **Build the meta-skill `skill-system-evolution`** (the "Curator + crystallizer" for our repo), encoding: *when* to propose a skill edit (recurring `pipelineFindings`, your feedback, a wave that needed manual fixing), *how* (prefer `patch`/`references/` over new skill; class-first), and the **gate** (must not regress `lesson:check --measured`; ships as a PR/diff you approve). Mirrors Hermes A2+A3+A5.
2. **Create the append-only improvement ledger** (`memory/skill-evolution.md` + a one-line pointer in `MEMORY.md`): one entry per change = {date, trigger/feedback source, skill+section touched, gate result, your verdict}. This is our `.usage.json`+`REPORT.md`. It is what makes the loop *self-tracking* and gives "where are we" for free.
3. **Add the ambient hook** to `CLAUDE.md` (one line, two-tier per your convention): "We are continuously advancing the skill system; before/after each lesson, consult `memory/skill-evolution.md`, and propose skill `patch`es for recurring findings — human approves." This is the SOUL-slot-1 analog: state it **once, in the system**, never per session.
4. **Wire the trigger into `lesson-build`**: at run end, diff this run's `pipelineFindings` against the ledger; if a finding recurs ≥2 runs, surface a proposed skill `patch` for your approval (don't auto-apply). Optional: a periodic "Curator pass" that flags stale/duplicate skill guidance for consolidation.
5. **Adopt the safe-edit gate as policy** (from A5/SkillOpt): every proposed skill edit is *bounded*, must **strictly improve or hold** the machine gates, ships as a reviewable diff, semver-bumped, logged — never a silent rewrite.
6. *Follow-up search if needed:* the exact Hermes **Curator LLM-review prompt** (PR #17277 body) and the **GEPA reflection-prompt template** inside Hermes' adapter — both under-documented; would sharpen our meta-skill's consolidation + reflection wording.

---

## Sources
### Reddit [R]
- 3-week Hermes/OpenClaw side-by-side (skill loop is real, "stack don't switch") — r/AI_Agents — https://www.reddit.com/r/AI_Agents/comments/1sh2r25/i_ran_hermes_openclaw_sidebyside_for_3_weeks/
- "Honest take" — auto-creates/self-evolves skills, OpenClaw skills "don't save directly" — r/AI_Agents — https://www.reddit.com/r/AI_Agents/comments/1t4lg8q/openclaw_vs_hermes_agent_heres_my_honest_take/
- Memory drift after a week, fixed with memtensor `memos` — r/AI_Agents — https://www.reddit.com/r/AI_Agents/comments/1ss9my5/moved_to_hermes_and_loved_the_switch_but_the/
- Localix vs Hermes benchmark (3.2× slower / 5.5× pricier / 39% tool-fail) — r/AgentsOfAI — https://www.reddit.com/r/AgentsOfAI/comments/1tz7vbk/localix_vs_hermes_comparison_v2_deepseek_v4_flash/
- Hermes vs OpenClaw — 5 real differences (self-improvement architecture) — r/AgentsOfAI — https://www.reddit.com/r/AgentsOfAI/comments/1thitu2/hermes_vs_openclaw_5_real_differences_that_change/
- "How Hermes Agent actually remembers" repo deep-dive — r/LLMDevs — https://www.reddit.com/r/LLMDevs/comments/1sy1y26/how_hermes_agent_actually_remembers/
- Autonomous-agent VPS+Telegram setup (auto-skills vs OpenClaw manual) — r/AgentsOfAI — https://www.reddit.com/r/AgentsOfAI/comments/1sadb14/how_i_set_up_my_own_autonomous_ai_agent_with/
- #1 most-used globally on OpenRouter — r/singularity — https://www.reddit.com/r/singularity/comments/1t9hh33/hermes_agent_is_now_1_most_used_globally_in_past/

### YouTube [Y] (yt-rag namespace `yt_hermes_agent`, ingested 2026-06-08; + adjacent `yt_self_improving_agents`, `yt_agent_prevention_hitl`)
- Akshay Pachaar — Hermes Crash Course (skill trigger / Curator / progressive disclosure / slots) — https://youtu.be/bNp6YcKBLgY (deep-links @918, @1009, @1192, @1375, @643)
- WorldofAI — loop cadence "~every 15 tool calls" + GEPA framing — https://youtu.be/cu2fgknmemA?t=2
- Igor Kudryk (Salesforce) — compaction internals (keep first-3/last-4, 2,500-tok summary) [unverified lone-wolf] — https://youtu.be/PVs2VTPZ3dw?t=1916
- NetworkChuck — crystallization philosophy / build-don't-download / live skill creation — https://youtu.be/QQEgIo4Juxg (@974, @1150, @1243, @1333)
- NVIDIA Developer — self-evolving Hermes, skill-manager anti-bloat (closest to official) — https://youtu.be/pgQDbRMa2Eg?t=613
- Weaviate — "GEPA Explained" (Pareto selection + reflective mutation) — https://youtu.be/czy7hvXIImE?t=367
- Knut Jägersberg — SkillOpt (bounded validated edits, <2k-token skill) — https://youtu.be/86_LUP699Bs?t=184
- AI with Ruchi — when-to-skill rubric + skill security — https://youtu.be/TsjrHmsmBjA?t=183
- MG — opt-in/skippable creation; minimal "lesson learned" skill — https://youtu.be/x7uZJomwe4I?t=549
- Tech With Tim — beginner architecture explainer — https://youtu.be/mTYxpIRK7xA
- Google Antigravity — "Intro to Agent Skills" (SKILL.md, progressive disclosure, agentskills.io) — https://youtu.be/4mnP1lRdUm8
- adjacent: Darwin Gödel Machine, VeRO eval-harness (overfitting/metric-gaming caution) — namespace `yt_self_improving_agents`

### Exa web [E]
- Hermes docs — Skills System — https://hermes-agent.nousresearch.com/docs/user-guide/features/skills
- Hermes docs — Curator — https://hermes-agent.nousresearch.com/docs/user-guide/features/curator
- Hermes docs — Memory — https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/memory.md
- Hermes docs — Architecture — https://hermes-agent.nousresearch.com/docs/developer-guide/architecture
- Self-evolution repo + PLAN.md — https://github.com/NousResearch/hermes-agent-self-evolution
- Curator PR #17277 (umbrella prompt, 346→118 run); Issue #7816 (sidecar/TTL rationale) — github.com/NousResearch/hermes-agent
- aiskill.market — "Self-Improving Agents: How Hermes Writes Its Own Skills" + memory deep-dive — https://aiskill.market/blog/self-improving-agents-hermes-writes-skills
- dailydoseofds — Hermes Agent Masterclass — https://www.dailydoseofds.com/p/hermes-agent-masterclass/
- intraview.ai — skills-system source tour — https://www.intraview.ai/explore/NousResearch/hermes-agent/tours/skills-system/
- GEPA paper (ICLR 2026 Oral) — https://arxiv.org/html/2507.19457v1
- agentskills.io specification — https://agentskills.io/specification

## Method notes
- Legs run: **A** Reddit (191 posts scanned, ~25 relevant) • **B** YouTube/yt-rag (14 videos freshly ingested into `yt_hermes_agent` → 214 chunks, + 2 adjacent namespaces) • **C** Exa web (12 pages, primary docs + repos + paper) • **D** YouTube-discovery scout (Exa). No A/B WebSearch probe (deep dive).
- **Corpus enrichment performed:** ingested a curated 14-video set on 2026-06-08; benefits all future runs (global corpus).
- Empty/weak: Reddit site-wide-by-keyword unsupported by the actor (must name subreddits); "self-improving agent skills" keyword too generic; 3 relevant threads (incl. r/LocalLLaMA "Hermes Desktop," 217 score) returned no body via the scraper.
- **Disambiguation handled:** Hermes *Agent* (skills/learning loop) ≠ Hermes *LLM* model line ≠ Bittensor "Subnet 82 (Hermes)" — all down-weighted out.
- **Trust calibration:** docs/repo claims = primary; video thresholds corroborate docs; Reddit = experiential (esp. the memory-drift weakness & the cost/speed benchmark); Igor Kudryk compaction numbers flagged unverified.
