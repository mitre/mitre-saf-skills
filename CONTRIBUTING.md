# Contributing to MITRE SAF Skills

Thank you for considering contributing to the MITRE SAF Skills collection. These skills help security engineers, developers, and compliance teams work more effectively with AI coding agents.

## Code of Conduct

By participating in this project, you are expected to uphold our [Code of Conduct](./CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Issues

- **Use a clear and descriptive title**
- **Describe the skill and the problem** you encountered
- **Include the agent tool** you're using (Claude Code, Cursor, Codex, etc.)
- **Provide steps to reproduce** the issue

### Suggesting New Skills

We welcome proposals for new skills. When suggesting a skill:

- **Describe the problem** the skill would solve
- **Identify the target audience** (InSpec authors, Rails devs, general dev teams, etc.)
- **Provide examples** of when the skill would trigger
- **Consider scope** — a skill should be a coherent unit of work, not too narrow or too broad

### Contributing a Skill

#### Skill Structure

Every skill follows the [Agent Skills specification](https://agentskills.io/specification):

```
skills/
  your-skill-name/
    SKILL.md              # Required: frontmatter + instructions
    references/           # Optional: docs loaded on demand
    scripts/              # Optional: executable helpers
    assets/               # Optional: templates, data files
```

#### SKILL.md Requirements

```yaml
---
name: your-skill-name          # Must match directory name
description: >-                # What it does + when to trigger
  Describe what this skill does and when an agent should use it.
  Include trigger phrases and scenarios.
compatibility: ...             # Optional: external tool requirements
metadata:
  author: your-name            # Optional: attribution
---
```

Key guidelines:
- **name**: lowercase, hyphens only, 1-64 chars, must match directory name
- **description**: 1-1024 chars, include both what AND when
- **SKILL.md body**: under 500 lines; move detailed content to `references/`
- **File references**: use relative paths (never `~/` or absolute paths)

#### Quality Checklist

Before submitting a skill PR:

- [ ] `name` field matches directory name
- [ ] Description includes "Use when..." trigger conditions
- [ ] SKILL.md is under 500 lines
- [ ] All file references use relative paths
- [ ] No hardcoded secrets, credentials, or personal paths
- [ ] No internal-only references (project names, team members, incident dates)
- [ ] `compatibility` field lists required external tools
- [ ] Tested with at least one agent tool (Claude Code, Cursor, etc.)
- [ ] `license` field set if skill includes third-party content

#### Testing Your Skill

1. Install locally: `ln -sfn /path/to/your/skills/your-skill ~/.claude/skills/your-skill`
2. Start a new Claude Code session — verify the skill appears in the available skills list
3. Test with realistic prompts that should trigger the skill
4. Test with prompts that should NOT trigger the skill (avoid false positives)

### Development Process

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Create a feature branch**: `git checkout -b feat/your-skill-name`
4. **Add your skill** under `skills/your-skill-name/`
5. **Test locally** per the testing checklist above
6. **Submit a Pull Request** with:
   - Description of the skill and its use cases
   - Target audience
   - Testing performed
   - Agent tools tested with

### Improving Existing Skills

When improving an existing skill:

- **Keep changes focused** — one improvement per PR
- **Test both old and new behavior** to avoid regressions
- **Update the description** if trigger conditions change
- **Move content to `references/`** if SKILL.md exceeds 500 lines

## Style Guidelines

- Write clear, imperative instructions ("Run this command", not "You should run...")
- Explain WHY when instructions aren't obvious
- Include concrete examples, not abstract descriptions
- Prefer defaults over menus — pick the best approach, mention alternatives briefly
- Keep gotchas near the top where they'll be seen before the agent hits the problem
- No marketing language ("robust", "comprehensive", "enterprise-grade")

## Questions?

- Open a [GitHub Discussion](https://github.com/mitre/mitre-saf-skills/discussions)
- Email us at [saf@mitre.org](mailto:saf@mitre.org)
- Visit [saf.mitre.org](https://saf.mitre.org/) for more about the SAF ecosystem

---

<p align="center">
  Part of the <a href="https://saf.mitre.org/">MITRE Security Automation Framework</a>
</p>
