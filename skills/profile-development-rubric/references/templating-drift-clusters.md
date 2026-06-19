# Templating-drift anti-patterns observed in MITRE profiles

When a profile is generated via `saf delta` (or any other STIG-to-InSpec templating tool), the tool produces correct bodies for some control IDs and copy-templates incorrect assertions onto sibling controls whose individual check texts differ. The siblings then ship with assertions that don't match their actual check text.

This file documents two clusters observed during an Amazon Linux 2023 STIG baseline review. The same shape recurs on every new profile derived via templating — search for it explicitly.

Linked from [SKILL.md](../SKILL.md) — Phase 1 "templated cluster" note.

## Cluster 1 — Audit `-S all` over-asserted on auditd watch rules

### What it is

Six AL2023 controls assert that an auditd rule contains `-S all`, but their STIG check texts contain no such substring:

- SV-274093 (`/usr/bin/kmod`)
- SV-274095 (`/usr/sbin/usermod`)
- SV-274098 (`/etc/sudoers`)
- SV-274099 (`/etc/sudoers.d`)
- SV-274100 (`/etc/shadow`)
- SV-274105 (`/etc/passwd`)

### Why it happened

The template source for the cluster is SV-274112 (sudo command auditing), whose STIG check text legitimately contains:

```
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=unset -S all -k privileged-priv_change
```

The `-S all` is correct for SV-274112 because that rule actually has a `-S all` syscall filter. The templating step copied the full assertion shape — including `match(/-S\s+all\b/)` — to the six siblings whose own check text is a *file-watch* rule of the form `-w /path -p wa -k key`, with no `-S all` to match.

### How to spot it on a future profile

For each control in a "looks like a templated set" cluster:

1. Open the individual STIG `desc 'check'` text.
2. Diff the literal strings in the check text against the regex literals in the body of the control.
3. Anywhere the body asserts a substring that doesn't appear in the check text — that's drift.

Quick command to find candidates in any AL/RHEL audit-rules cluster:

```bash
grep -l "match.*-S\s\+all" controls/*.rb | while read f; do
  grep -q "\-S\s\+all" "$f" || echo "DRIFT: $f"
done
```

(Look for files that match the regex literal but whose `desc 'check'` doesn't contain the asserted substring. The exact grep above is illustrative — the real check is "regex asserted ∧ substring absent from `desc 'check'`".)

### Fix

Remove the unwarranted assertion, leaving only the assertions that match the actual check text. Reference fix commit: `c6a459d` on `mitre/amazon-linux-2023-stig-baseline`.

## Cluster 2 — pwquality `.conf.d/` drop-file directory missed

### What it is

Six AL2023 controls read only `/etc/security/pwquality.conf`, even though their STIG check texts explicitly say to grep both the main file and the `.conf.d/` directory:

- SV-274133, SV-274134, SV-274135, SV-274137, SV-274138, SV-274140

### Why it happened

Two sibling controls (SV-274136 and SV-274139) were authored correctly with the manual file-list pattern: `files = ['/etc/security/pwquality.conf'] + Dir.glob('/etc/security/pwquality.conf.d/*.conf')`. The other six were either templated before the drop-file pattern was added, or templated from an older RHEL profile that predates the drop-file directory. Either way, they shipped reading only the main file.

A hardened system that puts the policy in `/etc/security/pwquality.conf.d/50-fips.conf` would pass on SV-274136 / SV-274139 and *fail* on the other six — same machine, contradictory results.

### How to spot it on a future profile

1. For every control whose check text mentions a `*.conf.d/` directory, grep the corresponding `controls/*.rb` for the `Dir.glob` of that directory.
2. Anywhere the check text mentions both locations but the body only opens one file — that's drift.

### Fix

Mirror the canonical pattern from SV-274136 / SV-274139. See [worked-example-pwquality.md](worked-example-pwquality.md) for the full walkthrough and code. Reference fix commit: `81dbb7e` on `mitre/amazon-linux-2023-stig-baseline`.

## How to generalize this for any new profile

Both clusters above are instances of the same root pattern: **a templating step copied the right body for one control onto N siblings, then nobody re-validated each sibling's `desc 'check'` text against its body.**

Whenever you encounter a derived profile (saf delta, RHEL→AL port, RHEL→Ubuntu port, AL2→AL2023 bump), include a `Phase 1` step that explicitly diffs each control's `desc 'check'` text against the literal strings in its body. The cost is one extra read per control. The savings is not shipping six broken controls per cluster.

When you find a new cluster, document it here so future reviews know the pattern by name.
