# OPERATE — turn one flaw into one durable, tracked change

The daily loop: **gather → capture → route → edit → verify → approve → commit → record → rerun-decision.** The human spots the flaw; this loop makes the fix land in the right place, generalize, and stay revertible — with the human gating the change in (approve) and gating whether to re-validate it (rerun).

## 0. Gather the full context (evidence first — law 1)
Read these *together* before touching anything:
- **The user-surface problem** — what the human actually saw go wrong.
- **The system's map** (its `.agents/` map, found via the registry `map:` pointer) — current skill + workflow composition and **who is responsible for what**. For *has this class been hit before?* read the **iteration log**: `git log --grep '^skillsys(<id>)'` (especially the **Rejected** trailer — what we already tried) + the registry's **open-threads** block.
- **The run's real evidence** — the actual logs + artifacts the run produced. The map's observability section says where: per-node logs, run status, raw transcripts, the aggregated findings, and the product artifact itself. Diagnose from this, not from a guess about what the code "should" do.

The map + the live problem, side by side, give the **top candidate** of what to fix. If the map feels stale or thin here, refresh it (INIT) first — a stale map is the main failure mode.

## 1. Capture — the lesson, as a class
Write it down before routing, general not one-off:
```
symptom:    <what the human saw>
root cause: <the real reason, traced from the run's logs/artifacts>
rule:       <the GENERAL rule that prevents the whole CLASS — never the single instance>
trigger:    <which run / artifact / finding surfaced it>
```
If you can't state the rule as a class that holds across all future runs, you don't have a lesson yet — keep digging. Hard-coding the one case is forbidden (law 2).

## 2. Route — find the one owner (P1)
Using the map's responsibilities:
- **Classify** the lesson: a **law/fact** (constitution or arch doc), the **chain** (orchestrator wiring + hand-offs), a **node's craft** (a wave skill), a **capability** (registry), or **code**.
- **Prefer the chain over a single skill (law 4).** If the flaw is about coordination, ordering, hand-off, or hits many nodes → edit the **workflow/orchestrator**, not one skill.
- **Dedup (law 5):** grep the rule's keywords across owners; if it's half-stated somewhere, refine it *there*.
- **Altitude:** encode where the responsible node will actually reload it, reusable across lessons.

## 3. Edit — smallest durable change (law 6)
Patch a section > add a `references/` file > new skill. Phrase the edit to **generalize** — it must read correctly for every future lesson, not just this one.

**Update the node's acceptance criteria.** If the edit changes what *good output* for a node means, update that node's output-expectation rubric in the criteria fixture (the standing file alongside the map, `init.md` item 10) in the SAME atomic change. The criteria are the durable, accumulating definition of done that every future run is judged against — the standing form of step 4's per-edit intent. Human-judged, never an auto-test.

## 4. Verify — by intent, for the next session (law 3)
Do **not** write a deterministic test. Write a short **verification intent**: what a *future* run (or the human) should look for to confirm the rule fired and held — phrased so it can't be gamed and doesn't predict the exact output. **Anchor it to the node's acceptance criteria in the criteria fixture** (the standing file alongside the map, `init.md` item 10): the per-edit intent is "the next run's `<artifact>` meets criterion X," referencing that durable bar — not a fresh ad-hoc bar re-invented each time.
- **Visual / artifact-dominant outputs:** the human is the eye. Say so plainly — verification is "the next lesson's human review confirms X no longer happens," not a model self-grade.
- Keep it general: "the composer applies <rule> wherever <condition>," not "frame 412 shows Y."

## 5. Approve — get the human's yes BEFORE it lands (law 3)
Present the concrete diff/plan to the human and wait for explicit approval **before committing** — this gate is *before* the change, distinct from step 4's post-hoc intent. **Structural changes always require it** (a new skill/doc, a new wave, reordered waves, or a changed subagent/node contract); a spec edit inside an existing skill may not. Atomic-revertibility is not a substitute — easy revert is not the same as a yes. If the human adjusts, fold it in and re-present; only a clear yes advances.

## 6. Commit — one atomic, revertible change (P2 / law 7)
One lesson = one commit:
```
skillsys(<id>): <imperative rule, one line>

why:      <trigger — run/artifact/finding + date>
lesson:   <symptom → root cause → general rule>
rejected: <what you tried that did NOT work — the anti-hallucination field; omit if none>
verify:   <the next-session intent from step 4>
```
`<id>` is the **registry id of the tracked system** you improved — the `skillsys(<id>)` scope key, so `git log --grep '^skillsys(<id>)'` returns this system's whole iteration log (for a single-skill system, `<id>` is that skill's name). Name the **specific component** edited (a skill, the workflow, a doc) in the imperative subject; the file path carries it too. The trailers ARE the record (step 7) — keep them honest. Keep skill-system edits **out of product commits** so they stay filterable and revertible.

## 7. Record — git IS the record; touch open-threads only for an unresolved/recurring pattern
The commit you just made (step 6) **is** the record: `skillsys(<id>)` with Why / Lesson / Rejected / Verify is the iteration log, queryable forever (`git log --grep '^skillsys(<id>)'`, `scripts/review-edits.sh`). Do **not** append the edit to an in-file diagnostics ledger — that duplicates what the commit already holds and is exactly the rot the registry's exclusion list forbids (`init.md`).

The only standing in-file write here is **conditional**: if the lesson leaves an **unresolved or recurring** pattern worth carrying into the next session (a thread you didn't fully close, or a class that has now recurred), add/refresh **one line** in that system's **open-threads** block in the registry. A fully-absorbed lesson writes **nothing** here — it lives in git alone. Keep the block tiny; CONSOLIDATE regenerates it and drops absorbed threads. So the map gets more certain through three channels, not a ledger: **git** (the full record), **open-threads** (only what's still live), and the **criteria fixture** (step 3, the sharpened bar).

## 8. Rerun-decision — re-validate WITH the human (law 3)
After committing, decide *with the human* whether to rerun the workflow — both to validate this change on a real run and because a skill-system edit can **stale prior verifications** (an earlier rule's "next run confirms X" may need re-confirming under the new edit). Verification is confirmed only by a real run + the human's eye, never assumed. The human owns this call; surface it explicitly — don't skip it. When you do rerun, **judge the artifacts against each touched node's acceptance criteria in the criteria fixture** (the standing file alongside the map), and **sharpen those criteria** from what the run reveals — so the rubric gets more certain every run (its history is its `skillsys(<id>)` commits, not an in-file ledger).

**The verification run is a SUFFIX of the pipeline, fixed by the FIRST changed node.** A validation rerun is neither a fresh full run *nor* "just the nodes I touched." What you must run is **determined by the EARLIEST node whose output the edit changes**: resume there (`--arg startAt=<that-node>`; the preflight verifies the upstream artifacts it depends on) and run forward through its **entire downstream closure** — in a mostly-linear pipeline, all the way to the final artifact, because every later node consumes an upstream one. So the run length **varies by edit and cannot be shortened past the first changed node**: a late edit (e.g. composer) reruns a short tail (compose → render → verify); an early edit (e.g. storyboard) reruns nearly the whole loop, since everything after depends on it. **Pick the start by asking "what is the first node whose behaviour my edit alters?" — never by how many nodes you touched.** Everything upstream of that node is **reused untouched**: never clear or regenerate an unchanged upstream artifact (deleting it forces a needless, credit-burning re-run), and never re-judge it ("initial design" you didn't alter — point the eye only at the delta). This first-changed-node rule is the lever that makes validation gradually cheaper as the system matures.
