# Hooks

Enforcement that does not depend on an agent remembering to check something.

A workflow document can only work if it is consulted. Some failures are
precisely the failure to consult it — the agent never questioned the thing the
document would have told it to question, so no instruction was ever reached.
For that class, prose is not a control. A hook is.

These are agent-harness hooks, not git hooks. They are installed once, globally,
and apply to every session and every skill — including sessions where no skill
is running at all. That is deliberate: putting a guard inside one skill only
protects the code path that runs that skill.

## write-target-guard.sh

**Enforces:** no file may be mutated inside a git working tree, and no mutating
git command may run in one, until that tree has been declared a **write
target** for the current session. A write target is a `(root path, branch)`
pair, rendered everywhere as `<path> @ <branch>`.

*(Formerly `worktree-target-guard.sh`. Renamed 2026-08-10: "write target" names
the function — where writes may land — and stays true for a plain clone, a git
worktree, or a CI runner's detached checkout. The target is the checkout ROOT,
so two worktrees of one repository are two distinct targets — that distinction
is the original reason this guard exists.)*

**The problem it solves.** A shell's working directory is not a statement of
intent. It drifts — a subshell, a tool that resets it, a session resumed
elsewhere — and an agent that reads its location as its assignment will do
careful, correct work on the wrong branch. Repositories with multiple checkouts
make this sharper: several directories share one history, each sitting on a
different branch, and nothing in a task description says which one the task
belongs to. The work looks right, passes its tests, and lands somewhere it does
not belong.

**How it behaves.** On the first write into any git working tree, the guard
denies and reports the resolved target, then applies a two-case contract
(revised 2026-08-10) decided by what the user actually said:

- **Case 1 — the user named this tree in the current exchange** ("put it in
  `<dir>`", "fix the hook", "card it there"): the agent declares the target
  itself, citing the user's words via `--cite`. The banner and the session's
  declaration log are the audit trail.
- **Case 2 — nothing the user said names this tree** (shell location,
  precedent, inference): the agent states the target in one line and WAITS for
  the user's answer before declaring.

The asymmetry is what makes case 1 safe: the incident this guard exists for —
work landing in the wrong checkout because the shell happened to be there —
cannot produce a citation, because nobody said it. Once declared, a target is
unblocked for the rest of the session. Any other checkout, or the same checkout
on a different branch, is still blocked.

```
BLOCKED — undeclared write target.

About to write: /path/to/repo/src/thing.ts
  target : /path/to/repo @ feature/something

This session's declared write targets: (nothing declared in this session)
...
```

To clear a denial:

```bash
# case 1 — the user named the tree; cite their words:
bash hooks/declare-write-target.sh --session <id> --cite "put it in path/to/repo" /path/to/repo
# case 2 — after the user answers the stated ask:
bash hooks/declare-write-target.sh --session <id> /path/to/repo
bash hooks/declare-write-target.sh --session <id> --list
```

The session id is supplied by the denial message rather than guessed, so a
declaration cannot land in a different concurrently running session. The script
prints a banner to stdout — every declaration is visible, citations are shown
in it and appended to `<session>.log`, and the banner says so explicitly when a
second distinct repository joins a session, because that is the shape
accidental drift takes.

### What it covers

| Surface | Enforced | Why |
|---|---|---|
| `Write`, `Edit`, `NotebookEdit` | Yes | The file path is a structured field — the target is resolved exactly, never parsed out of text. |
| `Bash`, mutating git verbs | Yes | `commit`, `add`, `push`, `checkout`, `switch`, `rebase`, `reset`, `revert`, `cherry-pick`, `restore`, `merge`, `am`, `apply`, `clean`, `rm`, `mv`, `stash` (except `stash list`/`show`). An explicit `-C <path>` is honoured. |
| `Bash`, read-only git | No | `status`, `log`, `diff`, `branch`, `rev-parse`, `stash list` are never blocked. Checking where you are must always be possible. |
| Paths outside any git tree | No | Temp directories, scratch space, and agent configuration are out of scope. |

Symlinked directories resolve to the real repository, so editing a symlinked
skill inside a checkout is guarded as an edit to that checkout.

### What it does not cover

Stated plainly, because a guard believed to cover more than it does is worse
than no guard.

- **In-place edits through a shell** — `perl -i`, `tee`, output redirection.
  Catching those means parsing arbitrary shell, which produces false denials,
  and a guard that blocks legitimate work gets switched off.
- **Whether the task belongs on the declared branch.** The guard enforces that a
  target was chosen *deliberately*, not that it was chosen *correctly*. Work
  from an unrelated subsystem, done on a branch that was legitimately declared
  for other work, passes. Only a per-task target check catches that.
- **Case classification.** Whether the user "named this tree" is judged by the
  agent from conversation the hook cannot see. The control on that judgment is
  the visible banner plus the citation log — misuse is detectable, not
  impossible.

### Failure posture

Fails **open** on infrastructure problems — no `jq`, no `git`, unparseable
input. A guard that blocks every write because of its own bug is worse than the
drift it prevents. It fails **closed** only on the check itself.

## The AC-verify enforcement set

Four hooks implement the acceptance-criteria gate: the model may close its own
card only against evidence it could not have forged, and only so often before a
human looks. They arrived here on 2026-08-11 from `~/.claude/hooks`, where they
had lived untracked — the enforcement layer for a review process was the one
thing under no review.

**Installation model: copy, with provenance and verification — not symlinks.**
The agent's hook directory holds real files installed from a known ref of this
repository. Symlinking the installed path at a working tree was tried and
rejected the same day: it makes the *checked-out branch* the running
enforcement, so an ordinary `git switch` silently changes — or, for a branch
that does not track these files, removes — the live control plane, and a missing
gate hook prints nothing, which the harness reads as ALLOW. It also cannot
survive versioned releases, where the thing you install is a release artifact
rather than somebody's working tree.

Copies alone are not the answer either: two copies with no comparison is the
divergence this move was meant to end. The completed model is the one packaging
systems already use — install a copy, record a manifest of source ref plus
per-file SHA-256, and verify installed-against-source on demand (`rpm -V`,
`debsums`, and `pre-commit`'s self-reinstall are the same idea). **The install
script and its verify command are card `mitre-saf-skills-ed8`; until it lands,
the installed copies were placed by hand and confirmed byte-identical to this
directory on 2026-08-11.** Re-verify at any time with:

```bash
for f in hooks/ac-*.sh; do cmp -s "$f" ~/.claude/hooks/"$(basename $f)" \
  || echo "DRIFT: $f"; done
```

### ac-review-prompt.sh

Generates the reviewer's prompt mechanically from the card: the acceptance
criteria, the anti-patterns, every card note, and a diff scoped to the paths the
card's own Files section names — working-tree inclusive, so staged-versus-worktree
divergence is visible to the reviewer. Criteria and diff are written to disk and
pinned by SHA-256. **The implementing agent chooses neither what the reviewer
reads nor what it is asked.**

### ac-review-agent-block.sh

Denies any review the agent hand-wrote. A spawn that looks like an AC review must
contain the canonical prompt **verbatim** — containment is checked by regenerating
it and comparing on collapsed whitespace. Passing the prompt *by file reference*
is denied too, which is not over-strictness: indirection is indistinguishable
from substitution at the point of the check.

### ac-gate-tiered.sh

The gate itself, on `bd gate resolve`. **Tier 2** allows self-resolution only when
a verdict artifact exists, names this card, says PASS, and its embedded hashes
match hashes the hook **re-derives from the current tree** — so any edit after the
review makes the PASS stale. **Tier 1** reserves the human's key for: the
`human-gate` label, a card that flapped (≥2 recorded FAIL verdicts), spent credit,
and anything it cannot positively verify. `bd close --force` is always denied, and
closing a gate directly is denied because resolution is where the checks live.

### ac-audit-ledger.sh

The credit accounting the budget rests on — `key`, `count`, `list`, `record`,
`ack`. The quantity is self-resolutions **outstanding**, `|emitted| − |audited|`,
and only the human's `ack` returns capacity:

```bash
ac-audit-ledger.sh list "$(ac-audit-ledger.sh key)"   # what am I owed a look at?
ac-audit-ledger.sh ack  "$(ac-audit-ledger.sh key)"   # reviewed — restore credit
```

Keyed on `<repo>@<branch>`, never on a session id. Until 2026-08-11 this was a
bare `wc -l` over a session-keyed ledger with **no drain at all**, so an audited
budget stayed spent and blocked the next day's work; time-based fixes were
rejected because the clock cannot discharge an audit obligation. Full rationale,
prior art and rejected designs are in that script's header.

## The card and skill-invocation gates

The same reasoning, applied earlier in the workflow: a card that is not properly
formed cannot be reviewed against, and a review that was never run cannot be
cited. These arrived here on 2026-08-11 with the set above, for the same reason
— unversioned enforcement is unreviewable enforcement.

### validate-bd-create.sh

Blocks `bd create` unless the description carries all twelve mandatory card
sections. Exit 0 allows, exit 2 blocks with the missing sections named on stderr.

It reads the body out of a file when the command passes one by substitution
(`--description="$(cat /path/card.md)"`) — the flow `project-card` mandates,
because a card body must never travel through a shell heredoc, where backticks
in card prose execute and safety tooling matches ordinary English inside the
text.

**Defect fixed 2026-08-11:** the accepted path pattern was `/tmp/...` only. On
macOS the per-session scratchpad is `/private/tmp/...` (and `/tmp` is a symlink
to it), so the file was never opened and the hook reported all twelve sections
missing on a card that had all twelve — pushing the author toward precisely the
two things the rules forbid, an inline heredoc or a hard-coded directory. Any
absolute path is now accepted. Regression covered by
`tests/test_validate_bd_create.py` case 2, mutation-confirmed.

### gate22-require-skill.sh / gate22-mark-skill.sh

`require` enforces that Gate 22 is satisfied by *invoking* the
`project-ac-verify` skill, not by a hand-written stand-in — prose in the skill
did not prevent that substitution on 2026-08-09, so it became a hook. `mark`
records each real invocation, with its card, as an audit trail.

**Known inconsistency, recorded rather than papered over:** `ac-gate-tiered.sh`
cites the marker as an independent cross-check in its honesty statement, while
`gate22-mark-skill.sh` states that nothing reads it any more. Both cannot be
true. Either the gate should consult it or the claim should be dropped; until
that is decided the marker is an audit log, not a control.

### validate-settings.sh

Checks that the agent's `settings.local.json` is well-formed JSON. Small, but
the settings file is what wires every other hook — a corrupted one disables the
whole layer silently.

### Tests

`tests/test_ac_gate_hook.py` runs all five suites (49 cases). They target hooks
that exist — a point worth stating, because the suite this replaced pointed at a
hook that had been deleted, and since a missing hook prints nothing and the
harness reads silence as ALLOW, its DENY cases failed unnoticed for weeks.

```bash
python3 hooks/tests/test_ac_gate_hook.py
```

**Coverage is honest, not complete.** Covered: credit accounting, the gate's
tiers, the agent block, the card gate, and the four session/compaction hooks.
Not covered: the gate's stale-hash and clean-allow paths (they need the canonical
generator plus a real git tree — card `mitre-saf-skills-x6r.4`), the gate22 pair,
and `write-target-guard.sh`. Untested enforcement is how the defects fixed on
2026-08-11/12 survived, so treat that list as debt rather than as scope.

The session-hook suite pins one regression deliberately:
`pre-compact-save-state.sh` **must not write recovery files**. Writing recovery
state belongs to the `/prepare-compact` skill the user invokes, never to a hook
that fires automatically — and a stale copy of that hook, carrying the original
file-writing behavior, was found in a second repository on 2026-08-12 where an
apply would have restored it silently. The test fails if the behavior returns.

## Session and compaction hooks

Not gates — these shape what the agent knows rather than what it may do. They
are here for the same reason as the gates: behavior-shaping machinery that
exists on one machine and nowhere else cannot be reviewed or restored.

- **`session-start-rules.sh`** — prints the authorship rules at session start,
  where they cannot be missed. Prominence is the point; the same text in a file
  the agent may or may not read is not equivalent.
- **`pre-compact-save-state.sh`** — PreCompact reminder, and cleans up beads
  worktrees that would otherwise block git operations. It deliberately does NOT
  write recovery files: that belongs to the `prepare-compact` skill, which the
  user invokes. A hook that wrote them would make a user-invoked operation
  automatic.
- **`post-compact-restore-state.sh`** — loads recovery context after a compact
  and validates that settings are not corrupted.

## One installation model (unified 2026-08-12)

Every hook runs from a copy in `~/.claude/hooks`, and `settings.json` names only
paths there. The repository is the source; it is never the runtime.

Until 2026-08-12 `write-target-guard.sh` and `declare-write-target.sh` were the
exception: `settings.json` invoked them **at their repository path**, with no
installed copy. That was a live hazard rather than an untidiness. The hooks
directory is tracked on a feature branch and absent from `main`, so `git switch
main` deletes it from the working tree — and the file `settings.json` points at
for the guard that protects *every write* would simply cease to exist, silently.
A control whose presence depends on which branch is checked out is not a control.

Both are now installed copies like the rest. `write-target-guard.sh` resolves its
`declare-write-target.sh` sibling via `${BASH_SOURCE[0]%/*}`, so the guidance it
prints points at whichever copy is running — install both together or neither.

What remains for card `mitre-saf-skills-ed8` is the *provenance* half: an
`install.sh` that records the source ref and per-file SHA-256, and a `--verify`
that detects drift. Until it lands, installation is by hand and drift is found
with the loop above — which is not theoretical: editing a hook in the repo left
the installed copy stale within minutes on 2026-08-12, and the stale copy is what
runs.

## Installation

Register in the agent's global settings so the guard applies everywhere, not
only in the repository that holds it:

```jsonc
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [{ "type": "command",
                    "command": "bash /path/to/mitre-saf-skills/hooks/write-target-guard.sh",
                    "timeout": 10000 }] },
      { "matcher": "Write|Edit|NotebookEdit",
        "hooks": [{ "type": "command",
                    "command": "bash /path/to/mitre-saf-skills/hooks/write-target-guard.sh",
                    "timeout": 10000 }] }
    ]
  }
}
```

Session state is written to `~/.claude/state/write-target/<session-id>.tsv` —
one tab-separated `root<TAB>branch` line per approved target — with a
companion `<session-id>.log` recording each declaration's timestamp and
citation. Nothing is written inside any repository.

## Requirements

`bash`, `git`, `jq`, `perl`. All are present by default on macOS and on common
Linux images.
