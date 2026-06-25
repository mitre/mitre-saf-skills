# MITRE SAF Skills

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![skills.sh](https://skills.sh/b/mitre/mitre-saf-skills)](https://skills.sh/mitre/mitre-saf-skills)

Agent skills for security automation, compliance development, and software engineering workflows from the [MITRE Security Automation Framework](https://saf.mitre.org/) team.

Skills are modular instruction sets that extend AI coding agents with specialized knowledge. They follow the open [Agent Skills](https://agentskills.io/) specification and work across Claude Code, Cursor, Codex, Copilot, Windsurf, Gemini, and Cline.

## Quick Start

### Install all skills

```bash
npx skills add mitre/mitre-saf-skills
```

### Install a specific skill

```bash
npx skills add mitre/mitre-saf-skills --skill profile-development-rubric
```

### Install globally (available in all projects)

```bash
npx skills add mitre/mitre-saf-skills -g --all
```

### Browse available skills

```bash
npx skills add mitre/mitre-saf-skills --list
```

## Available Skills

### InSpec & Compliance

Skills for writing, reviewing, and mapping security controls.

| Skill | Description |
|-------|-------------|
| **[profile-development-rubric](skills/profile-development-rubric/)** | Methodology for writing "done" InSpec controls — the SAF yardstick. Covers the six outcomes, InSpec resource selection, describe block framing, failure messages, input generalization, and compliance metadata (CCI, NIST, CIS). Works across STIG, CIS Benchmark, cloud, and Kubernetes baselines. |

### Development Workflow

Skills for test-driven development, documentation, and code quality.

| Skill | Description |
|-------|-------------|
| **[project-docs](skills/project-docs/)** | Auto-detects your documentation system (VitePress, MkDocs, Nuxt Content, Docusaurus, Sphinx) and loads the matching style guide. Enforces "read source before writing" discipline. |
| **[spec-split-review](skills/spec-split-review/)** | Split large RSpec files into domain-focused files with expert review for grouping quality, test gap analysis, and parallel safety. Use when any spec file exceeds 500 lines. |
| **[package-audit](skills/package-audit/)** | Run a systematic audit of a package's source code across four domains: DRY/maintainability, architecture, test quality, and security. |
| **[create-feature-plan-adr](skills/create-feature-plan-adr/)** | Drive the design phase before code. Produces an ADR (WHY) and feature plan (HOW) that feed into project-card for epic/card creation. Phase 0 reads the codebase first, Decision Gate routes based on existing work. |

### Project Management (requires [beads](https://github.com/gastownhall/beads))

Skills for teams using beads for issue tracking and task management.

| Skill | Description |
|-------|-------------|
| **[create-beads-board](skills/create-beads-board/)** | Set up a beads board in any repo. Three modes: local (embedded), shared (team Dolt server), and shared+remote (with DoltHub/GitHub sync). |
| **[project-tdd](skills/project-tdd/)** | TDD with quality gates learned from production audits. 22 gates covering exhaustive branching, type safety, test sufficiency, DRY, error classification, and more. |
| **[project-card](skills/project-card/)** | Create well-structured beads cards with the mandatory 12-section template. Enforces acceptance criteria, verification commands, and anti-patterns. |
| **[project-ac-verify](skills/project-ac-verify/)** | Independent agent review of card acceptance criteria before close. Spawns a reviewer that checks each AC against the actual code diff and design doc. |
| **[prepare-compact](skills/prepare-compact/)** | Save full session context before context compaction or loss. Archives recovery files, updates beads cards, syncs to remote, and writes strategic recovery context for the next session. |
| **[restore-context](skills/restore-context/)** | Restore full session context after compaction or time away. Reads recovery files, syncs the board, loads memories, verifies git state, and presents available work. |

### Skill Authoring

| Skill | Description |
|-------|-------------|
| **[create-skill](skills/create-skill/)** | Guided workflow for creating, auditing, or improving agent skills. Searches marketplace before building, runs 7-dimension audits, context-aware false positive classification. |

## Installation Methods

### For development (symlinks, live edits)

If you're actively developing skills and want a single source of truth:

```bash
# Clone the repo
git clone https://github.com/mitre/mitre-saf-skills.git

# Symlink individual skills
ln -sfn /path/to/mitre-saf-skills/skills/profile-development-rubric ~/.claude/skills/profile-development-rubric

# Or install all via npx (symlinks by default)
npx skills add /path/to/mitre-saf-skills -g --all
```

### For use (stable copy)

```bash
# Install with copy (won't change when repo updates)
npx skills add mitre/mitre-saf-skills -g --all --copy
```

### Manual install (any agent tool)

```bash
cp -r skills/profile-development-rubric ~/.claude/skills/
```

For Cursor: copy to `.cursor/skills/`. For Codex: copy to `.agents/skills/`.

## Skill Compatibility

| Skill | Claude Code | Cursor | Codex | Copilot | Requires |
|-------|:-----------:|:------:|:-----:|:-------:|----------|
| profile-development-rubric | Yes | Yes | Yes | Yes | InSpec |
| project-docs | Yes | Yes | Yes | Yes | — |
| spec-split-review | Yes | Yes | Yes | Yes | RSpec, Ruby |
| package-audit | Yes | Yes | Yes | Yes | — |
| create-feature-plan-adr | Yes | Yes | Yes | Yes | — |
| create-beads-board | Yes | Yes | Yes | Yes | beads CLI |
| project-tdd | Yes | Yes | Yes | Yes | beads CLI |
| project-card | Yes | Yes | Yes | Yes | beads CLI |
| project-ac-verify | Yes | Yes | Yes | Yes | beads CLI |
| prepare-compact | Yes | Yes | Yes | Yes | beads CLI |
| restore-context | Yes | Yes | Yes | Yes | beads CLI |
| create-skill | Yes | Yes | Yes | Yes | — |

## Creating Your Own Skills

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full guide. The short version:

1. `npx skills init my-skill-name`
2. Edit `my-skill-name/SKILL.md` with your instructions
3. Test locally with `ln -sfn` into `~/.claude/skills/`
4. Submit a PR

Skills follow the [Agent Skills specification](https://agentskills.io/specification). Key rules:
- `SKILL.md` is the only required file
- `name` must match the directory name (lowercase, hyphens)
- `description` should say what it does AND when to trigger it
- Keep `SKILL.md` under 500 lines; use `references/` for detail

## About MITRE SAF

The [Security Automation Framework](https://saf.mitre.org/) (SAF) is a suite of tools for security automation, validation, and compliance. Key projects include:

- **[Vulcan](https://github.com/mitre/vulcan)** — STIG authoring and InSpec profile development
- **[Heimdall](https://github.com/mitre/heimdall2)** — Security results visualization and analysis
- **[SAF CLI](https://github.com/mitre/saf)** — Command-line security automation toolkit
- **[InSpec Profiles](https://github.com/mitre?q=inspec-profile)** — 300+ validation profiles across platforms

## License

[Apache 2.0](./LICENSE.md)

Approved for Public Release; Distribution Unlimited. Case Number 18-3678.

---

<p align="center">
  Part of the <a href="https://saf.mitre.org/">MITRE Security Automation Framework</a>
</p>
