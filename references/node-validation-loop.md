# Node-validation loop — clean-room re-run + independent judge

The concrete protocol for OPERATE's **verify** (step 4) and **rerun-decision** (step 8) when the skill system's artifacts are produced by a deterministic multi-node workflow run on a cheap production executor — a `transform-workflow-to-pi`-style harness where a plain-code driver owns the DAG and the executor runs one node per wave. Use it to harden the pipeline **one node at a time** against the per-node criteria fixture, or to post-mortem a "gate-green but bad artifact" run.

It **composes** OPERATE; it does not replace it. Steps 1–7 of OPERATE are unchanged — this file only makes steps 0 / 4 / 8 concrete for an executor-produced system.

## The division of labor (non-negotiable)
- **The executor PRODUCES.** The cheap production model (run via the driver) regenerates the node's artifact. It never judges quality and never edits a skill.
- **The steward (the capable model + the human) JUDGES and EDITS.** Reading evidence, judging against the fixture, finding the root cause, and writing the skill edit are the steward's job — never delegated to the executor.
- Validating on the EXECUTOR's model (not the steward's stronger model) is deliberate: a too-strong judge could produce a good artifact *despite* a vague skill, masking the flaw. The executor's honest output is the test of whether the SKILL ITSELF carries the craft.

## The laws of the loop
1. **One node at a time. The human is the eye.** Never sweep many nodes before a human looks.
2. **Judge against the fixture, never inject it.** The per-node acceptance criteria are read by the STEWARD to judge — they NEVER travel into the producing node's prompt. Injecting them teaches-to-the-test and voids the clean-room signal that tells you whether the SKILL (not the rubric) produces good output.
3. **Generalize every edit** (OPERATE law 2) — the fix must hold for every future run of that node, never patch the one case.
4. **An independent judge.** Judge the regenerated artifact with a FRESH agent that sees ONLY the artifact + the fixture entry + the upstream it must be faithful to — never the diff or the reasoning behind the fix, so it cannot grade to the fix.
5. **A blind gate is never trusted.** If a verification node in the pipeline cannot see the failure mode (e.g. it can't view pixels and rubber-stamps from JSON), do not run or rely on it during the sweep — the human + the independent judge are the eye.

## The loop (per node)
0. **Gather 3-tier evidence** (OPERATE step 0): the node's structured return + its tier-2 process log + its tier-3 raw transcript + the artifact + the upstream it consumed. Name the EXACT decision in the log/transcript that produced the flaw — never infer "model too weak / node too hard" from a counter.
1–3. **Capture → route → edit** (OPERATE 1–3): route the flaw to its canonical owner skill(s); make the smallest durable, generalizing edit; update the node's criteria-fixture entry if the definition of *good* changed.
4. **Approve** (OPERATE 5): show the concrete diff, get the human's yes.
5. **Commit** (OPERATE 6–7): one `skillsys(<owner>)` commit (why/lesson/verify body) + a product-quality diagnostics line in the map. (Self-referential sha caveat: a commit cannot embed its own sha via amend — that orphans the commit the line names; fill the sha in a small child commit so the reference resolves in pushed history.)
6. **Clean-room re-run of JUST that node** on the executor, reusing all upstream from disk: start the driver at the node's entry phase and stop after the node. Back up the bad-run artifact first (`<artifact>.PRE-<NODE>FIX`). The node reads the *edited* skill (nodes load skills by path) → a true test of the edit. Run with debug on + escalation OFF, so the result is the executor's honest output, not a fallback model's.
7. **Independent judge** (law 4) → PASS / PASS-WITH-NITS / FAIL against the fixture; the steward cross-checks.
8. **Decide WITH the human** (OPERATE 8): accept & advance, or refine. Record the outcome — and any *parked* item to revisit — in the map's status ledger.

## Single-node re-run vs the full suffix
OPERATE step 8 runs the whole downstream closure of the first changed node — that is the **end-to-end re-validation**, done once when the human calls it (typically at the end of a sweep, or after an early-node edit). To merely **judge whether one node's skill edit fixed that node's artifact**, you re-run only that single node (a degenerate suffix stopped at the changed node). So: harden the pipeline by sweeping node-by-node with single-node re-runs; then one full run from the top is the closing validation that nothing downstream re-broke. Reuse every unchanged upstream artifact untouched — never regenerate or re-judge what the edit didn't alter.

## Run mechanics
The executor run is driven by the project's `transform-workflow-to-pi` harness (the plain-code driver + its `startAt` / `--until` levers). The project's **map** binds each node to its entry phase, its stop label, its artifact, and its owner skill(s), plus the exact command — that binding is repo-specific and lives in the map, not here. Wrinkle to encode in the map: a node that shares a phase with earlier-serial or parallel siblings re-runs them too; judge only the target, and restore a previously-validated sibling if it drifts.
