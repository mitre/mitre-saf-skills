# Good/Bad patterns from real InSpec profiles

Six paired examples drawn from real MITRE profiles. Each pair shows the same intent expressed badly (raw shell, cryptic report) and well (typed resource, readable report). All file citations are to real profiles you can open.

Linked from [SKILL.md](../SKILL.md) — see The Five Phases (Phase 2 + Phase 4) for the methodology these examples illustrate.

## 1. Raw grep / stdout as the describe subject

```ruby
# BAD — AL2023 SV-274187:32, SV-274155:36 — grep stdout becomes the headline;
# the report prints the command output instead of the requirement.
describe command('grep -i immutable /etc/audit/audit.rules') do
  its('stdout.strip') { should cmp '--loginuid-immutable' }
end
describe command('grep even_deny_root /etc/security/faillock.conf').stdout.strip do
  it { should match(/^even_deny_root$/) }
end
```

```ruby
# GOOD — typed resource, named subject
describe 'auditd immutable-loginuid rule' do
  subject { file('/etc/audit/audit.rules').content }
  it { should match(/^--loginuid-immutable\s*$/) }
end
describe 'faillock root-lockout policy' do
  subject { parse_config_file('/etc/security/faillock.conf').params }
  its(['even_deny_root']) { should_not be_nil }
end
```

Rationale: never let raw stdout become the describe headline — the report ends up labeled with the command output instead of the requirement.

## 2. Multi-file config with "at least one correct AND no conflicts"

```ruby
# BAD — single command pipeline, report can't distinguish "missing" from "conflicting"
describe command("grep -h kernel.dmesg_restrict /etc/sysctl.d/*.conf") do
  its('stdout') { should match(/kernel\.dmesg_restrict\s*=\s*1/) }
end
```

```ruby
# GOOD — RHEL9 SV-257797.rb:51-73 — two assertions in one describe
search_results = command("/usr/lib/systemd/systemd-sysctl --cat-config | egrep -v '^(#|;)' | grep -F kernel.dmesg_restrict").stdout.strip.split("\n")
correct = search_results.any? { |l| l.match(/^\s*kernel\.dmesg_restrict\s*=\s*1\s*$/) }
incorrect = search_results.reject { |l| l.match(/^\s*kernel\.dmesg_restrict\s*=\s*1\s*$/) }

describe 'Kernel config files' do
  it "should configure 'kernel.dmesg_restrict'" do
    expect(correct).to eq(true), 'No config file was found that correctly sets this'
  end
  it 'should not have incorrect or conflicting setting(s)' do
    expect(incorrect).to be_empty, "Conflicts:\n\t- #{incorrect.join("\n\t- ")}"
  end
end
```

Rationale: sysctl-style settings can be set in many files and a *wrong* value in any one of them silently overrides the right one. The dual-it pattern separates "missing" from "conflicting" so the report tells you which.

## 3. Set check — "find the outsiders" instead of "check everyone at the door"

```ruby
# BAD — loops describe blocks, one per item; long report and no summary
files.each do |f|
  describe file(f) do
    its('mode') { should cmp '0640' }
  end
end
```

```ruby
# GOOD — RHEL9 SV-257823.rb:42-48 — collect failures, assert empty
misconfigured = command("rpm -Va --noconfig | awk '$1 ~ /..5/ && $2 != \"c\"'").stdout.strip.split("\n")
describe 'All system file hashes' do
  it 'should match vendor hashes' do
    expect(misconfigured).to be_empty, "Misconfigured files:\n\t- #{misconfigured.join("\n\t- ")}"
  end
end
```

Rationale: one assertion, one report line, named offenders. Scales to thousands of items without flooding the report.

## 4. PAM check — typed resource

```ruby
# BAD — AL2023 SV-274151:39 / SV-274013:32 — raw grep returning stdout lines
pam_rules_check = command("grep pam_wheel /etc/pam.d/su").stdout.strip.split("\n")
describe 'PAM rules' do
  it { expect(pam_rules_check).not_to be_empty }
end
```

```ruby
# GOOD — pam resource parses the stack
describe pam('/etc/pam.d/su') do
  its('lines') { should match_pam_rule('auth required pam_wheel.so').any_with_args('use_uid') }
end
```

Rationale: the pam resource understands PAM rule syntax (control flags, module args). Raw grep can't tell `required` from `sufficient`.

## 5. Per-key iteration over a config section

```ruby
# BAD — AL2023 SV-274080:44-49 — shell pipeline inside subject, one per key
%w[URL ServerKeyFile ServerCertificateFile TrustedCertificateFile].each do |key|
  describe "journal-upload.conf setting #{key}" do
    subject { command("grep -E '^\\s*#{key}\\s*=\\s*\\S+' /etc/systemd/journal-upload.conf").stdout.strip }
    it { should_not be_empty }
  end
end
```

```ruby
# GOOD — parse the config once, iterate keys against the hash
conf = parse_config_file('/etc/systemd/journal-upload.conf').params['Upload'] || {}
%w[URL ServerKeyFile ServerCertificateFile TrustedCertificateFile].each do |key|
  describe "journal-upload.conf [Upload] #{key}" do
    subject { conf[key] }
    it { should_not be_nil }
    it { should_not be_empty }
  end
end
```

Rationale: one file read, typed access, no per-key shellouts. The report headline names the key explicitly.

## 6. Title vs. body must match

```ruby
# BAD — AL2023 SV-274107:38-49 — title says disk_full_action,
# body checks DefaultNetstreamDriver. The control passes for the wrong reason.
```

```ruby
# GOOD — body must implement what the title claims
describe 'auditd disk_full_action' do
  subject { auditd_conf.disk_full_action }
  it { should be_in %w[SYSLOG SINGLE HALT] }
end
```

Rationale: a Phase 1 mistake (read the source guidance text) cascades into a control that lies. Always cross-check title -> check/Audit text -> describe block intent before merging.

## Reference examples (copy-pasteable, with line numbers)

All in the [redhat-enterprise-linux-9-stig-baseline](https://github.com/mitre/redhat-enterprise-linux-9-stig-baseline) repo under `controls/`:

- `SV-257797.rb:51-73` — multi-file sysctl with dual-it "at least one correct + no conflicts" pattern
- `SV-257814.rb:42-63` — `limits_conf` + `globally_set` + `failing_files` pattern
- `SV-257820.rb:36-40` — single-section `parse_config_file` with `subject` and `its`
- `SV-257822.rb:32-50` — yum/dnf repos parsed and rejected by name with skip when empty
- `SV-257823.rb:42-48` — rpm hash check with file-list failure message
- `SV-257843.rb:37-52` — per-mount-point describe with interpolated subject label
- `SV-258050.rb:32-80` — findings hash keyed by username for per-user dumps
- `SV-257778.rb:49-59` — `describe.one` with package fallback (good for "either bulk OK or list specifics")

And in the [amazon-linux-2023-stig-baseline](https://github.com/mitre/amazon-linux-2023-stig-baseline) repo under `controls/` (anti-pattern references — pre-fix branch):

- `SV-274187.rb:32-34` — raw `grep` pipeline as describe subject
- `SV-274155.rb:36-38` — stripped stdout as subject string
- `SV-274077.rb:31-36` — shell pipeline inside `subject {}` block
- `SV-274080.rb:44-49` — 4-key loop with shell pipeline subject per key
- `SV-274151.rb:39-45`, `SV-274013.rb:32-38` — PAM checks via raw grep (use `pam` resource)
- `SV-274107.rb:32-51` — title/body mismatch (Phase 1 failure)
- `SV-274058.rb:56` — `ls -l … | awk '{print $9}'` for directory listing (use `directory`/`file.link_path`)
