# Agent / skill-system memory that stays retrievable without context bloat — research brief
_scope: ~9-month window, generic AI-coding-agent lens, deep dive • generated 2026-06-18_
_source tags: [R]=Reddit • [Y]=YouTube (yt-rag) • [E]=Exa web. Inline citations name the specific creator/site so every claim is traceable._
_Purpose: evidence base for evolving `hermes-skill-system`'s memory layer. Companion to `references/hermes-agent-research-2026-06-08.md` and the three web briefs already folded into the conversation (Ralph loop, agent memory architectures, git-as-memory)._

## How to read this
This is a reusable design artifact, not a one-off answer. Claims are practitioner-experience unless marked as a paper/benchmark. The single most important meta-finding: **the architecture we proposed (split memory by type + git as the episodic log + lean capped standing files + out-of-band consolidation + human-curated, capped skill evolution) is independently the convergent practice across Anthropic's own Claude Code internals, the named "git-as-memory" movement, and the agent-memory literature.** The new material does not overturn the plan — it sharpens specific knobs and adds hard guardrails.

---

## TL;DR (highest-confidence, survived ≥2 sources)
- **Claude Code's *own* memory design is our proposal, almost to the letter** [E, Nafiz]: plain-text files, **one fact = one file**, a **hard-capped index (200 lines / 25 KB)**, append-only transcripts, and an **explicit exclusion list — "never save anything you can `git log`/`git blame`, no in-progress task state, no debugging recipes."** *"Most memory rot is a violation of the exclusion list, not a 200-line problem."* Our 885-line diagnostics log is a textbook exclusion-list violation.
- **"Git history as agent memory" is now a named, documented pattern** [E: Contextual Commits / AI Commit Convention / Lore / whylog], with a concrete **trailer grammar** (`trigger / cause / decision / rejected / learned / keywords`) queried via `git log --grep` / `git log --trailer=`. The `rejected:` field is explicitly *"the anti-hallucination field."* Your instinct is a movement, not a hunch.
- **Autonomy without curation degrades — measured.** The *Library Drift* paper [E, arXiv 2605.19576]: fully **LLM-authored skills give +0.0pp vs +16.2pp for human-curated** on SkillsBench. The fix ("Ratchet") = **retirement on measured contribution + a hard cap (50) + a meta-skill doc** (removing the meta-skill alone costs 43% of the gain). → the human-in-the-loop and a cap are *not* optional flourishes; they are the mechanism.
- **Separate the four memory jobs or it breaks** [E, graph.digital; many others]: working / durable-state / shared-knowledge / event-history each have **different lifespans and write authority**. *"Shared knowledge is governed and versioned; event history is append-only and immutable."* Collapsing them (one fat file) is the failure.
- **Consolidation must be out-of-band, never inline** [Y: Anthropic "dreaming"; Hermes "curator"]. Rakuten cut first-pass mistakes ~90% with a cron that reads transcripts for recurring mistakes and rewrites memory. **Reflect on *failures*, not successes** [Y, Vinh Nguyen] — forcing reflection on wins induces reward hacking.
- **The compaction paradox** [E, Piper Morgan]: a 1,257→157-line CLAUDE.md *broke* because external references don't reload after compaction. **Triggers must stay inline; procedures go external.** Relevant to how INIT injects the stewardship hook.

---

## Key findings (in depth)

### 1. Claude Code's on-disk memory = the reference implementation of our plan
The most mechanism-dense source [E, Ahammad Nafiz, "How Claude Code Actually Remembers Things," 2026-04-26, https://ahammadnafiz.github.io/posts/How-Claude-Code-Actually-Remembers-Things/], reverse-engineered from leaked source. Thesis: **"Claude Code treats memory as a pipeline, not a store. The store is boring on purpose."**

On-disk layout (note: this is *literally the personal-memory system in the user's own global CLAUDE.md* — `memory/` one-file-per-fact + `MEMORY.md` index):
```
~/.claude/projects/<repo>/
├── memory/
│   ├── MEMORY.md        # index of all memory files — HARD CAP 200 lines / 25KB, bottom silently truncates
│   ├── user_role.md     # one fact per file
│   ├── feedback_*.md
│   ├── project_*.md
│   └── reference_*.md
└── sessions/<uuid>.jsonl  # full transcript, append-only
```
Three invariants: **one fact, one file** · **the index is bounded** · **transcripts are append-only** (pruning is reapplied on load, never stored).

Four memory *types* with different decay rates: **User** (slow), **Feedback** (slow), **Project** (fast), **Reference** (pointers only). — This is exactly the `metadata.type` taxonomy in the user's global memory rules.

**The exclusion list (the load-bearing rule for us):** *"never save anything you can `git log`/`git blame`, no in-progress task state, no debugging recipes, no conversation-bound details."* And: *"most memory rot is a violation of the exclusion list, not a 200-line problem."* → Our diagnostics log stores precisely what `git log` already holds (each entry cites its SHA). That is the rot.

Other stealable mechanisms:
- **Freshness warning** appended to any memory file >1 day old: *"This memory is X days old. Memories are point-in-time observations, not live state."* (Directly answers "how do I know an old map note is stale?")
- **Frozen snapshot:** writes hit disk immediately, but the prompt is rebuilt from memory only at session start / post-compaction — preserves prompt-cache hits. [Also Y: Akshay Pachaar, Hermes.]
- **Compaction pipeline ordered cheap→expensive, reversible→destructive:** per-message tool-result budget → snip → microcompact → context-collapse (reversible projection) → autocompact (lossy). A reversible projection pre-empts a lossy summary.
- **Pre-compaction flush** ("save anything worth remembering before we summarize") — called *"the single best pattern."*
- **`auto-dream` background service** merges duplicate memories and ages out stale entries between sessions.
- **Telemetry: 97% of memory-relevance lookups return nothing** → retrieval is backgrounded off the critical path, not loaded eagerly.

### 2. Git-as-memory is a named practice with a concrete grammar
[E, "Contextual Commits / Lore / whylog," agent-wars.com 2026-03-13; D. Stekanov, "Can git history act as a lightweight memory layer," medium]. The **AI Commit Convention (ACC)** puts structured fields in the commit body/trailers:
```
fix(payments): handle slow charge endpoint timeout

Charge API can take up to 45s under load per vendor docs. Default 10s causes false failures.

[context]
trigger:  charge requests timing out in production, not staging
cause:    default HTTP timeout too low for vendor SLA
decision: set timeout to 60s with retry on 429 only
rejected: retry on timeout (masks real failures, inflates cost)   # the "anti-hallucination field"
learned:  vendor SLA allows up to 45s; never use library defaults for billing
keywords: payments, timeout, http-client, retry, billing
```
`learned:` + `keywords:` mandatory; rest optional. Retrieval: `git log --grep="payments" --all-match`. **Zero infra** — rules live in `.claude/rules/commit-convention.md`; an optional pre-commit hook warns if `[context]` is present without `learned:`/`keywords:`. The **Lore** variant uses native **git trailers** (`git log --trailer=`); **whylog** keeps a stable `Lore-id` decoupled from the SHA so rebases don't break links.

**Bi-temporal git-SHA memory** [E, sverklo.com, 2026-04-29] directly addresses the "git gives deltas, not current state" limitation: pin each memory's validity to commit SHAs — `valid_from_sha` / `valid_until_sha` / `superseded_by` — so you can ask "what was true at SHA X" and supersede cleanly instead of flat-overwriting. (Author flags it as "a signal, not proof" — Month-2 retrieval-quality numbers not yet measured.) This is the principled version of our "active-invariants index regenerable from git."

### 3. Autonomy degrades without curation + a cap (the hard guardrail for your loop)
*Library Drift* [E, arXiv 2605.19576v1, 2026]: a single frozen-LLM loop that "writes, retrieves, curates, and retires its own natural-language skills." Headline benchmark: **LLM-authored skills = +0.0pp; human-curated = +16.2pp** (SkillsBench). The **"Ratchet"** governance that recovers most of the gain:
1. **Retirement** — evict a skill on *measured per-task contribution*, not vibes.
2. **Hard cap C (default 50)** — when adding would exceed the cap, the curator evicts the lowest-contribution skill (gives a formal non-divergence guarantee).
3. **A meta-skill document** constraining the synthesizer to stylistically consistent skills — *ablating it costs 43% of the gain; the single most valuable component.*

Corroborating governance designs: **llm-skill** [E, github.com/hanyuancheung/llm-skill] — three meta-skills with **disjoint write rights** (`execute` read-only/routes ≤3 skills/logs candidates · `distill` writes `SKILL.md` · `guide` writes routing only), lazy-load ≤3 SKILL.md, two required "vital signs" per skill (`version` + `status`), append-only `CHANGELOG.md`. And **Skill Evolver** [E, vadim.blog] — a self-improving agent that **may edit only Markdown (skills/CLAUDE.md/hooks), never source** — bounded blast radius + a verification gate.

→ For your "autonomous loop that keeps updating each node's skill + schema": keep it, but it must be **propose-only into a human/independent-judge gate (you already have this), under a per-subsystem skill cap, with retirement by measured contribution, governed by a meta-skill (which `hermes-skill-system` already is).** Hermes's "the human is the eye" and "generalize or don't ship" are the empirically-required guardrails, not bureaucracy.

### 4. The four memory jobs (independent confirmation of the 4-layer diagnosis)
[E, graph.digital, 2026-04-18]: working / durable-state / shared-knowledge / event-history, each with a distinct lifespan **and write authority**:
- Worker agents **READ** shared knowledge (doctrine/schemas/rubrics), cannot modify.
- Orchestrators manage durable state (workflow stage, decisions), don't touch doctrine.
- All agents **APPEND** to event history; **no agent deletes**.
- Working memory is per-run only, **never written back**.
- *"Shared knowledge is governed and versioned; event history is append-only and immutable."* Enforceable on day one via "file structure, worker contracts, write authority, handoff artefacts" — no memory platform needed.

Maps cleanly onto Hermes: **shared-knowledge = the map + criteria** (governed, versioned, curated) · **event-history = git** (append-only, immutable) · **durable-state/working = `status.md`** (the steward owns it, never written back into knowledge) · the node-validation-loop's clean-room producers already have **read-only** access to the rubric.

Related stacks confirming the split: Ralph Orchestrator's `memories.md` (cross-session wisdom) vs `tasks.jsonl` (single-session work) [E, mikeyobrien.github.io]; the "second brain" three-layer global/project/wiki where *current status* is its own layer [R, r/PromptEngineering 1u0e9fq]; hivetrail's 4-file stack (CLAUDE.md rules / skills / MEMORY.md session / per-task) [E].

### 5. Out-of-band consolidation, and reflect only on failures
- **Anthropic "dreaming"** [Y, Claude, 2026-05-08, https://youtu.be/RtywqDFBYnQ?t=739]: an out-of-band process (cron, or on agent spin-down) reads recent transcripts for recurring mistakes + winning strategies and produces an updated memory state you apply immediately or after review. Out-of-band = no hot-path latency **and** separates the memory-quality objective from task performance. **Rakuten: ~90% fewer first-pass mistakes.**
- **Hermes "curator"** [Y, We Learn for Future / NVIDIA]: a background "librarian" tracks skill *usage frequency*, auto-archives stale skills, and triggers short model reviews to consolidate overlapping ones on a schedule.
- **Reflect on failures, not successes** [Y, Vinh Nguyen, 2026-03-11, https://youtu.be/1eXGiDirvdU?t=2005]: forcing reflection on successful runs *induces reward hacking and destroys generalization*; build validation checks before committing to global memory. → vindicates Hermes capturing on *flaws* and the "never reward-hackable tests" law.
- **Permission-scoped shared memory for many parallel agents** [Y, Anthropic SRE demo]: read-only org knowledge vs read-write team store; **optimistic-concurrency content hash** so one agent won't clobber another's write; **version history with attribution** (which agent, when, what session). Relevant once many genre-subsystems evolve concurrently.

### 6. CLAUDE.md / standing-file bloat — the war stories and the rules
- **The compaction paradox** [E, Piper Morgan, 2026-01-30]: refactoring 1,257→157 lines by moving protocols to external files *broke* — after compaction the agent "didn't know logs existed," losing 12 hours of session logs. Fix: ~70 lines of critical protocol back **inline** → 230 lines. **"Minimal inline protocols (the triggers) with detailed external references (the procedures). The trigger survives compaction."**
- **The deletion test** [E, dev.to/ohugonnot, 296→142 lines]: *"if a senior dev deduces it in 5 seconds, it doesn't belong."* KEEP what's NOT deducible from code — invariants, gotchas, non-obvious decisions, security choices, regression anchors. CUT layout trees, tech stack, how-to-run-tests, naming conventions. Corollary: move *verifiable* constraints to **hooks** — "hook error messages substitute for documentation."
- **"Every line is a scar"** [E, stephendulaney, 2,006-line CLAUDE.md]: split into always-loaded rules vs findable reference vs `learnings.md`.
- **"Facts without reasoning decay. Reasoning compounds."** [R, r/PromptEngineering 1u0e9fq]: a note "use X for Supabase joins" is useful once; a page on *why* + when you hit it + how to recognize it applies in new situations. → store the **lesson/rule**, not the instance (already Hermes law 2).
- **Quarterly "is this still true?" line-by-line audit** [E, aicodex.to]: MEMORY.md decays quietly into stale/dead/contradictory rules. → our CONSOLIDATE, on a freshness trigger.
- **MCP tool defs cost ~4–6k tokens each; 5 MCPs ≈ 12% of context** [Y, Alchain] → prefer skills (progressive disclosure) over always-on tool definitions; OpenClaw ships the shortest system prompt (read/write/edit/bash only).

### 7. The maintenance-habit failure mode (why automation matters, gated)
- **20-power-user survey** [R, r/ContextEngineering 1tvgtvm]: everyone reinvents a manual handoff doc 3–5×/day; *"the friction of maintaining it manually means it falls apart within a week"*; *"docs degrade when they hit context limits, decisions get lost."*
- **The differentiator is forced maintenance** [R, r/AI_Agents 1rxwqn8 — MAINTENANCE.md + KB_INDEX.md]: without a rule that forces re-mapping, *"docs slowly drift into garbage… and the agent starts guessing again."* Agent failure modes named: "read too much / read the wrong folder / combine things that shouldn't combine / act confident anyway." Fix routing: "read the index first, only pull extra folders if the task clearly crosses over — **stop loading the entire docs tree like a maniac.**"
- **Make the agent do ~90% of the upkeep** [R, 1u0e9fq]: a session-close command that extracts new concepts, writes pages, appends to an **append-only** session log, and updates *current status* — "when the AI is doing 90% of the upkeep, the habit is just: run the command."
- **The Structure Paradox** [R, r/ContextEngineering 1pclw66]: logically-organized context can perform *worse* than shuffled; *"even ONE irrelevant element reduces performance."* So a well-organized-but-bloated file still degrades output — curation beats organization.

---

## What's working (claimed)
- Plain-text, one-fact-per-file memory with a **hard-capped index** [E, Claude Code]. ✅
- **Git commit trailers as the change-log/memory**, `git log --grep`/`--trailer=` retrieval [E, ACC/Lore]. ✅
- **Progressive / lazy disclosure** — load skill name+description first, body on trigger, scripts last [Y: Akshay Pachaar, AI with Ruchi, Sebastien Dubois; E: tianpan, llm-skill]. ✅ (Hermes already does this.)
- **Out-of-band consolidation** ("dreaming"/"curator") with failure-only reflection [Y]. ✅
- **Separating status (working) from knowledge (durable)** [R, Y, E — unanimous]. ✅
- **Filesystem (+ git checkpoints) as state for long/resumable loops**, fresh agent greps to resume [Y: AI Engineer workshop, Tech With Tim]. ✅
- **Self-improving loop = run → extract learnings → store as skill → reinject** — ACE on Claude Code ported a repo in ~4h / 119 commits / 14k lines, ~$1.5, commit-after-every-edit [R, r/LLMDevs 1pfoqib]. ✅ (this is your autonomous loop, working in practice.)

## What's broken / contested
- **Fully autonomous skill authoring: +0.0pp** without curation+cap [E, Library Drift]. The biggest caution for the autonomous-loop ambition.
- **Self-maintaining vs self-rotting** is the same loop with opposite defaults — the differentiator is an **enforced** maintenance/index discipline [R, contradiction across 1u0e9fq vs 1rxwqn8].
- **More memory ≠ better:** accuracy 90%→51% as context grows [R, Microsoft study via 1pclw66]; ChromaDB: 11/12 models <50% at 32K tokens. Retrieval/curation is the lever, not accumulation.
- **External-reference refactors break after compaction** — over-aggressive leaning-out is its own failure [E, Piper Morgan].
- **Tooling vs files:** Mem0's founder pitches memory infra, then concedes plain markdown "gets you ~70% for free, and I'd recommend it to everyone" [R, 1r967vj]. For our scale, files + git win.
- **Reddit scraper caveat:** 2 of 3 Reddit queries fell back to default subreddits (r/Python, r/bittensor_) and returned off-topic/crypto noise; on-topic signal came from the CLAUDE.md/skills scan + URL follow-ups. Treat Reddit breadth here as partial.

## Numbers worth verifying
- Claude Code MEMORY.md cap: **200 lines / 25 KB**; freshness warning at **>1 day**; **97%** of memory lookups return nothing [E, Nafiz].
- Library Drift: **+0.0pp** LLM-authored vs **+16.2pp** human-curated; cap **C=50**; meta-skill ablation **−43%** of gain [E, arXiv 2605.19576].
- Rakuten first-pass mistakes **−90%** via dreaming [Y, Anthropic].
- Hermes capped files: `memory.md` **~2200 chars**, `user.md` **~1375 chars**; skill-save nudge every **~15 tool calls** / **>5-step** tasks; memory flash at **50%** context; handoff summary **~2500 tokens** [Y, Akshay Pachaar / Igor Kudryk].
- MCP tool defs **~4–6k tokens each**, 5 MCPs **≈12%** of context [Y, Alchain].
- Context rot: accuracy **90%→51%** over long conversations; **32K**-token sub-50% cliff [R, 1pclw66]. ACE loop: **119 commits / 14k lines / ~$1.5** [R, 1pfoqib]. Dynamic memory on browser agents: **30%→100%** success, **−82%** steps, **−65%** tokens [R, 1pclw66].

---

## Ready-to-paste scaffolds (reconstructed from the legs)

### A. `skillsys` commit grammar with git trailers (replaces the diagnostics log)
Derived from ACC/Lore [E] + the existing Hermes convention. Trailers are immutable, travel with the commit, and extract cleanly:
```
skillsys(<owner>): <imperative rule, ≤72 chars>

<narrative body — the reasoning>

Why: <trigger — the run/artifact/finding + date>
Lesson: <the GENERAL rule, phrased to hold for ALL future runs>
Rejected: <what was tried and didn't work — the anti-hallucination field>
Verify: <observable check the next run/human confirms>
Doc: <path to the supporting brief/handoff, if any>
```
Retrieval recipes (the "memory read path"):
```bash
# Evolution of one owner, newest-first, with the Lesson inline
git log --grep '^skillsys(harden-blueprint)' \
  --pretty=format:'%h %ad %s%n  └ %(trailers:key=Lesson,valueonly=true)' --date=short
# Why every change to a subproject/file happened
git log --pretty='%h %s' -- packages/skills/harden-blueprint/
# What we already TRIED and rejected on this node (before re-proposing)
git log --grep '^skillsys(harden-blueprint)' --pretty='%h %s%n%(trailers:key=Rejected,valueonly=true)'
# When an invariant entered / how a rule block evolved
git log -S 'control-scheme' -p
git log -L '/## Fan-out SOP/,/^## /:references/debug-tuning-loop.md'
```
Lint with a commit-msg hook (warn if `Lesson:`/`Verify:` missing). **Never squash `skillsys` commits** — one rule = one commit preserves `--grep`/`-S`/`bisect`.

### B. Four-layer `.agents/` memory (what stays, what moves)
| Layer | Job | Home | Mutation | Budget / rule |
|---|---|---|---|---|
| **Event history** (episodic) | "what changed, when, why, what we rejected" | **git** (`skillsys` + trailers) | append-only, immutable | unbounded; never load eagerly — query by owner |
| **Shared knowledge** (semantic) | "what the system IS + invariants in force" | lean `skill-system-map.md` (+ per-subsystem maps) | curated, versioned | **hard cap ~400 lines**; deletion test; freshness audit |
| **Procedural** (judging) | "what good output looks like" | `skill-system-criteria.md`, per-node | curated, never injected | per-node ≤~8 bullets; the active bar only |
| **Working state** | "current run status, open threads" | `status.md` — *outside Hermes* | overwrite, ephemeral | **hard cap ~60 lines**; history is `git log`, not in-file |
Plus a tiny **reflection layer**: a capped (~20-line) "Open threads & recurring classes" block — only *unresolved/recurring* patterns; absorbed ones drop out (live only in git). Regenerated by CONSOLIDATE (the out-of-band "dream").

### C. Exclusion list for the map/criteria (the rot-killer) [E, Nafiz]
> Never write into a standing `.agents/` file anything that is: (a) recoverable from `git log`/`git blame` (a dated change record — that's what the `skillsys` trailers are for); (b) in-progress task state (that's `status.md`); (c) a one-off instance rather than a generalizing rule; (d) deducible from the code/skills in 5 seconds. Most map bloat is an exclusion-list violation, not a length problem.

---

## Next moves
1. **Re-present the proposal with these guardrails baked in** (cap numbers, the trailer grammar, the exclusion list, the autonomy-needs-curation finding) and get scope approval.
2. **One concrete experiment:** migrate `game-omni`'s 885-line diagnostics log → git is the record + a ~20-line open-threads index; add the `Rejected:`/`Doc:` trailers to the `skillsys` convention; cap `status.md`; measure the map's token footprint before/after.
3. **Follow-up search if needed:** pull the Nafiz follow-up "How Hermes Agent Actually Remembers" (not surfaced this pass) and the Library Drift "Ratchet" details for the exact retirement metric.

## Sources
### Reddit [R]
- r/PromptEngineering — "second brain" 3-layer (global/project/wiki), facts-decay-reasoning-compounds, AI self-maintains — https://www.reddit.com/r/PromptEngineering/comments/1u0e9fq/
- r/LLMDevs — ACE self-learning loop on Claude Code, 119 commits, learnings-as-skills reinjected — https://www.reddit.com/r/LLMDevs/comments/1pfoqib/
- r/AI_Agents — MAINTENANCE.md + KB_INDEX.md, docs "drift into garbage" without a rule — https://www.reddit.com/r/AI_Agents/comments/1rxwqn8/
- r/ContextEngineering — context-rot field guide (attention budget, JIT, Structure Paradox, numbers) — https://www.reddit.com/r/ContextEngineering/comments/1pclw66/
- r/ContextEngineering — 20-power-user survey, manual systems "fall apart within a week" — https://www.reddit.com/r/ContextEngineering/comments/1tvgtvm/
- r/PromptEngineering — Mem0 founder; plain markdown gets ~70% free; paste-at-start template — https://www.reddit.com/r/PromptEngineering/comments/1r967vj/
- r/ContextEngineering — Tocket versioned `.context/` Memory Bank (activeContext/systemPatterns/…) — https://www.reddit.com/r/ContextEngineering/comments/1rdzwbk/
### YouTube [Y]
- Akshay Pachaar — Hermes 3-tier memory, capped memory.md/user.md, frozen snapshot — https://youtu.be/bNp6YcKBLgY?t=643
- Igor Kudryk — Hermes self-improvement loop, 50% flash compaction, add/replace/delete — https://youtu.be/PVs2VTPZ3dw?t=1916
- Claude (Anthropic) — "dreaming" out-of-band memory consolidation; Rakuten −90% — https://youtu.be/RtywqDFBYnQ?t=739
- Claude (Anthropic) — permission-scoped memory, optimistic-concurrency hash, version history — https://youtu.be/RtywqDFBYnQ?t=373
- AI with Ruchi — progressive disclosure 3 levels — https://youtu.be/TsjrHmsmBjA?t=93
- Vinh Nguyen — reflect on failures only; success-reflection induces reward hacking — https://youtu.be/1eXGiDirvdU?t=2005
- PAPAYA 電腦教室 — CLAUDE.md bloats; move not-every-time rules into skills — https://youtu.be/2pM-7fBXc_M?t=642
- AI Engineer (Anthropic workshop) — filesystem-as-state; write learnings to JSON; Ralph history — https://youtu.be/mR-WAvEPRwE?t=3220
- Alchain花生 — MCP tool-def token cost ~4-6k each; skills over MCP — https://youtu.be/DXTS82fJO9A?t=273
- We Learn for Future — Hermes "curator" background pruner/consolidator — https://youtu.be/XoWzOH1lLVg?t=92
- Yaron Been — "close session" skill writes AGENTS.md/learnings/tech-debt/handover — https://youtu.be/NRrj6qEymBY?t=822
- Anthropic — Claude Plays Pokémon: separate long-term KB vs summarized recent actions — https://youtu.be/CXhYDOvgpuU?t=458
### Exa web [E]
- Ahammad Nafiz — "How Claude Code Actually Remembers Things" (memory-as-pipeline, exclusion list, caps) — https://ahammadnafiz.github.io/posts/How-Claude-Code-Actually-Remembers-Things/
- Anthropic — "Effective context engineering for AI agents" (JIT, compaction, NOTES.md, memory tool) — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- platform.claude.com Cookbook — compaction / tool-result clearing / memory, `exclude_tools:["memory"]` — https://platform.claude.com/cookbook/tool-use-context-engineering-context-engineering-tools
- Contextual Commits (Lore/whylog) — git trailers as memory, `git log --trailer=` — https://agent-wars.com/news/2026-03-13-contextual-commits-git-already-logs-the-why
- D. Stekanov — AI Commit Convention (trigger/cause/decision/rejected/learned/keywords) — https://medium.com/@dstekanov.tech/can-git-history-act-as-a-lightweight-memory-layer-for-ai-coding-agents-d53fa345b0a2
- Library Drift (arXiv 2605.19576) — LLM-authored +0.0pp vs human +16.2pp; Ratchet (retire/cap/meta-skill) — https://arxiv.org/html/2605.19576v1
- graph.digital — four memory jobs with distinct lifespan + write authority — https://graph.digital/guides/ai-agents/memory
- Piper Morgan — the CLAUDE.md compaction paradox (1257→157 broke; triggers stay inline) — https://medium.com/building-piper-morgan/the-claude-md-paradox-27072f2228e8
- dev.to/ohugonnot — CLAUDE.md deletion test (296→142) — https://dev.to/ohugonnot/claudemd-after-an-audit-296-to-142-lines
- vadim.blog — Skill Evolver (edits only Markdown, verification gate) — https://vadim.blog/skill-evolver-research-to-practice
- github.com/hanyuancheung/llm-skill — 3 meta-skills, disjoint write rights, vital signs — https://github.com/hanyuancheung/llm-skill
- sverklo.com — bi-temporal git-SHA memory (valid_from_sha/valid_until_sha/superseded_by) — https://sverklo.com/blog/git-for-ai-agent-memory/
- mikeyobrien.github.io — Ralph Orchestrator memories.md vs tasks.jsonl — https://mikeyobrien.github.io/ralph-orchestrator/concepts/memories-and-tasks/
- aicodex.to — quarterly "is this still true?" MEMORY.md audit — https://www.aicodex.to/articles/claude-md-maintenance

## Method notes
- Legs run: A (Reddit), B (YouTube/yt-rag), C (Exa). No A/B WebSearch probe (deep dive). 
- Empty/degraded: 2 of 3 Reddit queries fell back to default subreddits (off-topic) — Reddit breadth partial; YouTube + Exa carried the load.
- yt-rag corpus was rich (yt_self_improving_agents, yt_hermes_agent, yt_agent_prevention_hitl, yt_llm_escalation, yt_ai_game_generation) — no ingest needed.
