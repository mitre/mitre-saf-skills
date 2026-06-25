# Skill Authoring Best Practices

Standards, patterns, and lessons learned for writing skills in this repo. All guidance is derived from the [Agent Skills specification](https://agentskills.io/specification) and [best practices](https://agentskills.io/skill-creation/best-practices), verified against real usage.

## Table of Contents

- [The Spec (what's required)](#the-spec-whats-required)
- [Progressive Disclosure](#progressive-disclosure-the-most-important-pattern)
- [Description Quality](#description-quality-determines-auto-triggering)
- [Principle-First Writing](#principle-first-writing-for-universal-skills)
- [Credentials and Secrets](#credentials-and-secrets)
- [Cross-Skill References](#cross-skill-references)
- [Portability](#portability)
- [Multi-Mode Skills](#multi-mode-skills)
- [Structured Q&A for Context Gathering](#structured-qa-for-context-gathering)
- [Script Design for Agents](#script-design-for-agents)
- [Distribution Channels](#distribution-channels)
- [Installation for Development](#installation-for-development)
- [How Agents Discover and Activate Skills](#how-agents-discover-and-activate-skills)
- [The Universal Principle Insight](#the-universal-principle-insight)
- [Publishing Checklist](#publishing-checklist)

## The Spec (what's required)

### SKILL.md Frontmatter

Only these top-level fields are valid per the spec:

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | 1-64 chars, lowercase + hyphens, must match directory name |
| `description` | Yes | 1-1024 chars. What it does AND when to trigger. Include "Use when..." |
| `license` | No | License name or reference |
| `compatibility` | No | Environment requirements (tools, runtimes) |
| `metadata` | No | Arbitrary key-value pairs (put custom fields here) |
| `allowed-tools` | No | Experimental pre-approved tools |

Custom fields like `user-invocable`, `argument-hint`, `arguments` go under `metadata:`, not at the top level.

### File References

Use **bare relative paths** from the skill directory root. The agent resolves them automatically.

```markdown
## Workflow
1. Run the search script:
   ```bash
   python3 scripts/semantic-cci-search.py -r "requirement text"
   ```
```

**Never use:**
- `~/.claude/skills/skill-name/...` (tool-specific install path)
- `/Users/username/...` (personal machine path)
- `$SKILL_DIR` or `$SKILLS_HOME` (no such standard exists)

The spec says: "Use relative paths from the skill directory root. The agent resolves these paths automatically."

### Scripts Self-Locate

Scripts find their own files via `Path(__file__).parent` (Python) or `$(dirname "$0")` (bash). They don't depend on any env var or working directory.

```python
SCRIPT_DIR = Path(__file__).parent
DATA_DIR = SCRIPT_DIR.parent / "data"
```

## Progressive Disclosure (the most important pattern)

Skills load in three tiers:

1. **Metadata** (~100 tokens) — `name` + `description`, loaded at startup for ALL skills
2. **SKILL.md body** (<500 lines recommended) — loaded when the skill activates
3. **References/scripts/assets** — loaded only when the instructions reference them

### Why this matters

Loading too much content into SKILL.md actively hurts performance. From the spec:

> "Overly comprehensive skills can hurt more than they help — the agent struggles to extract what's relevant and may pursue unproductive paths triggered by instructions that don't apply to the current task."

### What stays in SKILL.md

- Core workflow (the steps the agent follows every time)
- Gotchas and anti-patterns (must be seen before the agent hits the problem)
- Decision points and defaults
- Specific "Read when..." pointers to reference files

### What moves to references/

- Detailed procedures that only apply in specific conditions
- Deep-dive content for advanced scenarios
- Tool-specific or stack-specific reference material
- Large example collections

### The "Read when..." pointer is critical

Vague pointers don't work. Specific conditional pointers do.

```markdown
<!-- BAD — agent doesn't know when to look -->
See references/ for more details.

<!-- GOOD — agent knows the exact trigger -->
After completing Phase 5, if the project requires mutation testing or
race-condition analysis, read
[references/advanced-verification.md](references/advanced-verification.md).
```

### Directory structure

```
skill-name/
├── SKILL.md              # Core workflow, under 500 lines
├── references/           # Detailed docs, loaded on demand
│   ├── advanced-topic.md
│   └── stack-specific.md
├── scripts/              # Executable helpers, self-contained
└── assets/               # Templates, data files
```

## Description Quality (determines auto-triggering)

The description is the most important field — it's the only thing loaded at startup, and it's what the agent uses to decide whether to activate the skill.

### Do

- Include "Use when..." with concrete scenarios
- List trigger phrases the user might say
- Name the domain clearly ("InSpec controls", "RSpec spec files", "beads boards")
- Be specific enough to avoid false triggers, broad enough to catch valid ones

### Don't

- Use marketing words ("comprehensive", "robust", "enterprise-grade")
- Write vague descriptions ("helps with testing")
- Omit trigger conditions (the agent won't know WHEN to activate)

### Example

```yaml
# BAD
description: Helps with PDFs.

# GOOD
description: >-
  Audit a package's source code across four domains: DRY/maintainability,
  architecture, test quality, and security. Produces prioritized, card-ready
  findings. Use when reviewing a package before planning improvements, when
  onboarding to an unfamiliar codebase, or when asked to assess code quality.
```

## Adopt and Adapt Before Building

Before creating any skill, search for existing ones that solve the same problem:

```bash
npx skills find "<domain keywords>"
```

Also check the [skills.sh leaderboard](https://skills.sh) and [Anthropic's skills repo](https://github.com/anthropics/skills).

If an 80-90% solution exists, adapt it rather than building from scratch. Fork it, add what's missing, remove what doesn't fit. Building a new skill when a near-match exists wastes effort and fragments the ecosystem.

The decision framework:
- **Exact match** → install and use it
- **80-90% match** → fork, adapt the gap, contribute improvements upstream if applicable
- **Partial match** → use as a starting point or compose with other skills
- **No match** → build from scratch

## Regression Testing (when rewriting skills)

When generalizing or rewriting a skill, verify the new version catches the same failures the old version was built to prevent:

1. Keep both versions available (original in `~/.claude/skills/`, rewrite in repo)
2. Walk 3-5 real past tasks through the new version
3. For each gate/rule, ask: "Would this still catch the failure that created this gate?"
4. Check that generalization didn't lose specificity — "use project design tokens" should still lead the agent to find `--project-primary` in the project's stylesheet

If a gate doesn't fire where it should, the generalization went too far.

## Principle-First Writing (for universal skills)

Skills encode universal engineering principles, not project-specific recipes. When a skill was learned from a specific incident, write it as:

1. **State the universal principle** — what's true regardless of stack
2. **Give concrete examples** — labeled as examples, from one or more stacks
3. **Let the reader map to their context**

```markdown
<!-- WRONG — project-specific -->
Never add `rubocop:disable` to bypass Rails/SkipsModelValidations.

<!-- RIGHT — universal principle with examples -->
Never suppress linter warnings to make the build green. Fix the root cause.
Examples: `rubocop:disable` (Ruby), `eslint-disable` (JS), `@ts-ignore` (TS),
`//nolint` (Go), `# type: ignore` (Python).
```

### Attribution

When a rule comes from a real incident, state it as a direct rule — not a quote with a name and date.

```markdown
<!-- WRONG -->
Aaron: "THAT BREAKS TRUST." (2026-06-06)

<!-- RIGHT -->
THAT BREAKS TRUST. Documenting what was skipped is transparent laziness.
```

The lesson is the value. The name and date are internal context that doesn't help the reader.

## Credentials and Secrets

- Never hardcode API keys, tokens, or passwords in skill files
- Scripts should read credentials from environment variables: `os.environ.get("API_KEY")`
- Document required env vars in the skill's compatibility field or prerequisites section
- Default to localhost and standard ports for services

## Cross-Skill References

Use plain skill names, not slash commands or wikilinks:

```markdown
<!-- WRONG -->
Invoke /project-tdd before writing code.
See [[derive-cci-mappings]] for CCI lookup.

<!-- RIGHT -->
Follow the project-tdd skill before writing code.
See the derive-cci-mappings skill for CCI lookup.
```

Slash commands (`/skill-name`) are Claude Code-specific. Wikilinks (`[[name]]`) are a memory-system convention. Plain names work across all agent tools.

## Portability

Skills should work across Claude Code, Cursor, Codex, Copilot, Windsurf, Gemini, and Cline. The Agent Skills spec is a cross-tool standard — every major AI coding agent supports it.

### Avoid

- **Tool-specific mechanism names**: `Agent tool`, `runSubagent`, `TodoWrite`, `TaskCreate`, `AskUserQuestion`, `context: fork`, `.claude/hooks/`
- **Tool-specific install paths in content**: `~/.claude/skills/`, `.cursor/skills/` (OK in install instructions, not in skill workflow)
- **Platform-specific env vars**: `$SKILL_DIR`, `$SKILLS_HOME` (the spec has no such standard)

### Instead

- **Describe intent, not mechanism**: "conduct an independent review" not "use the Agent tool to spawn a subagent"
- **Reference scripts by relative path**: the agent resolves the full path from the skill root
- **State compatibility requirements in frontmatter**: use the `compatibility` field for external tool dependencies

### Cross-Tool Agent Delegation

The spec describes subagent delegation as "an advanced pattern only supported by some clients." But every major AI coding tool has SOME form of delegation — Claude Code has the Agent tool, Codex has subtasks, Cursor has agent mode, Copilot has its coding agent, Windsurf has Cascade, Gemini has agent capabilities.

**The pattern for portable delegation:**

1. **Describe the task**: what needs to be done, with what prompt
2. **Note the isolation benefit**: why a separate session is better (independence, focus)
3. **Provide fallback behavior**: "if subagents are unavailable, conduct the review in the current session"

```markdown
## Step 4: Independent Review

Conduct an independent review using this prompt. If your environment
supports subagent delegation, run this as a separate agent session for
isolation. Otherwise, conduct the review in the current session — the
key requirement is independence of judgment, not a separate process.

[prompt structure follows]
```

**Why this works everywhere:** the skill describes WHAT to delegate, not HOW. Each tool maps the intent to its own mechanism. The fallback ensures the skill is functional even if delegation isn't supported — it degrades gracefully, not catastrophically.

## Multi-Mode Skills

When a skill supports multiple modes (e.g., local vs shared server, split vs audit), use the "default + escape hatch" pattern from the spec:

1. **Pick a default** — the most common mode
2. **Put the default workflow in SKILL.md** — the agent follows it without extra input
3. **Put variant workflows in references/** — loaded only when the user's request matches

```
create-beads-board/
├── SKILL.md                    # Mode detection table + local mode (default)
└── references/
    ├── shared.md               # Shared server setup (loaded if user says "shared")
    ├── shared-remote.md        # Remote sync (loaded if user says "remote")
    └── migration.md            # Embedded→shared migration
```

The mode detection goes in SKILL.md as a table matching user phrases to reference files:

```markdown
| User says | Mode |
|-----------|------|
| "shared server", port number | Read references/shared.md |
| "remote", "dolthub" | Read references/shared-remote.md |
| Nothing specific | Local (default, below) |
```

## Structured Q&A for Context Gathering

Some skills need user input before they can proceed. Use structured questions (presented as options the user picks) instead of open-ended prompts. The agent uses whatever mechanism its platform supports — `AskUserQuestion` in Claude Code, natural conversation in Cursor/Codex, etc.

### When to use structured Q&A

Ask **only when the skill genuinely can't proceed without user input**. Auto-detect first; ask as a fallback or when scoping is needed.

| Use Q&A when... | Example |
|-----------------|---------|
| The skill can't infer intent from context | "What should this skill do?" (create-skill) |
| There's genuine ambiguity that context clues can't resolve | "Local, shared, or shared+remote?" (create-beads-board fallback) |
| The skill needs to scope its work | "Which audit domains? (DRY / architecture / test quality / security / all)" |
| Auto-detection failed and you need a fallback | "Couldn't detect your doc system. Which are you using?" |

| Don't use Q&A when... | Why |
|------------------------|-----|
| The input is already in the arguments or card | project-tdd gets everything from the card description |
| The skill has a clear default | spec-split-review mode comes from the argument pattern |
| The answer is deterministic from the codebase | project-docs auto-detects from marker files |

### How to write Q&A in a skill

Write the questions as content the agent presents — **don't name the tool**. Each platform implements questions differently.

```markdown
## Step 1: Gather Context

Before proceeding, gather these answers from the user:

**Question 1: What type of baseline are you targeting?**
- "DISA STIG" — follows the SRG→STIG inheritance model
- "CIS Benchmark" — uses CIS Controls mapping
- "Cloud provider" — AWS/Azure/GCP best-practice baseline
- "Custom" — organization-specific requirements

**Question 2: Which platform?**
- RHEL / Amazon Linux / Ubuntu / Windows Server
- AWS / Azure / GCP
- Kubernetes / Container platform

Present these as structured options. Use the answers to load the right
reference material and tailor the workflow.
```

### The decision framework

When adding a new step to a skill, ask: "Can I determine this from context, arguments, or auto-detection?" If yes, do that and move on. If no, present structured options with a recommended default. Never ask open-ended questions when structured options would work — the user clicks instead of typing, and the skill gets unambiguous input.

```
Can I detect it?
  ├── Yes → auto-detect, move on
  └── No → Can I offer structured options?
        ├── Yes → present options with a default
        └── No → ask an open-ended question (last resort)
```

## Script Design for Agents

From the spec's [using-scripts guide](https://agentskills.io/skill-creation/using-scripts):

- **No interactive prompts** — agents can't respond to TTY input. Accept all input via flags, env vars, or stdin.
- **Document usage with `--help`** — this is how the agent learns your script's interface.
- **Structured output** (JSON) to stdout, diagnostics to stderr.
- **Meaningful exit codes** — distinct codes for different failure types.
- **Idempotent** — agents may retry. "Create if not exists" beats "create and fail on duplicate."
- **Pin versions** in inline dependencies (PEP 723 for Python, `npm:package@version` for Deno/Bun).
- **Predictable output size** — support `--offset`/pagination for large output to avoid context truncation.

## Distribution Channels

Two channels work from the same repo:

### npx skills (universal — all agent tools)

```bash
npx skills add mitre/mitre-saf-skills              # all skills
npx skills add mitre/mitre-saf-skills --skill X     # one skill
npx skills add /local/path -g --all                 # local dev, symlinks by default
npx skills add mitre/mitre-saf-skills --copy        # stable copy, no symlink
```

Works across Claude Code, Cursor, Codex, Copilot, Windsurf, Gemini, Cline.

### Claude Code Plugin Marketplace (Claude Code only)

Requires `.claude-plugin/marketplace.json`. Adds `/plugin install` browsing UX.

### skills.sh.json

Groups skills for display on the [skills.sh](https://skills.sh) leaderboard:

```json
{
  "$schema": "https://skills.sh/schemas/skills.sh.schema.json",
  "groupings": [
    {
      "title": "Group Name",
      "description": "What this group covers.",
      "skills": ["skill-name-1", "skill-name-2"]
    }
  ]
}
```

## Installation for Development

For skill authors actively developing skills, **symlinks** give a single source of truth:

```bash
# npx skills defaults to symlinks
npx skills add /path/to/repo -g --all

# Or manual symlinks
ln -sfn /path/to/repo/skills/my-skill ~/.claude/skills/my-skill
```

Edits in the repo are live immediately. `npx skills update` pulls changes from GitHub.

For stable consumption, `--copy` creates an independent copy that doesn't change when the repo updates.

## How Agents Discover and Activate Skills

From the [client implementation guide](https://agentskills.io/client-implementation/adding-skills-support):

1. **Discovery** — agent scans `~/.claude/skills/`, `.agents/skills/`, project-level skill dirs at startup
2. **Catalog** — `name` + `description` of all skills loaded into context (~50-100 tokens each)
3. **Activation** — agent reads full SKILL.md when it decides the skill is relevant (based on description match)
4. **Resources** — agent reads references/scripts/assets on demand when SKILL.md points to them

Project-level skills override user-level skills with the same name. The agent knows the skill's base directory and resolves all relative paths from there.

## The Universal Principle Insight

Every "project-specific" element in a skill encodes a universal engineering principle:

| Surface (project-specific) | Intention (universal) |
|---|---|
| Blueprint | Serialization layer (serializers, presenters, DTOs) |
| `--vulcan-*` CSS variables | Project design tokens (any design system) |
| 7-layer OpenAPI rule | Contract changes propagate atomically to all consumers |
| `before_save` callback fight | ORM lifecycle hooks create invisible coupling |
| `rubocop:disable` | Don't suppress warnings — fix the root cause |
| `as any` / `as unknown` | Don't bypass your language's safety mechanisms |
| Playwright screenshots | Visual changes require visual verification |
| `npx tsc --noEmit` | Run static analysis, not just tests |

When writing skills from real incidents, state the principle first, then give the incident as a concrete example. This is how "Clean Code" works — principles in Java examples that every developer translates.

## Audit Context Awareness

When auditing skills with grep-based checks, the agent must distinguish **real violations from examples of what to check for.** A checklist that documents `"Aaron said X" → state X directly` will trigger on "Aaron" even though it's showing what NOT to do.

The agent is the context parser: read the surrounding lines, identify whether the match is inside a table cell example, a code block, or a "how to verify" instruction. Classify as FALSE POSITIVE when the match is documentation of the pattern, not an instance of it. See the audit checklist's "Avoiding False Positives" section for the full classification table.

This is a genuine advantage of AI-driven auditing over script-based linting — the agent understands markdown structure, table context, and instructional intent that grep cannot distinguish.

## Publishing Checklist

Before adding a skill to this repo:

- [ ] `name` field matches directory name (lowercase, hyphens)
- [ ] Description includes "Use when..." trigger conditions
- [ ] SKILL.md is under 500 lines
- [ ] All file references use relative paths (zero `~/` or `/Users/`)
- [ ] No hardcoded secrets, credentials, or personal paths
- [ ] No person names, dated incidents, or internal epic IDs
- [ ] No marketing words ("comprehensive", "robust", "enterprise-grade")
- [ ] `compatibility` field lists required external tools
- [ ] Scripts self-locate via `__file__` / `dirname "$0"` (no `$SKILL_DIR`)
- [ ] Cross-skill references use plain names (no slash commands or wikilinks)
- [ ] `license` field set (Apache-2.0 for this repo)
- [ ] Tested with at least one agent tool
