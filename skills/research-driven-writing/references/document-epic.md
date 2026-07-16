# The Document Epic — Card Templates

Read this when setting up the lifecycle for a new document. With beads (bd) and the project-card skill, each stage below is a child card of a document epic, with dependencies wired in stage order. With any other tracker, keep the same stages and gates as checklist items.

## Epic shape

```
[EPIC] <Verb> <document> — <context>
├── E.1  Frame — question, constraints block, claims-register skeleton     (gates everything)
├── E.2  Research & sourcing — fill the register, cache sources            (blocked by E.1)
├── E.3+ Draft <section group> — one card per coherent section group       (blocked by E.2*)
├── E.R  Multi-lens review — five lenses, dedupe, adversarial verify       (blocked by all E.3+)
├── E.I  Independent review — fresh context, findings only                 (blocked by E.R)
└── E.S  Author sign-off — decisions and release                           (blocked by E.I)
```

*Section cards may start when the register rows THEY consume are VERIFIED — full-register completion is not required if the register is partitioned by section. Wire dependencies accordingly.

Sizing guidance: Frame and Research are real work, typically comparable to a section card each. Do not fold them into the first drafting card — that recreates prose-first writing with extra steps.

## Card skeletons (condensed — combine with the project-card template where in use)

### E.1 Frame
- **Deliverables:** question + reader + altitude statement; constraints block with per-item checks; claims-register skeleton; division-of-labor map if sibling documents exist.
- **Acceptance:** author has approved all four artifacts; every constraint has a check; every planned section has a scope note or is explicitly deferred.
- **Anti-patterns:** do not research yet; do not draft yet.

### E.2 Research & sourcing
- **Deliverables:** register rows moved OPEN → VERIFIED/REFUTED with pins; sources cached; do-not-resurrect list started.
- **Acceptance:** zero OPEN rows among claims the planned sections consume; every VERIFIED row's pin re-derivable by a stranger in under a minute; convenient facts show evidence of a refutation attempt.
- **Decision points:** any claim that cannot be verified from a primary source → author decides (drop, hedge explicitly, or accept with stated basis).

### E.3+ Section drafting (one card per section group)
- **Deliverables:** prose for the named sections, drafted only from the register.
- **Acceptance:** every load-bearing sentence traces to a VERIFIED row; scope note fully covered; mechanical battery green; no new unregistered claims (mid-draft claims went through the register first).
- **Anti-patterns:** do not "improve" author concepts (fidelity lens will catch it — save the round-trip); do not exceed the scope note; no prose ahead of pins.

### E.R Multi-lens review
- **Deliverables:** findings from all five lenses; dedupe; adversarial verification verdicts; confirmed fixes applied; rejected findings dispositioned with reasons.
- **Acceptance:** loop ran until a round produced no confirmed findings; battery green after final fixes; substantive-claim findings routed to the author, not decided.
- **State the review's scale before launching** (how many reviewers/sessions, what depth) and get the author's confirmation if it is large.

### E.I Independent review
- **Deliverables:** the fresh-context report (see the review-lenses reference for the prompt): AC verification, five-worst-claims spot check, weakest-claim judgment.
- **Acceptance:** report delivered findings-only; any findings triaged through the same adversarial-verify pipeline; author sees the report verbatim.

### E.S Author sign-off
- **Deliverables:** author decisions on all routed items; final read; release/distribution call.
- **Acceptance:** author has explicitly approved — silence is not approval. Distribution, attribution, and licensing wording are the author's alone.

## Verification lines (put the real commands on the cards)

Each card's verification is executable, not aspirational. Examples:

```bash
# E.3+ / E.R: the document's mechanical battery (defined in E.1's constraints block)
grep -icE "<forbidden-markers>" <doc>        # 0
grep -n "<Acronym> (" <doc> | sort -u        # one expansion
# E.2: register completeness for the sections about to draft
grep -c "OPEN" <register>                    # 0 among consumed rows
```

## Reviving a stale document epic

A document untouched for months re-enters at E.2, not E.3: re-verify every pin against its source (versions move, links die, "current" claims age), re-open stale rows, then resume drafting. Skipping re-verification on revival is the most common way a once-green document ships red.
