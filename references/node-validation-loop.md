# Node-validation loop — clean-room re-run + independent judge

The concrete protocol for OPERATE's **verify** (step 4) and **rerun-decision** (step 8) when the skill system's artifacts are produced by a deterministic multi-node workflow run on a cheap production executor — a `transform-workflow-to-pi`-style harness where a plain-code driver owns the DAG and the executor runs one node per wave. Use it to harden the pipeline **one node at a time** against the per-node criteria fixture, or to post-mortem a "gate-green but bad artifact" run.

It **composes** OPERATE; it does not replace it. Steps 1–7 of OPERATE are unchanged — this file only makes steps 0 / 4 / 8 concrete for an executor-produced system.

## The three roles — the main loop ONLY orchestrates
- **The executor PRODUCES.** The cheap production model (run via the driver) regenerates the node's artifact. Never judges, never edits.
- **Worker subagents (the capable model) DO THE WORK** — spawned per step, each a clean-room agent:
  - a **DIAGNOSIS** subagent: gathers the 3-tier evidence + artifact + upstream, judges against the node's fixture entry, names the EXACT flawed decision, routes to the canonical owner skill(s), and returns a concrete proposal — the skill diff (file + old→new), the `skillsys(<owner>)` commit message (why/lesson/verify), and the diagnostics line. (OPERATE steps 0–4 run INSIDE it.) It reads the fixture (it is a steward, not a producing node).
  - an **APPLY** subagent: applies the human-approved diff and commits (skillsys + diagnostics line; child-commit for the self-referential sha).
  - an **INDEPENDENT-JUDGE** subagent: fresh, sees ONLY the regenerated artifact + fixture entry + upstream — never the diagnosis — and returns PASS / PASS-WITH-NITS / FAIL.
- **The orchestrator (main loop) ONLY CONTROLS FLOW.** It spawns the worker subagents, triggers the executor re-run, runs the two HITL gates, fires the commit, records status, and advances node-to-node. **It never reads evidence, judges, diagnoses, or writes/applies edits in its own context** — it writes plans and spawns prompts (the `/cm` orchestrator discipline), keeping the main loop a clean controller able to drive the whole sweep.
- Validating on the EXECUTOR's model (not a worker subagent's stronger model) is deliberate: a too-strong producer could mask a vague skill. The executor's honest output is the test of whether the SKILL ITSELF carries the craft.

## The laws of the loop
1. **One node at a time. The human is the eye.** Never sweep many nodes before a human looks.
2. **Judge against the fixture, never inject it.** The per-node acceptance criteria are read by the STEWARD to judge — they NEVER travel into the producing node's prompt. Injecting them teaches-to-the-test and voids the clean-room signal that tells you whether the SKILL (not the rubric) produces good output.
3. **Generalize every edit** (OPERATE law 2) — the fix must hold for every future run of that node, never patch the one case.
4. **An independent judge.** Judge the regenerated artifact with a FRESH agent that sees ONLY the artifact + the fixture entry + the upstream it must be faithful to — never the diff or the reasoning behind the fix, so it cannot grade to the fix.
5. **A blind gate is never trusted.** If a verification node in the pipeline cannot see the failure mode (e.g. it can't view pixels and rubber-stamps from JSON), do not run or rely on it during the sweep — the human + the independent judge are the eye.

## The loop (per node) — the orchestrator drives, subagents do the work
0. **Orchestrator spawns the DIAGNOSIS subagent.** It does OPERATE 0–4 inside: gather the 3-tier evidence (structured return + tier-2 process log + tier-3 raw transcript) + the artifact + the upstream it consumed; name the EXACT decision that produced the flaw (never "model too weak" from a counter); judge against the node's fixture entry; route to the canonical owner skill(s); make the smallest durable, *generalizing* proposal; update the node's fixture entry if the definition of *good* changed. It RETURNS the diff + commit message + diagnostics line — it does not commit.
1. **Gate 1 — approve (human).** The orchestrator presents the proposed diff; the human says yes / adjust / no. Structural changes always gate here.
2. **Orchestrator spawns the APPLY subagent.** On approval it applies the exact diff and commits one `skillsys(<owner>)` change + the product-quality diagnostics line, filling the self-referential sha in a child commit (an amend orphans the very commit the line names).
3. **Orchestrator triggers the executor re-run** of JUST that node, reusing upstream from disk (start the driver at the node's entry phase, stop after it; back up the bad-run artifact first as `<artifact>.PRE-<NODE>FIX`; debug on, escalation OFF). The node reads the *edited* skill by path → a true test.
4. **Orchestrator spawns the INDEPENDENT-JUDGE subagent** (fresh; sees ONLY the regenerated artifact + fixture entry + upstream, never the diagnosis) → PASS / PASS-WITH-NITS / FAIL.
5. **Gate 2 — decide (human).** The orchestrator presents the verdict; the human accepts & advances or asks to refine. The orchestrator records the outcome + any *parked* item in the map's status ledger, then advances to the next node.

The orchestrator performs the gates (1, 5), the executor trigger (3), and the spawns (0, 2, 4) — and nothing else. It never reads-and-judges or drafts/applies edits in its own context.

## Single-node re-run vs the full suffix
OPERATE step 8 runs the whole downstream closure of the first changed node — that is the **end-to-end re-validation**, done once when the human calls it (typically at the end of a sweep, or after an early-node edit). To merely **judge whether one node's skill edit fixed that node's artifact**, you re-run only that single node (a degenerate suffix stopped at the changed node). So: harden the pipeline by sweeping node-by-node with single-node re-runs; then one full run from the top is the closing validation that nothing downstream re-broke. Reuse every unchanged upstream artifact untouched — never regenerate or re-judge what the edit didn't alter.

## Run mechanics
The executor run is driven by the project's `transform-workflow-to-pi` harness (the plain-code driver + its resume lever). The project's **map** binds each node to its entry point, its artifact, and its owner skill(s), plus the exact command — that binding is repo-specific and lives in the map, not here. Wrinkle to encode in the map: a node that shares a phase with earlier-serial or parallel siblings may re-run them too; judge only the target, and restore a previously-validated sibling if it drifts.

**Loop artifacts live OUTSIDE every producing node's read-scope.** The two artifacts the loop itself produces — the DIAGNOSIS subagent's post-mortem PROPOSAL and the APPLY/re-run step's bad-run BACKUP (`<artifact>.PRE-<NODE>FIX`) — are written to a path that is OUTSIDE the declared read-scope of every node that produces an artifact under judgment, e.g. a repo-root `_prior-runs/<run-id>/`. NEVER park them inside a node's own data/out dirs (the dirs a re-run reads). A node's read-scope typically grants its whole data + out directory, so a proposal or backup dropped there is IN scope: the clean-room re-run can read the proposed fix (teaching-to-the-test — it voids the clean-room signal, exactly like injecting the fixture, law 2) or thrash re-reading the clutter. This holds for any executor-produced system, not just lessons: wherever the loop writes evidence-of-the-fix, keep it off the producing node's read path.
