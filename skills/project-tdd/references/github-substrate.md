# GitHub Substrate — TDD Card Lifecycle

How to run this skill when the card is a **GitHub Issue** (`owner/repo#N`, a GitHub URL,
or `#N`/bare number inside a repo clone; beads-shaped IDs stay on the bd path — full
detection table: `project-card/references/github-substrate.md`). Every gate, mode rule, and
behavioral safeguard in SKILL.md applies unchanged — this file only maps the card
storage commands. Use the **gh CLI**; the GitHub MCP server lacks the needed surface.

## Mode Resolution on GitHub (same order as SKILL.md)

1. Explicit arg `lite`/`full` wins.
2. `tdd:lite` label on the issue: `gh issue view N -R owner/repo --json labels`
3. `tdd:lite` label on the parent epic: `--json parent` → view parent's labels
4. Default: full. Hard guardrail escalation unchanged.

## Gate 0 — Epic Context (GitHub form)

```bash
REPO=owner/repo; N=<issue-number>
# 1. No bd dolt pull needed — GitHub is server-authoritative. Fetch fresh state:
gh issue view $N -R $REPO --json title,body,labels,state,parent,blockedBy,milestone,url
# READ THE PHASE 0 PREAMBLE at the top of the body. Not decorative.

# 2. Epic + all children + completion % (native):
EPIC=$(gh issue view $N -R $REPO --json parent --jq '.parent.number // empty')
gh issue view $EPIC -R $REPO --json title,subIssuesSummary,subIssues \
  --jq '{title, done: .subIssuesSummary.completed, total: .subIssuesSummary.total,
         children: [.subIssues[] | {number, title, state}]}'

# 3. Blockers must be closed before starting:
gh issue view $N -R $REPO --json blockedBy \
  --jq '[.blockedBy[] | select(.state != "CLOSED")] | if length==0 then "UNBLOCKED" else . end'
# (If the blockedBy shape ever differs, fall back to:
#  gh api graphql -f query='query{repository(owner:"O",name:"R"){issue(number:N){
#    blockedByIssues(first:20){nodes{number state}}}}' )

# 4. Label hygiene: exactly one sp:* label (no inheritance on GitHub, but verify).

# 5-6. Present the execution summary (same format as SKILL.md), confirm phase.

# 7. FULL MODE ONLY — create the close gate (label, not bd gate):
gh issue edit $N -R $REPO --add-label "gate:ac-verify"
# Optionally move the board item: gh project item-edit (Status -> In Progress).
```

Lite mode: steps 1–4 unchanged, summary collapses to the one-liner, step 7 SKIPPED —
same contract as SKILL.md. Sub-step for the summary when the epic is large:
`subIssues` returns each child's `number,title,state` — enough to render the phased
table without extra calls; add per-child `sp:*`/estimate detail only for the active phase.

## Mid-Card Notes and Evidence (Gate 18)

Live-test proof goes in an **issue comment** before close:

```bash
gh issue comment $N -R $REPO --body-file /tmp/evidence.md   # paste real output, not narration
```

## Card Close Protocol (GitHub form)

1. Gate 21: re-read every `- [ ]` in the body (`gh issue view $N --json body`).
2. Gate 22 (full mode): run `/project-ac-verify owner/repo#N`. On PASS it removes the
   `gate:ac-verify` label and posts the verification comment. **Never close while the
   label is present** — on repos with the enforcement Action, the close will be
   auto-reopened; without it, the label is still the contract. There is no `--force`
   equivalent: removing the label yourself IS the bypass, and it is prohibited.
   Lite mode: self-verify + ONE consolidated evidence comment (no gate label exists).
3. Close with actual-vs-estimate in the comment:
   ```bash
   gh issue close $N -R $REPO -c "Done. Estimated ~12 min, actual ~8 min. <summary>"
   ```
   Optionally move the board item to Done (`gh project item-edit`).
4. **Suggest next card** — GitHub form of `bd ready`, scoped to the same epic first:
   ```bash
   gh issue view $EPIC -R $REPO --json subIssues \
     --jq '[.subIssues[] | select(.state=="OPEN")] | .[0:5]'
   # then filter to those whose blockedBy are all CLOSED (loop gh issue view --json blockedBy)
   ```
   Present ONE line: `Next: owner/repo#N — <title> (<sp>, ~<est>) — <reason>`.
5. **Commits/pushes remain user-requested only.** Closing an issue is a tracker
   operation, not a git operation — the standing git policy is unchanged.

## What Has No GitHub Equivalent (and what replaces it)

| beads mechanism | GitHub replacement |
|---|---|
| `bd dolt pull` (sync) | none needed — always-fresh server reads |
| `bd gate` blocking close mechanically | `gate:ac-verify` label + per-repo reopen Action (see project-ac-verify/references/github-substrate.md) |
| `bd close --force` (auditable bypass) | none — deliberately. Ask the user; label removal without a PASS is prohibited |
| `bd ready` | epic `subIssues` OPEN + empty non-closed `blockedBy` filter (step 4 above) |
