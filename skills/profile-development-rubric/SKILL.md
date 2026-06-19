---
name: profile-development-rubric
description: Use when writing, reviewing, or fixing a single SAF/HDF-style InSpec control — STIG, CIS Benchmark, AWS/Azure/GCP best-practice baseline, application baseline, or any profile that emits Heimdall Data Format results. Apply when deciding what "done" means for a control, picking the right InSpec resource instead of raw shell pipelines, framing describe blocks for clear evaluator output, generalizing checks via inputs, attaching the right compliance metadata (CCIs, NIST 800-53, CIS controls, CSF, etc.), or porting controls between vendor baselines (RHEL/AL/Ubuntu/Windows/cloud/k8s).
compatibility: Requires InSpec CLI (chef/inspec or CINC Auditor) and familiarity with STIG/CIS check text
license: Apache-2.0
metadata:
  type: methodology
---

# Profile Development Rubric

## What this skill does

This skill captures the methodology MITRE SAF uses to decide when an InSpec control is "done" and to write controls whose evaluator output a human can actually read. It applies to the full SAF/HDF profile family — DISA STIGs, CIS Benchmarks, AWS/Azure/GCP best-practice baselines, Kubernetes baselines, application baselines, and any other profile whose results land in Heimdall. It is **vendor- and framework-agnostic**: the same rubric applies whether the target is RHEL, Amazon Linux, Ubuntu, Windows Server, a cloud account, or a Kubernetes cluster.

Apply it one control at a time: read the source guidance end-to-end (STIG check/fix, CIS Audit/Remediation, cloud Description/Rationale/Audit), pick the right InSpec resource (almost never raw `command()`), frame a describe block whose subject reads like a sentence, write the assertion with a "find the outsiders" failure message, generalize fixed thresholds through `input(...)`, attach the right metadata tags (`cci`, `nist`, `cis_controls`, etc.), and gate with `only_if` where the source guidance calls out N/A or N/R conditions. The output of a control reviewed this way is a report line that says *what passed*, *what failed*, and *which items failed* — not a wall of `grep` output.

**REQUIRED BACKGROUND for cross-framework porting:** see the derive-cci-mappings skill for CCI/NIST tag derivation when adapting controls between frameworks (CIS → NIST → DISA CCI, etc.).

## The Six Outcomes (the SAF yardstick)

A control is "done" when every one of these is true for *both* a vanilla target and a hardened target (see saf-training lesson 09 for the source):

1. **Passes-as-expected on hardened** — the test communicates success clearly on a properly configured target.
2. **Fails-as-expected on vanilla** — the test communicates failure clearly on a misconfigured target, and the failure message *names the offending items*.
3. **Passes-as-expected on vanilla when the vanilla target happens to be compliant** — e.g. a container image that already ships with the required setting, or a cloud account already provisioned with the recommended control.
4. **Fails-as-expected on hardened when something has drifted** — same clarity, hardened side.
5. **Articulates Not Applicable (N/A) clearly** — via `only_if(... impact: 0.0)` (or `impact 0.0` + `describe ... skip ... end` for branchy cases) when *the source guidance explicitly authorizes N/A* OR strong observational evidence confirms the control doesn't apply (container vs host kernel, FIPS-not-required, MFA-not-required, smart-card-disabled, etc.). N/A requires *justification anchored in the check text or environment*, not author convenience.
6. **Articulates Not Reviewed (N/R) clearly** — via `describe ... do skip 'reason' end` (impact unchanged) when the check genuinely *cannot be performed automatically* — PPSM/CLSA review, cloud-console inspection, attestation-only evidence, or operator-declared alternative implementations. The skip message MUST name the input/condition that triggered the bypass so an auditor knows which knob to flip.

Plus one operational rule: **the control must not produce profile errors** — no exceptions thrown from missing files, missing services, empty `find` results, unset inputs, or unreachable cloud APIs. When the check text says "for every X..." and there happen to be zero Xs, that's **pass-when-empty** (Outcome 3 / vacuous truth), *not* N/A — see the next section.

If any of these six is missing, the control is not done. Re-read this list every time you think a control is finished.

## N/A vs N/R vs Pass-when-empty — pick the right outcome type

The most common author mistake is conflating "I can't find any items to check" with "this control is Not Applicable." Three different outcomes that report differently in Heimdall.

**Decision rule** — ask: *does the source check text explicitly authorize Not Applicable for this case?*

- **Yes, explicit N/A** → `impact 0.0` + `only_if` (or `if ... impact 0.0; describe ... skip ... end`).
- **No, but check is "for every X..." with zero Xs** → pass-when-empty. Run the assertion; an empty list satisfies it vacuously. **Do not flip impact.**
- **Check requires human judgment / out-of-band data / attestation** → N/R via `describe ... skip ... end`. Impact unchanged.

The check text is the authority. Don't infer N/A from "no items found" — that misreports compliance status.

### N/A — `impact 0.0`, control removed from the compliance score

**Use when** the check text verbatim authorizes N/A ("Note: if the SA demonstrates Y, this is not applicable"), OR observable environment makes the control physically inapplicable (container vs host kernel, FIPS-not-required, smart-card-disabled), OR an operator declares N/A via a purpose-built input (`use_fips == false`, `mfa_required == false`).

```ruby
# Single-condition N/A — only_if at the top of the body
only_if('This control is Not Applicable to containers', impact: 0.0) {
  !virtualization.system.eql?('docker')
}

# Stacked N/A predicates — both must hold for the control to apply
only_if('MFA not required per ISSO/AO exemption', impact: 0.0) { input('mfa_required') == true }
only_if('Smart-card authentication is not enabled', impact: 0.0) { input('smart_card_enabled') }

# Branchy N/A — impact 0.0 inside the if, real check in the else
if virtualization.system.eql?('docker')
  impact 0.0
  describe 'Not applicable in a container' do
    skip 'The host OS controls FIPS mode; scan the host with the OS profile.'
  end
else
  # ... real check ...
end
```

Heimdall reports as **Not Applicable**. Examples: `controls/SV-274063.rb:49-55` (stacked), `controls/SV-274057.rb:27-42` (branchy).

### N/R — `skip` alone, impact unchanged

**Use when** the check requires manual comparison against out-of-band data (PPSM/CLSA, cloud console, organizational policy), OR an operator-declared alternative implementation bypasses the automated path, OR the source literally says "ask the system administrator" with no programmatic check.

```ruby
# Input-gated alternative-implementation N/R
if input('alternative_logging_method').to_s.empty?
  # ... automated check ...
else
  describe 'rsyslog audit log transport (manual review)' do
    skip "input('alternative_logging_method') is set to '#{input('alternative_logging_method')}'; ask the administrator to confirm how rsyslog authenticates the remote logging server."
  end
end
```

**Skip-message rule:** name the input or condition that triggered the bypass. Not "Manual check required." — "`input('alternative_logging_method')` is set to '`syslog-ng`'; ask the SA to confirm X."

Heimdall reports as **Not Reviewed**. Examples: `controls/SV-274158.rb:39-41` (PPSM/CLSA), `controls/SV-274183.rb:33-35` (AWS console), `controls/SV-274077.rb:30-48` (input-gated).

### Pass-when-empty — assertion runs, vacuously satisfied

**Use when** the check text says "for every X..." / "if any X has property P, this is a finding" and there happen to be zero Xs. The check *is* performed; an empty offender list satisfies the assertion. Impact stays at the STIG-assigned value. No `skip`, no `impact 0.0`.

Shape: compute `offenders = items.select { |i| violates?(i) }`, then `expect(offenders).to be_empty, "<labelled list of offenders>"`.

Heimdall reports as **Passed** (empty) or **Failed** (offenders found) — same shape as any Phase-4a "find the outsiders" check. Don't special-case empty results. Examples: `controls/SV-274146.rb:32-55` (with explicit "Pass-when-empty" comment), `controls/SV-274150.rb`, `controls/SV-274164.rb`, `controls/SV-274165.rb`.

**Anti-pattern:** flipping `impact 0.0` for "no items found" when the source guidance doesn't authorize N/A. This fabricates a Not Applicable from a legitimate pass and misreports compliance posture.

## Before Starting — Determine the Baseline Context

If not clear from the user's request, ask:

**What type of baseline are you working on?**
- "DISA STIG" — follows the SRG-to-STIG inheritance model
- "CIS Benchmark" — uses CIS Controls mapping (invoke the derive-cci-mappings skill for CCI derivation)
- "Cloud provider baseline" — AWS/Azure/GCP best-practice (uses cloud InSpec resources from references/inspec-resources.md)
- "Kubernetes / container platform" — uses k8sobject resources
- "Custom organizational baseline"

**What platform?**
- RHEL / Amazon Linux / Ubuntu / Windows Server
- AWS / Azure / GCP
- Kubernetes / Container platform

Use the answers to point to the right section of [references/inspec-resources.md](references/inspec-resources.md) (OS vs cloud vs Kubernetes resource families) and to select the right metadata tags in Phase 6.

## The Six Phases of a Control Review

Apply these in order. Don't skip ahead — phase 3 fails badly if phase 1 was sloppy.

### Phase 1 — Read the source guidance end-to-end

Profile-family translation table (read whichever applies to your source):

| Framework | What to read |
|---|---|
| DISA STIG | `desc`, `desc 'check'`, `desc 'fix'`, all `tag satisfies` SRGs |
| CIS Benchmark | Description, Rationale, Audit, Remediation, Impact, References |
| AWS/Azure/GCP best practices (CIS Foundations, NIST OSCAL, vendor benchmarks) | Description, Rationale, Audit (CLI/console steps), Remediation |
| Application baseline (e.g. NGINX, MongoDB, K8s CIS) | Description, Audit, Remediation, profile-specific caveats |

Read every section — guidance authors regularly put validation steps in *Remediation/Fix* text or N/A caveats in *Discussion/Rationale*. Extract:
- The **target artifact**: a file path, a sysctl key, a service name, a package, a PAM module, an IAM policy, a security-group rule, a k8s manifest field, etc.
- The **expected value(s)** and any allowed equivalents (e.g. "SYSLOG, SINGLE, or HALT"; "MFA enabled OR hardware key registered").
- The **N/A conditions**: "Not applicable to containers", "Not applicable if the system uses an alternative logging method", "Not applicable to AWS Organizations master accounts", etc.
- The **N/R conditions**: "ask the system administrator", "if there is no documented exception", "evidence must be attested by the cloud account owner".
- Any **threshold or list** that should become a profile **input**: password lengths, lockout counts, allowed cipher lists, exempt user/account lists, retention days, etc.

If the guidance text says "ask the SA / account owner / DevOps lead", that's an N/R signal — plan an input-gated `skip`, not a hard assertion.

**Templated cluster — re-read each check text independently.** When the profile was generated via `saf delta` or similar, a control may share a body shape with N siblings whose individual check texts differ. *Reviewing the cluster as one* misses assertions that were copy-pasted from the source sibling and never adjusted. Open each control's `desc 'check'` text and diff it against the literal strings asserted in its body. See [references/templating-drift-clusters.md](references/templating-drift-clusters.md) for the two clusters found and fixed in AL2023 (audit `-S all` and pwquality drop-files) and how to spot the pattern on a future profile.

### Phase 2 — Pick the right InSpec resource

`command()` is the resource of last resort. Almost every check has a typed InSpec resource that already parses the artifact correctly and produces readable output — for OS targets *and* for cloud and Kubernetes targets (`aws_*`, `azurerm_*`, `google_*`, `k8sobject`, etc.). See the **Decision Table** below; full list including cloud/k8s families at [references/inspec-resources.md](references/inspec-resources.md).

The cost of picking the wrong resource is paid every time the profile runs and every time someone opens the Heimdall report: `command('grep ...')` dumps raw shell output into the report; `parse_config_file(...)` (or `aws_iam_password_policy`, or `k8sobject(...)`) gives you a typed value and a one-line pass/fail. See [references/good-bad-patterns.md](references/good-bad-patterns.md) for six paired examples of the wrong-vs-right resource choice on real controls.

**Drop-file directories — iterate both the main file AND `*.conf.d/`.** Modern Linux configs follow the `/etc/X.conf` + `/etc/X.conf.d/*.conf` pattern. When the check text mentions *both* locations (it usually does), reading only the main file produces false findings on hardened systems that use drop-files and misses conflicting settings on misconfigured ones. Some resources already iterate drop-files for you — `kernel_parameter` (sysctl), `sshd_config`/`sshd_active_config` (sshd_config.d), `limits_conf`. For everything else build the file list manually:

| Main file | Drop-file glob |
|---|---|
| `/etc/security/pwquality.conf` | `/etc/security/pwquality.conf.d/*.conf` |
| `/etc/sysctl.conf` | `/etc/sysctl.d/*.conf` + `/usr/lib/sysctl.d/*.conf` + `/run/sysctl.d/*.conf` (use `kernel_parameter`) |
| `/etc/rsyslog.conf` | `/etc/rsyslog.d/*.conf` |
| `/etc/profile` | `/etc/profile.d/*.sh` |
| `/etc/audit/audit.rules` | `/etc/audit/rules.d/*.rules` |
| `/etc/modprobe.d/*.conf` | `/usr/lib/modprobe.d/*.conf` + `/run/modprobe.d/*.conf` |
| `/etc/sudoers` | `/etc/sudoers.d/*` |
| `/etc/security/limits.conf` | `/etc/security/limits.d/*.conf` (use `limits_conf`) |
| `/etc/sssd/sssd.conf` | `/etc/sssd/conf.d/*.conf` |

For the canonical drop-file pattern (build the file list, `flat_map` to `[path, value]` pairs, dual-it "configured at least once + valid wherever set"), see [references/worked-example-pwquality.md](references/worked-example-pwquality.md) — full Phase 1-5 walkthrough on STIG SV-274136. Reference implementation: `controls/SV-274136.rb`, `controls/SV-274139.rb` (commit `e832ba1`).

### Phase 3 — Frame the describe block with a human-readable subject

The subject of a describe block becomes the *headline* of the report line, both in the CLI runner and in Heimdall. Default RSpec behavior dumps the literal subject — for `command()` that's the entire stdout; for `aws_iam_users.where(...)` it's the whole user list. Override with either:

- a **string headline** + implicit subject (an InSpec resource): `describe aws_iam_password_policy do; its('minimum_password_length') { should cmp >= input('min_password_length') }; end`, or
- a **string headline** + `subject { ... }`: `describe 'DNF configuration' do; subject { parse_config_file('/etc/dnf/dnf.conf').params['main'] }; its('gpgcheck') { should cmp 1 }; end`.

A good headline reads like a sentence the next engineer (or auditor opening Heimdall) can scan in a 500-control report.

### Phase 4 — Write the assertion with a "find the outsiders" message AND generalize via inputs

**4a. Find the outsiders.** For tests over sets (files, users, repos, packages, IAM users, S3 buckets, k8s pods, security groups, etc.), don't assert "for each item: it must be OK". Instead:

1. Compute `failing = items.reject { compliant? }`.
2. `expect(failing).to be_empty, "Offending items:\n\t- #{failing.join("\n\t- ")}"`.

The report then says exactly which items failed, and a passing run is one line ("All S3 buckets should have default encryption enabled"). See `beginner/07.md:240-259` in saf-training for the canonical framing, and [references/good-bad-patterns.md](references/good-bad-patterns.md) §3 for a paired example.

For tests with multiple aspects (e.g. "at least one config file sets X *and* no file conflicts with X"), use **two `it` blocks inside one describe** with separate failure messages — see `RHEL9 SV-257797.rb:64-73` and `good-bad-patterns.md` §2.

**4b. Generalize fixed thresholds through `input(...)`.** This is what makes a profile reusable across vendors, organizations, and trust levels. The rule: *if the guidance text mentions a specific number, list, or path that an operator might reasonably need to override, it's an input.* Common patterns:

| Guidance says... | Make it an input named... | Default |
|---|---|---|
| "minimum password length is 15" | `min_password_length` | `15` |
| "lock account after 3 failed attempts" | `unsuccessful_attempts` | `3` |
| "retain audit logs at least 7 days" | `audit_retention_days` | `7` |
| "approved cipher list is X, Y, Z" | `approved_ciphers` | `%w[X Y Z]` |
| "exempt service accounts from this check" | `exempt_users` (or `exempt_accounts`) | `[]` |
| "this control is N/A if the org uses alternative logging" | `alternative_logging_method` | `''` |

Declare every input in `inspec.yml` with a `description`, `type`, and `value` (the default). Cite the input in the failure message so the evaluator sees both the *required* value and the *configured* value.

**4c. Construct the `failure_message` deliberately — the list IS the message.** rspec accepts a custom string as the second arg to `expect(...).to`. The default `expected ["foo","bar"] to be empty` is useless to an auditor; the custom form names the offenders and (when possible) the fix command. Build via a local variable:

- Per-item diagnostic: `failure_message = "Accounts with warndays > #{max_days}:\n\t- " + failing_users.map { |u| "#{u} (warndays=#{user(u).warndays})" }.join("\n\t- ")`.
- List + remediation hint: `failure_message = "World-writable dirs missing sticky bit (run: chmod +t <dir>):\n\t- #{ww_dirs.join("\n\t- ")}"`.

If your assertion is `expect(<set>).to be_empty`, the second argument is mandatory in this rubric. Always name the offenders; add a remediation hint when the fix is a one-liner. Examples: `controls/SV-274164.rb:38-43`, `controls/SV-274165.rb:34-39`, `controls/SV-274146.rb:48-54`, saf-training `beginner/07.md:240-259`. See [references/good-bad-patterns.md](references/good-bad-patterns.md) for paired good/bad examples of all three Phase-4 elements.

### Phase 5 — Gate with `only_if` (and inputs) for N/A and N/R

See the **N/A vs N/R vs Pass-when-empty** section above for the full decision rule, patterns, and examples. Phase-5 quick reminders:

- **N/A** via `only_if(...impact: 0.0)` at the top of the body — only when the source guidance authorizes it or environment justifies it.
- **N/R** via `describe ... skip ... end`, impact unchanged. Skip message must name the input or condition that triggered the bypass.
- **Pass-when-empty** is NOT N/A — leave impact alone and let `expect(failing).to be_empty` satisfy itself vacuously.
- Prefer `only_if` over `if/else` whenever the entire control is to be skipped — cleaner report, clearer `impact 0.0` signal in Heimdall.

**Mid-body guards: use early-return, not fall-through.** When a check has a pre-condition (file exists, command succeeded, prerequisite present), a bare `unless precondition; describe ... end` *without* a `return` falls through to the rest of the body, which then runs against the empty/missing state the guard already flagged — producing a second confusing failure. Correct shapes: early-return after the guard's `describe`, or `if/else` so the real check only runs when the precondition holds. Anti-pattern reference: `controls/SV-274142.rb:32-58` (pre-fix). This is the mid-body cousin of the top-of-body `only_if` pattern; same intent, different mechanic.

### Phase 6 — Attach the right metadata (CCIs, NIST, CIS controls, CSF, framework cross-refs)

A SAF/HDF profile is only as useful as the cross-framework rollup it enables in Heimdall. Every control should carry the tags appropriate to its source plus any frameworks it satisfies:

```ruby
tag cci: ['CCI-000366', 'CCI-001749']          # DISA CCIs (STIG and cross-mapped controls)
tag nist: ['CM-6 b', 'CM-5 (3)']                # NIST 800-53 Rev 5 controls
tag cis_controls: [{ '8' => ['4.1', '4.2'] }]   # CIS Controls v8 (CIS Benchmark profiles)
tag cis_level: 1                                # CIS profile level (1 or 2)
tag severity: 'high'                            # also drives Heimdall impact rollup
tag satisfies: ['SRG-OS-000366-GPOS-00153']     # SRGs the STIG control satisfies
```

For non-STIG profiles, derive CCIs/NIST tags via the derive-cci-mappings skill — that skill maps any framework (SCuBA, CIS, custom org guidance) to DISA CCIs through NIST 800-53. This is what lets a CIS-sourced control roll up next to a STIG-sourced one in Heimdall.

## Active vs. passive testing — and why a good control usually does both

InSpec checks fall into two complementary modes. A "done" control usually verifies *both* sides of the same requirement so that drift is caught no matter how it's introduced.

| Mode | What it observes | OS examples | Cloud / k8s examples |
|---|---|---|---|
| **Passive** (configuration) | What's *written* — config files, manifests, persisted settings, IaC | `parse_config_file('/etc/ssh/sshd_config')`, `file('/etc/sysctl.d/...').content` | `aws_s3_bucket(name).bucket_policy`, `k8sobject(...).spec` |
| **Active** (runtime / process) | What's *running* — kernel state, daemon behavior, API-reported state | `kernel_parameter(...)`, `service('sshd').running?`, `auditd` (loaded rules), `sshd_active_config` (output of `sshd -T`) | `aws_iam_user(...).has_mfa_enabled?`, `aws_security_group(id).inbound_rules`, `processes('nginx').running?` |

The "find the outsiders" pattern in Phase 4a applies identically to both modes. Wherever possible, pair them:

- *Passive* check: the config file says `kernel.dmesg_restrict = 1`.
- *Active* check: the kernel actually has `kernel.dmesg_restrict = 1` loaded.

If only one passes, the control still reports the discrepancy — drift discovered. See `RHEL9 SV-257797.rb` for a canonical paired-mode example (kernel_parameter + multi-file config scan).

## Decision Table: which InSpec resource?

This table covers OS targets — the most common case. For cloud (`aws_*`, `azurerm_*`, `google_*`) and Kubernetes (`k8sobject`) resource families, see [references/inspec-resources.md](references/inspec-resources.md).

| If the guidance says check... | Use this resource | Don't use |
|---|---|---|
| `grep KEY /path/to/file` on a key=value file | `parse_config_file(path).params['KEY']` | `command('grep ...')` |
| `sysctl kernel.X` | `kernel_parameter('kernel.X')` | `command('sysctl ...')` |
| `systemctl is-active foo` | `service('foo')` | `command('systemctl ...')` |
| `rpm -q foo` / `dpkg -l foo` | `package('foo')` | `command('rpm ...')` |
| `grep pam_X /etc/pam.d/Y` | `pam('/etc/pam.d/Y').lines` | `command('grep pam_X ...')` |
| `grep KEY /etc/audit/auditd.conf` | `auditd_conf.KEY` | `command('grep ...')` |
| auditd rule check (`auditctl -l`) | `auditd.where { ... }` | `command('auditctl -l \| grep ...')` |
| `sshd -T` / sshd_config key | `sshd_config.KEY` (or `sshd_active_config`) | `command('grep ...')` |
| `mount \| grep /X` | `mount('/X')`, `etc_fstab` | `command('mount ...')` |
| `getenforce` / SELinux check | `selinux` | `command('getenforce')` |
| `grep KEY /etc/login.defs` | `login_defs.KEY` | `command('grep ...')` |
| `grep KEY /etc/security/limits.conf` (or `.d/*`) | `limits_conf(path)` | `command('grep ...')` |
| File mode / owner / content | `file(path)` with `be_owned_by`, `be_mode`, etc. | `command('ls -l ...')` or `command('stat ...')` |
| Directory listing | `directory(path)` or iterate with the `file()` resource | `command('ls ...')` |
| `crontab -l` / cron files | `crontab(user: ...)` | `command('crontab ...')` |
| User / group attributes | `users.where { ... }`, `etc_passwd`, `etc_shadow`, `group('wheel')` | `command('getent ...')` |
| Repo file `[name]\ngpgcheck=1` | `parse_config_file('/etc/yum.repos.d/X.repo').params` | `command('grep ...')` |
| Yum/DNF main config | `parse_config_file('/etc/dnf/dnf.conf').params['main']` | `command('grep ...')` |
| `/etc/X.conf` + `/etc/X.conf.d/*.conf` (pwquality, rsyslog, sudoers, profile.d, etc.) | Manual `files = [main] + Dir.glob(dropdir)` + iterate; or `kernel_parameter`/`sshd_config`/`limits_conf` which handle drop-files internally | reading only the main file |
| Last resort: nothing else fits | `command('...')` **with `subject { ... }` and a headline** | — |

When nothing fits, see [references/inspec-resources.md](references/inspec-resources.md) for the broader catalog and links to the official docs.

## Quick Reference

| Phase | Activity | Success criterion |
|---|---|---|
| 1. Read source | Read check/Audit + fix/Remediation + discussion/Rationale end-to-end | Can name target artifact, expected value(s), inputs to generalize, N/A and N/R conditions in one sentence each |
| 2. Pick resource | Match the artifact to a typed InSpec resource from the Decision Table (OS or `references/inspec-resources.md` for cloud/k8s) | Not using `command()` unless nothing else fits |
| 3. Frame describe | Write a headline (or `subject { ... }`) that reads like a sentence | Report headline names the *requirement*, not the command output |
| 4a. Assertion | "Find the outsiders": collect failures, assert empty, name them in failure_message | A failing run lists exactly which items failed, by name; pass-when-empty is fine (impact unchanged) |
| 4b. Inputs | Move every threshold / list / exemption mentioned in the guidance into `input(...)` | The control's numeric and list literals come from inputs, not hard-coded values |
| 4c. failure_message | Build a local `failure_message` string naming the offenders and (when applicable) the fix command | Auditor reading the report knows which items failed AND how to fix them, without re-running the check |
| 5. Gates | `only_if(...impact: 0.0)` for N/A (must be guidance- or environment-justified); `skip` for N/R (impact unchanged, name the input); pass-when-empty for vacuous cases | N/A vs N/R vs pass-when-empty decision matches the check text; never use `impact 0.0` to paper over an empty result set |
| 6. Metadata | Apply `cci`, `nist`, `cis_controls`, `cis_level`, `severity`, `satisfies` tags appropriate to the source framework | Heimdall rollup attributes the control to the right framework(s) |
| Verify | Run against vanilla + hardened (container, VM, cloud account, or cluster) | All six SAF outcomes hold; no profile errors; active + passive checks agree |

## Where this is going

This skill is the methodology layer of a larger MITRE SAF Profile-Dev Toolkit. The plan for evolving it into a corpus-scale RAG-backed AI tool — cross-vendor validation, Skills API publication, MCP server for live STIG/CCI/profile lookups, vector-DB retrieval over the full SAF corpus, and a bidirectional learning loop — lives in [references/roadmap.md](references/roadmap.md).

## Supporting lessons (saf-training, deep dives)

When the rubric isn't enough, read the source. All paths relative to the [saf-training repo](https://github.com/mitre/saf-training) under `src/inspec-training/`:

- `profile-development/09.md` — "What is 'done' for a control?" (the SAF yardstick)
- `profile-development/06.md` — Testing with Docker containers (Test Kitchen + dokken)
- `profile-development/22.md` — `kitchen.container.yml` structure
- `profile-development/03.md`, `04.md`, `05.md` — environment setup + test kitchen basics
- `beginner/07.md` — explicit subject, failure_message, "find the outsiders" pattern
- `beginner/12.md` — "Steps to write an InSpec control" + login_defs walkthrough (prefer typed resources over `command`)

For cross-framework rollup (mapping CIS / SCuBA / cloud guidance to CCIs and NIST 800-53): invoke the derive-cci-mappings skill.

## Worked examples in this skill's references/

- [references/good-bad-patterns.md](references/good-bad-patterns.md) — six paired examples (raw grep vs typed resource, set checks, PAM, per-key iteration, title/body match) drawn from real AL2023 and RHEL9 controls.
- [references/worked-example-pwquality.md](references/worked-example-pwquality.md) — full Phase 1-5 walkthrough on pwquality `minlen` across `.conf` and `.conf.d/` drop-files (STIG SV-274136 / SV-274139).
- [references/templating-drift-clusters.md](references/templating-drift-clusters.md) — two anti-pattern clusters observed in AL2023 (`audit -S all` over-assertion, pwquality drop-file miss) and how to spot the templating-drift pattern on a future profile.
- [references/inspec-resources.md](references/inspec-resources.md) — full typed-resource catalog including cloud (`aws_*`, `azurerm_*`, `google_*`) and Kubernetes families.
- [references/roadmap.md](references/roadmap.md) — 5-phase plan for evolving the skill into a corpus-scale RAG-backed AI tool.
