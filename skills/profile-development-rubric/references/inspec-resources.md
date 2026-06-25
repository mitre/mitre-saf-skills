# InSpec resources for SAF/HDF profile work — quick catalog

This is a "use when" index, not full API documentation, covering the resource families used across MITRE SAF profiles: OS (Linux/Windows), cloud (AWS/Azure/GCP), Kubernetes, and application-specific. For each resource, follow the docs link for matchers, properties, and edge cases. Always prefer one of these over `command()`.

## Table of Contents

- [Filesystem and config files](#filesystem-and-config-files)
- [Kernel and sysctl](#kernel-and-sysctl)
- [Services, packages, processes](#services-packages-processes)
- [Auditing](#auditing)
- [Authentication and accounts](#authentication-and-accounts)
- [SSH and crypto](#ssh-and-crypto)
- [Cron and scheduled jobs](#cron-and-scheduled-jobs)
- [Networking](#networking)
- [Windows-specific](#windows-specific)
- [Cloud — AWS](#cloud--aws-inspec-aws)
- [Cloud — Azure](#cloud--azure-inspec-azure)
- [Cloud — GCP](#cloud--gcp-inspec-gcp)
- [Kubernetes](#kubernetes)
- [Last resort](#last-resort)
- [Where to look for more vetted examples](#where-to-look-for-more-vetted-examples)

Resources here serve **two modes** of testing (see the "Active vs. passive" section of `SKILL.md`):

- **Passive / configuration**: `file`, `parse_config_file`, `aws_s3_bucket(...).bucket_policy`, `k8sobject(...).spec` — read what's *written*.
- **Active / runtime**: `service`, `kernel_parameter`, `processes`, `auditd` (loaded rules), `sshd_active_config`, `aws_iam_user(...).has_mfa_enabled?`, `aws_security_group(id).inbound_rules` — observe what's *running*.

A "done" control often uses one of each (e.g. `parse_config_file('/etc/ssh/sshd_config')` + `sshd_active_config`) so drift is caught regardless of how it's introduced.

## How to read this list

- "Use when" → the guidance shape (STIG check text, CIS Audit text, cloud Audit step) that signals this resource fits.
- "Docs" → official Chef InSpec docs URL.
- "Gotchas" → things that bite in practice.

## Filesystem and config files

### `file(path)`
- **Use when:** any check that talks about ownership, mode, content, symlink target, or existence of a single file.
- **Docs:** <https://docs.chef.io/inspec/resources/file/>
- **Gotchas:** `file(path).content` returns `nil` for missing files — guard or use `should exist` first.

### `directory(path)`
- **Use when:** check is about a directory's mode/owner/group/existence. Don't use `command('ls -ld ...')`.
- **Docs:** <https://docs.chef.io/inspec/resources/directory/>

### `parse_config_file(path, options)`
- **Use when:** key=value config files (INI-like, with or without sections). Standard for `/etc/dnf/dnf.conf`, `/etc/yum.repos.d/*.repo`, `/etc/security/faillock.conf`, etc.
- **Docs:** <https://docs.chef.io/inspec/resources/parse_config_file/>
- **Gotchas:** for files without sections, `.params['KEY']`. For sectioned files, `.params['SectionName']['KEY']`.

### `parse_config(content, options)`
- **Use when:** you already have the content as a string (e.g. from a `command` you can't avoid).
- **Docs:** <https://docs.chef.io/inspec/resources/parse_config/>

### `ini(path)`
- **Use when:** strict INI files; gives nicer access than `parse_config_file` for clearly sectioned data.
- **Docs:** <https://docs.chef.io/inspec/resources/ini/>

### `yaml(path)` / `json(path)` / `xml(path)` / `csv(path)`
- **Use when:** structured config in the named format. All support `its('key.path')` chains.
- **Docs:** <https://docs.chef.io/inspec/resources/yaml/>, <https://docs.chef.io/inspec/resources/json/>, <https://docs.chef.io/inspec/resources/xml/>, <https://docs.chef.io/inspec/resources/csv/>

### `etc_fstab`
- **Use when:** any "is /X on its own filesystem" or "is /X mounted with noexec/nosuid/nodev" check.
- **Docs:** <https://docs.chef.io/inspec/resources/etc_fstab/>

### `mount(path)`
- **Use when:** runtime mount state (is /tmp currently mounted?). Pair with `etc_fstab` for persistence checks.
- **Docs:** <https://docs.chef.io/inspec/resources/mount/>

## Kernel and sysctl

### `kernel_parameter(name)`
- **Use when:** `sysctl X.Y.Z` checks (runtime value).
- **Docs:** <https://docs.chef.io/inspec/resources/kernel_parameter/>
- **Gotchas:** doesn't check persistence — also parse `/etc/sysctl.d/*.conf` or use the multi-file pattern from `RHEL9 SV-257797.rb`.

### `kernel_module(name)`
- **Use when:** "module X must be disabled / blacklisted / loaded" checks.
- **Docs:** <https://docs.chef.io/inspec/resources/kernel_module/>

## Services, packages, processes

### `service(name)`
- **Use when:** `systemctl is-active`, `systemctl is-enabled` checks.
- **Docs:** <https://docs.chef.io/inspec/resources/service/>

### `systemd_service(name)`
- **Use when:** you need systemd-specific properties (drop-ins, unit file path, etc.).
- **Docs:** <https://docs.chef.io/inspec/resources/systemd_service/>

### `package(name)`
- **Use when:** `rpm -q`, `dpkg -l`, "package must / must not be installed".
- **Docs:** <https://docs.chef.io/inspec/resources/package/>

### `packages(filter)`
- **Use when:** iterating over installed packages with a regex / name filter.
- **Docs:** <https://docs.chef.io/inspec/resources/packages/>

### `processes(filter)`
- **Use when:** "process X must / must not be running" or attribute checks on a running process.
- **Docs:** <https://docs.chef.io/inspec/resources/processes/>

## Auditing

### `auditd`
- **Use when:** the kernel-loaded audit rule set (the equivalent of `auditctl -l`).
- **Docs:** <https://docs.chef.io/inspec/resources/auditd/>
- **Gotchas:** does not check rule *files* under `/etc/audit/rules.d/` — only what the kernel has loaded.

### `auditd_conf`
- **Use when:** `/etc/audit/auditd.conf` key checks (`disk_full_action`, `space_left`, etc.).
- **Docs:** <https://docs.chef.io/inspec/resources/auditd_conf/>

## Authentication and accounts

### `pam(path)`
- **Use when:** any PAM stack check — `pam_wheel`, `pam_faillock`, `pam_pwquality`, etc.
- **Docs:** <https://docs.chef.io/inspec/resources/pam/>
- **Gotchas:** understands control flags and module args; raw grep can't.

### `login_defs`
- **Use when:** `/etc/login.defs` checks (`PASS_MAX_DAYS`, `CREATE_HOME`, `UMASK`, etc.).
- **Docs:** <https://docs.chef.io/inspec/resources/login_defs/>

### `limits_conf(path)`
- **Use when:** `/etc/security/limits.conf` and `/etc/security/limits.d/*.conf`. Returns parameters keyed by domain.
- **Docs:** <https://docs.chef.io/inspec/resources/limits_conf/>

### `users`, `user(name)`
- **Use when:** iterating local users (`users.where { uid >= 1000 }`) or checking one named user.
- **Docs:** <https://docs.chef.io/inspec/resources/users/>, <https://docs.chef.io/inspec/resources/user/>

### `etc_passwd`, `etc_shadow`, `etc_group`
- **Use when:** structured access to the underlying files (e.g. find accounts with `password != '!'`).
- **Docs:** <https://docs.chef.io/inspec/resources/etc_passwd/>, <https://docs.chef.io/inspec/resources/shadow/>, <https://docs.chef.io/inspec/resources/etc_group/>

### `group(name)` / `groups`
- **Use when:** group membership and existence checks.
- **Docs:** <https://docs.chef.io/inspec/resources/group/>

## SSH and crypto

### `sshd_config`, `sshd_active_config`
- **Use when:** any `sshd_config` key check. `sshd_active_config` reflects what `sshd -T` actually parses (recommended for STIG work).
- **Docs:** <https://docs.chef.io/inspec/resources/sshd_config/>, <https://docs.chef.io/inspec/resources/sshd_active_config/>

### `ssh_config`
- **Use when:** client-side ssh config check.
- **Docs:** <https://docs.chef.io/inspec/resources/ssh_config/>

### `selinux`
- **Use when:** SELinux mode/policy/booleans/modules.
- **Docs:** <https://docs.chef.io/inspec/resources/selinux/>

## Cron and scheduled jobs

### `crontab(user: ...)` / `crontab(path: ...)`
- **Use when:** "cron job X must / must not exist" or attribute checks on a scheduled task.
- **Docs:** <https://docs.chef.io/inspec/resources/crontab/>

## Networking

### `port(n)` / `host(name)`
- **Use when:** listening port checks or DNS reachability.
- **Docs:** <https://docs.chef.io/inspec/resources/port/>, <https://docs.chef.io/inspec/resources/host/>

### `firewalld` / `iptables`
- **Use when:** firewall rules. `firewalld` for systemd-managed; `iptables` for raw rules.
- **Docs:** <https://docs.chef.io/inspec/resources/firewalld/>, <https://docs.chef.io/inspec/resources/iptables/>

## Windows-specific

### `registry_key(path)`
- **Use when:** Windows STIG / CIS checks that read a registry value. Most Windows guidance is registry-based.
- **Docs:** <https://docs.chef.io/inspec/resources/registry_key/>

### `security_policy`
- **Use when:** local security policy items (`secedit /export`-style checks): account lockout, audit policy, user rights.
- **Docs:** <https://docs.chef.io/inspec/resources/security_policy/>

### `audit_policy`
- **Use when:** Windows audit policy subcategory checks (`auditpol /get`).
- **Docs:** <https://docs.chef.io/inspec/resources/audit_policy/>

### `windows_feature(name)`
- **Use when:** Windows roles/features installed-or-not checks.
- **Docs:** <https://docs.chef.io/inspec/resources/windows_feature/>

### `iis_site` / `iis_app_pool`
- **Use when:** IIS web server configuration checks (DISA IIS STIGs).
- **Docs:** <https://docs.chef.io/inspec/resources/iis_site/>, <https://docs.chef.io/inspec/resources/iis_app_pool/>

### `powershell(cmd)`
- **Use when:** no typed resource fits a Windows check. Treat as the Windows analogue of `command()`.
- **Docs:** <https://docs.chef.io/inspec/resources/powershell/>

## Cloud — AWS (`inspec-aws`)

These resources query the AWS API directly; the runner needs AWS credentials configured. Naming pattern: singular resource = one item, plural = collection that supports `.where { ... }`.

### `aws_iam_password_policy`
- **Use when:** account-level password policy checks (CIS AWS Foundations 1.5–1.11).
- **Docs:** <https://docs.chef.io/inspec/resources/aws_iam_password_policy/>

### `aws_iam_users` / `aws_iam_user(name)`
- **Use when:** "no IAM user without MFA", "no IAM user with console access without recent rotation", etc. Use plural + `.where` for "find the outsiders".
- **Docs:** <https://docs.chef.io/inspec/resources/aws_iam_users/>

### `aws_iam_root_user`
- **Use when:** root-account MFA, access keys, recent usage.
- **Docs:** <https://docs.chef.io/inspec/resources/aws_iam_root_user/>

### `aws_s3_buckets` / `aws_s3_bucket(name)`
- **Use when:** bucket-level checks for public access, default encryption, logging, versioning, MFA-delete.
- **Docs:** <https://docs.chef.io/inspec/resources/aws_s3_buckets/>

### `aws_security_groups` / `aws_security_group(id)`
- **Use when:** "no security group allows 0.0.0.0/0 to port 22/3389", inbound/outbound rule audits.
- **Docs:** <https://docs.chef.io/inspec/resources/aws_security_groups/>

### `aws_ec2_instances` / `aws_ec2_instance(id)`
- **Use when:** instance-level metadata, IMDSv2 enforcement, attached IAM role, EBS encryption.
- **Docs:** <https://docs.chef.io/inspec/resources/aws_ec2_instances/>

### `aws_cloudtrail_trails` / `aws_cloudtrail_trail(name)`
- **Use when:** multi-region trail, log file validation, KMS encryption, S3 destination.
- **Docs:** <https://docs.chef.io/inspec/resources/aws_cloudtrail_trails/>

### `aws_kms_keys` / `aws_kms_key(id)`
- **Use when:** key rotation enabled, key policy checks.
- **Docs:** <https://docs.chef.io/inspec/resources/aws_kms_keys/>

### `aws_config_recorder`, `aws_config_delivery_channel`
- **Use when:** AWS Config recording posture (CIS 2.5).
- **Docs:** <https://docs.chef.io/inspec/resources/aws_config_recorder/>

### Broader catalog
- The full set lives at <https://docs.chef.io/inspec/resources/#aws-resources>. Use the plural form whenever you need "find the outsiders" over all items in a region.

## Cloud — Azure (`inspec-azure`)

Naming pattern: `azurerm_<service>` for individual resources, `azurerm_<service>s` (plural) for collections with `.where { ... }`.

### `azurerm_security_center_policy`, `azurerm_security_center_subscription_pricing`
- **Use when:** Azure Defender tier checks, default policy enforcement (CIS Azure 2.x).

### `azurerm_role_definitions`, `azurerm_role_assignments`
- **Use when:** RBAC checks — "no custom subscription owner role", "no guest with privileged role".

### `azurerm_storage_accounts` / `azurerm_storage_account(...)`
- **Use when:** secure-transfer-required, public-access blocked, key rotation, default network rules.

### `azurerm_key_vaults` / `azurerm_key_vault(...)`
- **Use when:** soft-delete enabled, purge protection, RBAC vs access policies.

### `azurerm_sql_servers` / `azurerm_sql_database(...)`
- **Use when:** TDE, auditing, threat detection, AD-only authentication.

### `azurerm_network_security_groups`
- **Use when:** NSG rule audits (the Azure analogue of AWS security groups).

### Broader catalog
- <https://github.com/inspec/inspec-azure> — README lists every resource. Pattern is identical to AWS: singular for one, plural for collections.

## Cloud — GCP (`inspec-gcp`)

Naming pattern: `google_<service>_<resource>` and `google_<service>_<resource>s` (plural).

### `google_compute_instances`, `google_compute_instance(...)`
- **Use when:** VM-level checks — OS Login enabled, shielded-VM, no default service account.

### `google_compute_firewalls`
- **Use when:** firewall rule audits (analogue of AWS security groups / Azure NSGs).

### `google_storage_buckets` / `google_storage_bucket(...)`
- **Use when:** uniform bucket-level access, retention policy, public access prevention.

### `google_project_iam_bindings`, `google_project_iam_policy`
- **Use when:** IAM binding audits — "no @gmail.com identity on the project", separation-of-duties checks.

### `google_logging_project_sinks`, `google_kms_crypto_keys`
- **Use when:** centralized logging sinks (CIS GCP 2.x), key rotation policy.

### Broader catalog
- <https://github.com/inspec/inspec-gcp>

## Kubernetes

### `k8sobject(api_version:, type:, name:, namespace:)`
- **Use when:** any field of any Kubernetes object — Pods, Deployments, RoleBindings, NetworkPolicies, etc. Returns the parsed object so you can chain `.spec.containers.first.securityContext.runAsNonRoot`.
- **Docs:** <https://docs.chef.io/inspec/resources/k8sobjects/>

### `k8sobjects(api_version:, type:, namespace:)`
- **Use when:** "find the outsiders" across all objects of a type (e.g. all Pods in cluster). Supports `.where { ... }`.
- **Docs:** <https://docs.chef.io/inspec/resources/k8sobjects/>

### Common patterns
- "No Pod runs as root": `k8sobjects(...).items.reject { |p| pod_runs_as_nonroot?(p) }` then assert empty.
- "Every namespace has a default-deny NetworkPolicy": iterate `k8sobjects(type: 'namespaces')`, check for a matching NetworkPolicy in each.

## Last resort

### `command(cmd)`
- **Use when:** no typed resource exists. Examples: `rpm -Va`, `update-crypto-policies --check`, vendor-specific CLIs.
- **Docs:** <https://docs.chef.io/inspec/resources/command/>
- **Gotchas:** never use `command(...).stdout.strip` as a `describe` subject. Always wrap with a string headline and `subject { ... }`. Always strip + split when iterating.

### `powershell(cmd)` (Windows analogue)
- See Windows-specific section above.

## Where to look for more vetted examples

The `mitre/*` GitHub org carries many SAF/HDF profiles: STIG baselines (`*-stig-baseline`), CIS Benchmarks (`*-cis-baseline`), AWS/Azure/GCP best-practice profiles (`aws-foundations-cis-baseline`, `azure-foundations-cis-baseline`, etc.), and application profiles (NGINX, MongoDB, Postgres, Kubernetes). They vary widely in quality — older repos reflect InSpec 2.x/4.x conventions and often use raw `command()` shells, while recent ones follow the rubric in this skill.

Heuristics for picking a good reference:

- **Prefer the most recently maintained baselines** (`git log -1 --format=%cd controls/`). Recent commits usually correspond to modern conventions.
- **Canonical OS sources:** RHEL8/RHEL9, Ubuntu 22.04 STIG baselines (most review cycles).
- **Canonical cloud sources:** the `mitre/aws-foundations-cis-baseline` and `mitre/azure-foundations-cis-baseline` repos for CIS-style cloud profiles.
- **Skim before borrowing**: if the control uses `describe command('...')` as the *primary* subject, treat it as a candidate to be rewritten with this rubric, not a pattern to copy.
- **Cross-check across baselines** for the same SRG ID (or CIS section). If two baselines disagree on resource choice, the more recently updated one usually applies the rubric better.

When porting between vendors (RHEL → AL, RHEL → Ubuntu, STIG → CIS, AWS → Azure, etc.), expect resource choice to stay structurally similar (PAM is PAM; security groups have analogues in every cloud) while file paths, API names, default values, and N/A conditions shift. The rubric's six phases apply identically across OS, cloud, and Kubernetes targets.
