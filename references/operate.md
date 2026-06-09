# OPERATE — turn one flaw into one durable, tracked change

The daily loop: **gather → capture → route → edit → verify → commit → record.** The human spots the flaw; this loop makes the fix land in the right place, generalize, and stay revertible.

## 0. Gather the full context (evidence first — law 1)
Read these *together* before touching anything:
- **The user-surface problem** — what the human actually saw go wrong.
- **The map** (`<repo>/.agents/skill-system-map.md`) — current skill + workflow composition, **who is responsible for what**, and the **diagnostics log** (has this class been hit before?).
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

## 4. Verify — by intent, for the next session (law 3)
Do **not** write a deterministic test. Write a short **verification intent**: what a *future* run (or the human) should look for to confirm the rule fired and held — phrased so it can't be gamed and doesn't predict the exact output.
- **Visual / artifact-dominant outputs:** the human is the eye. Say so plainly — verification is "the next lesson's human review confirms X no longer happens," not a model self-grade.
- Keep it general: "the composer applies <rule> wherever <condition>," not "frame 412 shows Y."

## 5. Commit — one atomic, revertible change (P2 / law 7)
One lesson = one commit:
```
skillsys(<owner>): <imperative rule, one line>

why:    <trigger — run/artifact/finding + date>
lesson: <symptom → root cause → general rule>
verify: <the next-session intent from step 4>
```
`<owner>` is the map id you edited (a skill, the workflow, a doc, the registry). Keep skill-system edits **out of product commits** so they stay filterable and revertible.

## 6. Record — let the map get more certain
Append one line to the map's **Diagnostics log**: `<date> — <owner> — <rule> (skillsys <sha>)`. Over many runs this is what sharpens responsibilities, makes repeat-flaws visible, and lets the next diagnosis start ahead. Review any span with `scripts/review-edits.sh`.
