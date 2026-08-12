# Execution Summary — "You Are Here" Format (Gate 0 step 5)

The Gate 0 summary is an **accordion**, not a full dump: every phase collapses to a
one-line progress bar, and ONLY the phase holding the active card expands to its
cards. This follows Shneiderman's "overview first, … details-on-demand" — the whole
epic stays in view while the card you're about to work gets card-level detail.
(Info-viz: Shneiderman 1996 "The Eyes Have It"; CLI UX: clig.dev.)

**Generate every field from `bd` — never hand-type it.** Hand-assembly is how a card
lands in the wrong phase, a dependency is missed, or a count is wrong (a real miss:
an agent asserted "bd has no tree command" and mis-drew the graph instead of running
`bd graph`). Sources:

| Field | Command |
|---|---|
| overall `n/m · P%` + bar | `bd epic status <epic-id>` |
| phase membership + bars (one cell per child, filled = closed) | `bd graph --compact <epic-id>` (dependency layers) |
| expanded active-phase cards + status glyph + `sp:` | `bd children <phase>` / `bd graph`, labels for sp |
| each card's `⋯ needs X` | the **unmet** deps in `bd dep list <card-id>` |
| `◀ THIS CARD` | the card being started |

Phase **names** ("Call-site migrations") are a curated overlay — use them only if the
epic defines them; otherwise the robust backbone is the `bd graph` layer number
(`Layer 6 of 9`). Never invent phase names to fill the slot.

## Canonical render (color / TTY)

```
heimdall2-e25 · PBKDF2 FIPS hashing
progress  ███████░░░░░░░░░░░░░  10/29 · 34%

 DONE   P1  Pure crypto foundation      [█████]  5/5
 DONE   P2  Service + persistence       [█████]  5/5
 NOW →  P3  Call-site migrations        [░░░░░░] 0/6   ← YOU ARE HERE
          ├─ ▶ e25.11  shorten placeholder       sp:1   ◀ THIS CARD (ready)
          ├─ ○ e25.14  validateUser · keystone   sp:3   ⋯ needs e25.11
          ├─ ○ e25.15  validateApiKey            sp:3   ⋯ needs e25.14
          ├─ ○ e25.12  hash sites 1,2,7          sp:3
          ├─ ○ e25.17  lifecycle regression      sp:2
          └─ ○ e25.18  configurable complexity   sp:3
 next   P4  Runtime safety + rollout    [░░░░░]  0/5
 next   P5  Admin migration surface     [░░]     0/2
 next   P6  Packaging · deploy          [░░░░░░] 0/6

 legend  ✓ done · ▶ doing · ○ ready · ⊘ blocked
```

## Plain fallback — REQUIRED when stdout is not a TTY, `NO_COLOR` is set, `TERM=dumb`, or `--plain`

Same layout, ASCII only (clig.dev: "humans first … disable color if not in a terminal
or the user requested it"). Status still reads without color because it is carried by
the `DONE/NOW/next` word and the `[x]/[>]/[ ]` glyph — never by color alone
(WCAG 1.4.1, Use of Color).

```
heimdall2-e25 . PBKDF2 FIPS hashing
progress  [#######.............]  10/29 . 34%

 DONE   P1  Pure crypto foundation      [#####]  5/5
 DONE   P2  Service + persistence       [#####]  5/5
 NOW >  P3  Call-site migrations        [......] 0/6   <- YOU ARE HERE
          |- [>] e25.11  shorten placeholder      sp:1   <- THIS CARD (ready)
          |- [ ] e25.14  validateUser (keystone)  sp:3   .. needs e25.11
          |- [ ] e25.15  validateApiKey           sp:3   .. needs e25.14
          |- [ ] e25.12  hash sites 1,2,7         sp:3
          |- [ ] e25.17  lifecycle regression     sp:2
          `- [ ] e25.18  configurable complexity  sp:3
 next   P4  Runtime safety + rollout    [.....]  0/5
 next   P5  Admin migration surface     [..]     0/2
 next   P6  Packaging + deploy          [......] 0/6
```

## Format rules

- **Accordion:** collapse every phase to one line; expand ONLY the phase containing the
  active card. Do not dump all cards of every phase — that is the old format and it
  causes banner-blindness on card 15 of 29.
- **One cell per card** in each phase bar; a filled cell = a closed card. The bar length
  *is* the card count — it carries data, not decoration. Always bracket it (`[░░]`) so a
  zero-progress phase still reads as a bar, not whitespace.
- **Status is never color-only.** Phase rows lead with `DONE`/`NOW →`/`next`; card rows
  lead with a glyph (`✓ ▶ ○ ⊘`, ASCII `[x] [>] [ ] [!]`). Color, if present, is redundant
  reinforcement.
- **Mark the two anchors in words:** `← YOU ARE HERE` on the active phase, `◀ THIS CARD`
  on the active card. `⋯ needs <id>` states each unmet blocker inline.
- **Width-robust:** left-aligned, no right border, keep it ≤ 80 columns so it survives a
  narrow terminal and a resize (clig.dev: honor `COLUMNS`).
- **Multiple in-flight:** if more than one card in the active phase is `▶`/`✓`/`⊘`, show
  each with its own glyph — do not assume exactly one active card.
- **Full mode** shows the accordion; **lite mode** collapses to the one-liner
  (`<epic> ███░░ n/m (P%) · Phase <k> <name> · <card-id> unblocked ✓`, bar from
  `bd epic status`).

(GitHub substrate: same format — card IDs are `#N`, counts from the epic issue's
`subIssuesSummary`, dependencies from the issue body's task-list / tracked-by links;
see `references/github-substrate.md`.)
