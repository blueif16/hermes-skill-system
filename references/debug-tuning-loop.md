# Debug-Tuning Loop — crack an agent-pipeline failure to the root, on evidence

> Model strength is rarely the bug — *our part* is (task structure, the contract, the prompt). The
> executor may be a top-tier, large-context model run cheaply; **cheap-to-run ≠ weak.** Never diagnose
> "the model is too weak" off a counter — that is trap M3/M0. Fix our structure and our invariants.

The diagnostic **craft** inside Hermes: *how* you find a bug's true root cause and decide its fix —
not how you orchestrate or commit it. It is the method the **DIAGNOSIS subagent** runs
(`node-validation-loop.md` step 0) and the craft behind **OPERATE** steps 0–2 (gather → capture →
route). `operate.md` owns the change spine (edit → approve → commit → record → rerun);
`node-validation-loop.md` owns the roles/gates/clean-room re-run; **this owns getting to the root and
choosing the fix.** It governs BOTH failure kinds — "the node isn't runnable" (no/empty/wrong-path
artifact) and "the output is bad" (artifact exists but thin/wrong; the gate may be green — green ≠
good, the human is the eye).

## The prime rule — EVIDENCE OVER ASSUMPTION
Treat everything you "know" as unverified until a trace, a measurement, or the model's own reasoning
confirms it. **A claim with no ground evidence is a hypothesis, not a finding.** Every diagnosis ties
to a specific log line, a measured size/count, the model's own `<think>`, or a stored research result.
The canonical failure this prevents: reading a number off a config (e.g. a `maxTokens` cap) and
steering a fix from it **without checking the trace shows it actually bit**. Verify the number, then
fix it once and move on — don't camp on it, don't re-litigate it forever.

## Classify the failure first (P0)
- **A · NOT RUNNABLE** — stalls / errors / 0 writes / wrong-path / empty artifact. Oracle: the file
  exists at its exact path AND the Output Contract holds.
- **B · BAD QUALITY** — artifact exists but is thin / wrong / self-contradictory. Oracle: the node's
  criteria-fixture entry + the human eye (never the producing node's own green verdict).
The loop is the same; only the oracle differs.

## The loop — phases, each leaves only when its exit condition is met
- **P0 · FRAME.** Write the failure as a falsifiable sentence — *expected vs observed* — and classify
  A/B. Pin the run: node id, flow commit, and the **live pi model read from the run's `message_start`,
  not the config** (it drifts). *Exit:* one written "node X should write Y with property Z; instead got
  W," run pinned.
- **P1 · REPRODUCE.** A deterministic single-node re-run that fails on demand — pin model + reuse the
  frozen upstream artifacts from disk (`--only <node>` / `--from <node>`; the on-disk files ARE the
  recorded inputs — never re-run the whole pipeline to test one node). Flaky? Run N times, record the
  rate; intermittency is itself a finding. *Exit:* you can trigger the failure at will (or have it
  classified nondeterministic with a measured rate). **You may not form a fix hypothesis before this.**
- **P2 · RECONSTRUCT THE INFORMATION ENVIRONMENT.** See *exactly* what the model saw and did — not
  what you assume. (Mechanics below.) *Exit:* you can name, from the trace, the **first point** where a
  decision/state went wrong — not the final symptom.
- **P3 · ISOLATE.** Separate root cause from contributing cause. Enumerate **≥3 competing hypotheses
  before testing any** (dilutes the anchor). For each, write the observation that would *falsify* it,
  then go look for the disconfirming one first. Narrow by delta-debugging: a pass/fail pair, remove one
  component at a time (an instruction, a context block, a binding) and re-run; the change that flips
  pass↔fail is the cause. Trace UPSTREAM — a wrong artifact here is often a faithful node on bad input.
  *Exit:* one hypothesis survives a disconfirming test, explains every symptom, and is traced to its
  source owner (this node, not an upstream producer).
- **P4 · FIX.** Smallest durable edit at the canonical owner (see "Choosing the fix"). *Exit:* diff
  drafted; blast radius named (which consumers it touches — read `.agents/skill-system-io-map.md`).
- **P5 · VERIFY.** Re-run the P1 reproduction — failure gone — and confirm nothing downstream broke.
  The oracle is immutable; never edit the test/criteria to pass. *Exit:* repro passes, suffix green.

## Reading a large trace efficiently (P2 mechanics)
Cheapest, most objective signal FIRST — our own history shows the bug is usually visible before the
reasoning is: the W3b race showed in `extract.mjs` output as one `∥ parallel xN` stage *before any
run*; the Harden stall was a **write-count of 0**.
1. **Objective artifacts:** `extract.mjs` stages, the **write-call count**, file existence/size.
2. **The rendered `prompt.md`** — what the model ACTUALLY received, including anything auto-injected
   (e.g. a repo `CLAUDE.md` the agent loads from cwd) — not the workflow template. *Bugs live in the
   difference.*
3. **`events.jsonl`:** grep `tool_execution_start` for the real tool calls (name + args); grep/tail
   `<think>` and `text_delta` for the model's reasoning; find the divergence turn. An empty/null tool
   *result* ≠ a tool *error* — record it explicitly.
4. **`debug.log`:** the timeline + how it ended — a clean `finishReason`, a `length`/`max_tokens` cap,
   or killed mid-stream (events end on a raw `text_delta`, no `message_end`).
**Reconstruct the FULL information environment** — preamble + wiring body + the SKILL it loads + every
input/schema/registry file it reads + auto-injected context. Simulate exactly what it receives.

## Escalate to research — the tier rule
- **Fast path (diagnose inline):** deterministic repro + P2 points to an obvious single cause (missing
  field, dangling ref, malformed arg, one-line prompt gap) + small blast radius. Run P0→P5 directly.
- **Research path (spawn a clean-room research sub-agent; STORE the finding):** the cause is
  novel/external (a model/SDK/library behavior, "why does the executor do X"), OR the **fix needs a
  choice among design options you can't rank from first principles** (one big write vs incremental vs
  template-fill; sandbox-or-not; raise-a-limit-or-not), OR P3 yields no surviving hypothesis. The
  sub-agent gets clean context (pinned facts + artifact paths + the framed question) and returns a
  *diagnosis/recommendation*, not a gut patch. Use **Exa / multi-source research** — never settle a
  design option by gut.
- **Research vs just-check:** research a question whose best practice you cannot prove from the trace
  or first principles. Do NOT research what a `grep` / `ls` / single re-run would answer.
- **3-strike + time-box:** three falsified hypotheses → STOP (your model is wrong, not the next
  detail) → hand to a fresh-context sub-agent or the human. Box each hypothesis (a re-run count / a
  clock); sunk cost is sunk.

## The "enough evidence to act" gate — all must hold
1. **Reproduced** (P1), or measured nondeterministic with a rate.
2. The surviving hypothesis came with a **disconfirming observation you sought and did NOT find** — not
   just confirming evidence.
3. It **explains every** symptom (a partial explanation = a contributing cause — keep going).
4. **Traced to the source owner** (this node, not an upstream producer feeding it bad input).
5. You can name the **smallest edit + its blast radius**.
If any fail → keep gathering or escalate. If the *next* observation wouldn't change the fix → stop
gathering and act.

## Choosing the fix — a structural invariant belongs in the harness/contract, not in prose
**The load-bearing lesson (Hermes law 4 + trap M3) — model-agnostic.** Don't reach for "the model is
too weak, add more doctrine." First ask: **did WE structure the task and enforce the invariant well?**
Two consequences hold at ANY model strength:
- A **structural invariant** — e.g. "the required artifact exists on disk at its path" — is *guaranteed*
  by the **harness/driver gate or the declared contract** (`artifacts`/`owns`/`readScope`, the Output
  Contract), never by prose. "Write the file first" in a prompt is a hope; a driver gate that won't let
  the turn end until the file exists is a guarantee. A prompt that already says "do X" which the model
  didn't do is not fixed by saying it louder — move the boundary OUT of the prose.
- **Structure the task so the natural completion path produces the artifact incrementally on disk**, not
  as one giant inline pass. A node handed a huge schema + "compose it all and prove it" will tend to
  reason the whole thing in one stream; reduce that friction — pre-seed a template to FILL, decompose
  into ordered write-then-fill steps, lift the in-head burden — so a `write` is the first natural action.
  This also makes a killed/dropped stream **non-fatal**: incremental on-disk progress survives it; a
  single inline pass loses everything.

*Worked instance — "is one whole-file write worse than many small writes?" (resolved by research, not
asserted):* for a large structured artifact, single-shot inline generation is the **least robust** — it
maximizes pre-write reasoning and is all-or-nothing (a killed/dropped stream loses everything; the
inline-runaway). The evidenced-robust pattern is **pre-seed a placeholder template + write the skeleton
FIRST + fill via targeted edits**, with the artifact-on-disk invariant **enforced by a harness
write-first gate** — *independent of model strength*, because it gives incremental durable progress,
lowers the in-head schema burden, and makes a dropped stream recoverable. (Not a weak-model crutch —
structural robustness; a strong large-context model still benefits when the artifact + schema are large
and a kill-timeout is in play.) Store the research result with its evidence; don't re-derive it.

## Route to the canonical SOURCE owner, not the symptom site (composes with OPERATE step 2)
- A wrong artifact here is often a faithful node on bad INPUT → fix the producer/contract, not the
  symptom node.
- A defect reproduced on a SECOND case / a different executor is **structural** (instruction-layer),
  not random — the first question is "do the **SKILL + chain prompt + criteria fixture** AGREE on this
  behavior?" Fix every site that mandates it **in lockstep** (a single-site fix re-injects it).
- A verify node never creates a key artifact (the verify-node law) — if removing a node loses an
  artifact, it's misclassified; split producer/verifier first.

## Our recurring traps — the known-mistake checklist (each with the cheap check that catches it)
- **M1 · self-report over filesystem.** Check: `ls`/`stat` the exact expected file + confirm `write`
  calls in `events.jsonl`; never trust an `ok`/`PASSED` status alone (the plat1 false-green; green ≠
  good).
- **M2 · single-site fix for a multi-site defect.** Check: `grep <old behavior>` across SKILL + chain
  prompt + criteria fixture + schema examples *before* closing (the nv1 baked-labels — three sites in
  lockstep).
- **M3 · treating thrash/stall as a model defect, not a spec gap.** Check: count write calls in the
  first minutes — **0 writes at the 10-min mark = specification gap**; read the `<think>` for what it
  hunted (the Harden stall; the val1 114-tool thrash).
- **M4 · a serial dep hidden inside a `parallel()` thunk.** Check: `extract.mjs` stage count — a
  known-serial pair shown as one `∥ parallel` stage is the bug (the p02 W3b race).
- **M5 · a stale run record cited as live evidence.** Check: read the actual artifact on disk, not the
  `runs[]` note — the defect may already be fixed.
- **M6 · a verify node as primary artifact creator.** Check: "remove this node — does the flow still
  yield every artifact?" If no, split it (the VERIFY-1 conflation).
- **M0 · anchoring on an unverified number/assumption.** Check: does the trace show the limit/condition
  actually bit? (the `maxTokens=16384` that was never hit.)

## Recording — ground evidence, not citation ceremony
Record a finding ONLY when it rests on **ground evidence** — a specific log line, a measured
size/count, the model's own `<think>`, or a stored research result. The bar is *"is this verified,"*
NOT *"is there a formal citation."* Keep the evidence; drop the ceremony. A finding worth keeping (a
research result, a new recurring trap) is stored **once** at its canonical home (a `research/` record /
this checklist / the diagnostics log) with the evidence inline — so the next session reuses it instead
of re-deriving it, and we don't anchor on a wrong fact forever.

## How this composes with the rest of Hermes
- It is the craft INSIDE `node-validation-loop.md` step 0 (the DIAGNOSIS subagent) and OPERATE steps
  0–2. The orchestrator only controls flow; **clean-room sub-agents diagnose / research / judge / edit**
  (clarity = performance — give each complete, focused context); the **human gates structural changes**
  and **is the eye** on the playable artifact.
- Verify the fix by the **suffix re-run fixed by the first changed node** (OPERATE step 8); for a
  single-node skill edit that is the single-node re-run (`node-validation-loop.md` step 3).
- Anti-reward-hack is absolute: assert observable state only; never inject the criteria fixture into a
  producing node; the oracle is immutable.

## Worked example — the V01 Harden stall (the loop, end to end)
- **P0 FRAME (A · not runnable):** "Harden should write `out/v01/spec/blueprint.json`; instead 0
  writes, killed mid-run." Pinned: `--only harden`, provider `minimax`/`MiniMax-M3` (from
  `message_start`).
- **P1 REPRODUCE:** single-node re-run on frozen W0/W1 upstream — stalls every time (3×).
- **P2 RECONSTRUCT:** `events.jsonl` → **19 tool calls = 12 read + 7 bash, ZERO writes**; the model
  read both governing skills (its `<think>`: *"load them first as instructed by CLAUDE.md"* — an
  auto-injected, orchestrator-only directive leaking into an executor), read `blueprint.schema.json`
  twice, then opened **one 170 s+ inline reasoning stream** composing the artifact as chat; `debug.log`
  ends mid-`text_delta`, **no `message_end`, no `length`** — killed mid-stream, the 16384 cap never
  bit (refutes the cap hypothesis).
- **P3 ISOLATE:** core (hypothesis) = the task structure invites one giant inline pass and **nothing
  ENFORCES the artifact-on-disk invariant**, so 170s of inline reasoning produced 0 writes before the
  stream was killed; contributors = the CLAUDE.md leak (pulled it into orchestrator-mode — wasted reads
  + context) and the 68KB schema-in-head (read twice). The prior fix was prompt-level ("write skeleton
  FIRST" in SKILL §0.5) and **did not hold on the next run** — disconfirms "say it louder in the
  prompt." OPEN, for the fix sub-agent to reproduce: was the kill premature (node-timeout vs a stall
  watchdog vs a human stop)? i.e. would it have written eventually — diagnose, don't assume.
- **P4 FIX (route to owners):** harness write-first gate + pre-seed a `blueprint.json` template to fill
  (`harden-blueprint` + the driver/contract); stop the CLAUDE.md leak at its root (the directive /
  preamble); raise the self-imposed `maxTokens` (config hygiene — separate, cheap).
- **P5 VERIFY:** `--only harden` re-run → a non-empty `blueprint.json` lands on disk, valid against the
  schema, with no inline-only runaway.
