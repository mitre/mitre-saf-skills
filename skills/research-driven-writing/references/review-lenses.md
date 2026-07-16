# Review Lenses and the Adversarial Verify Protocol

Stage 4 (multi-lens review) and Stage 5 (independent review) in detail. Read this when the draft is complete and entering review.

## The five standard lenses

Each lens is an independent reviewer with one job and stated criteria. Independence matters: one reviewer running all five lenses converges on the first plausible reading; five reviewers with one lens each do not. If your environment supports subagent delegation, run each lens as a separate session; otherwise run them sequentially with an explicit reset between lenses.

### Lens 1 — Citation re-derivation
For every external-fact claim: open the pinned source and re-derive the claim from scratch. Verbatim quotes checked character-for-character against the cached source. Version attributions checked (is this the current edition's wording, or a superseded one?). Spliced quotes — two source sentences joined as one quote — are findings even when each half is accurate. Every URL resolved; every "current version" claim re-checked at review time.

### Lens 2 — Consistency
Terminology: every acronym expands one way, every defined term used per its definition, no term defined twice differently. Claim-strength: prose wording matches the register's ladder rung everywhere the claim appears (a claim "implemented" in section 3 must not become "released" in section 8). Internal contradiction sweep: statements in tension across sections.

### Lens 3 — Constraints
The document's Frame-time constraints block, checked item by item: names, advocacy, altitude rules, avoided terms, internal-note markers, division-of-labor boundaries with sibling documents ("does this restate what the companion paper owns?"). Mechanical items run as greps; judgment items (altitude) reviewed against the stated criteria, with findings quoting the offending passage.

### Lens 4 — Source fidelity
For modernizations and any document carrying an author's established concepts: does the new text preserve the meaning of the author's source text? Reviewers are explicitly prohibited from "improving" the author's concepts or voice — this lens exists to catch drift introduced by every other stage. Findings quote both texts side by side.

### Lens 5 — Reader experience
The persona check: a defined reader (state who — e.g., "a senior decision-maker who is not a specialist in this domain") reads the document start to finish. Findings: where they stop understanding, what question the text raises but doesn't answer, where altitude drops into implementation detail, what they would challenge first.

## Finding handling: dedupe, then adversarially verify

Reviewer findings are signals, not instructions. The pipeline:

1. **Collect** all findings from all lenses.
2. **Deduplicate** against the full set (same passage + same defect = one finding).
3. **Adversarially verify each finding before applying it**: a verifier (fresh context if possible) attempts to REFUTE the finding against the primary sources. Default skeptical — a finding that cannot be confirmed against a source is not applied.
4. **Apply confirmed findings; disposition the rest** with reasons, recorded with the document's working notes. Rejected findings are kept — like the do-not-resurrect list, they prevent the same plausible-but-wrong finding from being re-raised and re-litigated next cycle.
5. **Re-run the mechanical battery** after applying fixes.
6. **Repeat the cycle until a review round produces no confirmed findings** (loop-until-dry), typically two to three rounds.

Never apply a finding that would change a substantive authorial claim without the author's explicit decision — route those to the author with the evidence.

## Stage 5 — the independent review

After the lens cycles converge, one final fresh-context review with no investment in the draft and no memory of the review history. Purpose: catch what the process itself has gone blind to.

Prompt structure for the independent reviewer:

```
You are reviewing <document> cold. You have: the document, its claims
register, its constraints block, and the cached sources. You were not
involved in writing it and have no stake in it shipping.

1. Verify each acceptance criterion for the document against the text
   itself — not against the authors' notes about the text.
2. Spot-check citations: select the five claims whose failure would be
   most damaging, and re-derive each from its pinned source.
3. Answer: what is the single weakest claim in this document, and would
   you stake your credibility on it in front of a hostile expert reader?
4. Report findings only — do not edit the document.
```

If subagent delegation is unavailable, conduct this in the current session — the requirement is independence of judgment, not a separate process. State explicitly that you are switching roles, and hold the reviewer role until the report is complete.

## What the lenses cannot do

The lens battery bounds the judgment problem; it does not replace the author. Terminology, positions, political calibration, and distribution wording go to the author regardless of what any lens concludes. The author gate after independent review is not ceremonial — it is the one test only the document's owner can run.
