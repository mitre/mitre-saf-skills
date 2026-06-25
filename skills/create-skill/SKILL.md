---
name: create-skill
description: >-
  Create a new agent skill or improve an existing one following the Agent Skills
  spec and MITRE SAF publishing standards. Guides the user from intent through
  research, draft, validation, testing, and publication. Use when the user wants
  to create a skill, turn a workflow into a skill, improve an existing skill,
  review a skill for spec compliance, or asks "how do I make a skill."
compatibility: Works in any agent tool. Testing phase benefits from subagent support.
metadata:
  author: mitre-saf
license: Apache-2.0
---

# Create Skill

Guided workflow for creating or improving agent skills. Combines the [Agent Skills spec](https://agentskills.io/specification) with MITRE SAF publishing standards.

## Sources of Truth

Before creating, auditing, or improving a skill, fetch current standards. Do NOT rely on training data — these evolve.

**Authoritative references (fetch before drafting or auditing):**

The [Agent Skills spec](https://agentskills.io) is the cross-tool standard adopted by Claude Code, Codex, Cursor, Copilot, Windsurf, Gemini, and Cline. Anthropic co-authored the spec and maintains the reference implementation at `anthropics/skills`. There are no separate Claude-specific or Codex-specific skill standards — it's one spec, one format, one ecosystem.

**The open standard (all tools):**

| Source | What it covers | How to access |
|--------|---------------|---------------|
| [Agent Skills Spec](https://agentskills.io/specification) | Frontmatter schema, directory structure, naming rules, progressive disclosure | Fetch via Context7 or web fetch |
| [Best Practices](https://agentskills.io/skill-creation/best-practices) | Writing style, progressive disclosure, calibrating control, gotchas, templates | Fetch via web |
| [Using Scripts](https://agentskills.io/skill-creation/using-scripts) | Script design for agents, self-contained deps, --help, structured output | Fetch via web |
| [Evaluating Skills](https://agentskills.io/skill-creation/evaluating-skills) | Test cases, assertions, grading, benchmark viewer, iteration loop | Fetch via web |
| [Optimizing Descriptions](https://agentskills.io/skill-creation/optimizing-descriptions) | Trigger eval queries, description optimization loop | Fetch via web |
| [Client Implementation](https://agentskills.io/client-implementation/adding-skills-support) | How agents discover, activate, and manage skills — path resolution, progressive loading | Fetch via web |
| [skills.sh](https://skills.sh) | Browse existing skills, check for similar skills before building | `npx skills find "<keywords>"` |

**Tool-specific extensions (go beyond the base spec):**

| Source | What it covers | How to access |
|--------|---------------|---------------|
| [Claude Code Skills](https://code.claude.com/docs/en/skills) | Claude Code extensions: `context: fork` (subagent execution), `!command` (dynamic context injection), `$ARGUMENTS` substitution, `${CLAUDE_SKILL_DIR}`, `disable-model-invocation`, `user-invocable`, `allowed-tools`/`disallowed-tools`, `model`/`effort` overrides, `paths` glob patterns, `hooks` scoped to skill lifecycle, `when_to_use` field | Fetch via web |
| [Copilot Custom Instructions](https://docs.github.com/en/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot) | `.github/copilot-instructions.md`, path-specific instructions with glob frontmatter, `AGENTS.md` for agent instructions, 2-page limit | Fetch via web |
| [Anthropic skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) | The eval/iterate loop, description optimization scripts, blind comparison | Install: `npx skills add anthropics/skills --skill skill-creator` |

**Tool-specific tips (when the user tells you which tool they use):**

If the user is a **Claude Code** user:
- Skills can use `!command` for dynamic context injection (run a command and inline the output before the agent sees it)
- `${CLAUDE_SKILL_DIR}` resolves to the skill directory — use it in `!` commands to reference bundled scripts
- `context: fork` runs the skill in a subagent — useful for task skills that should not pollute the main conversation
- `disable-model-invocation: true` prevents auto-triggering for skills with side effects (deploy, send, commit)
- `allowed-tools` pre-approves tools so the user isn't prompted
- Skills at `~/.claude/skills/` are personal (all projects); `.claude/skills/` are project-level

If the user is a **Codex** user:
- Skills go in `.agents/skills/` (the cross-tool convention Codex follows)
- `AGENTS.md` at the repo root provides agent instructions (like CLAUDE.md but for Codex)
- Codex runs in a sandboxed cloud environment — skills that need network access or local tools may need adaptation
- No subagent execution or dynamic context injection — keep skills as pure instruction documents

If the user is a **Copilot** user:
- `.github/copilot-instructions.md` for repository-wide instructions (2-page limit)
- Path-specific instructions in `.github/instructions/NAME.instructions.md` with glob frontmatter
- `AGENTS.md` is recognized for agent instructions
- No progressive disclosure mechanism — keep instructions concise in the main file

**This repo's standards:**
| Source | What it covers |
|--------|---------------|
| [references/authoring-standards.md](references/authoring-standards.md) | MITRE SAF publishing standards, progressive disclosure, principle-first writing, Q&A pattern, portability, security |
| [references/audit-checklist.md](references/audit-checklist.md) | 7-dimension audit checklist for reviewing skills |

**When to fetch:** At the start of Phase 1 (create mode) or before running the audit checklist (audit mode). If Context7 MCP is available, use it to resolve the agentskills library and query docs. Otherwise, use web fetch on the URLs above. The spec and best practices pages are the minimum — fetch those two for every skill creation or audit.

## Phase 0: Gather Intent

Before writing anything, gather context from the user. Present these as structured questions with options — the user picks, not types.

**Question 1: What are you trying to do?**
- "Create a new skill from scratch" → continue to Question 2
- "Turn a workflow from this session into a skill" → continue to Question 2
- "Audit an existing skill" → ask for the skill path, then read [references/audit-checklist.md](references/audit-checklist.md) and run the full 7-dimension audit
- "Improve an existing skill" → ask for the skill path, run audit first to identify issues, then proceed to Phase 2 with findings
- "Review a skill for spec compliance" → same as "Audit"

**If "Audit" or "Review"** — ask for the skill path (or name if installed), then:
1. **Marketplace re-check** — run `npx skills find "<skill's domain keywords>"` to see if a better or higher-install-count skill now exists for the same purpose. Report findings as informational (WARN, not FAIL).
2. Read the SKILL.md and all supporting files, then run all audit dimensions from [references/audit-checklist.md](references/audit-checklist.md). Produce the structured findings report. Stop there unless the user asks to fix the findings.

**If "Improve"** — run the audit first, present findings, then ask: "Which findings do you want to fix?" Use the findings to guide Phase 2 edits.

**If "Turn a workflow"** — scan the current conversation for: tools used, sequence of steps, corrections the user made, input/output patterns. Summarize what you found: "I see you [did X, then Y, corrected Z]. Should the skill capture this workflow?" Confirm before proceeding.

**Question 2: What should the skill do?**
Ask for one sentence. If they already said it, confirm: "So the skill should [X] — correct?"

**Before Question 3 — Check if this already exists.**

Immediately after the user describes what the skill should do, search everywhere:

1. **Marketplace:** `npx skills find "<keywords from the user's description>"`
2. **Already installed:** Check `~/.claude/skills/`, `.claude/skills/`, and installed plugins for skills with similar names or descriptions
3. **Leaderboard:** Check the [skills.sh leaderboard](https://skills.sh) for popular skills in the domain
4. **Anthropic's repo:** Check [anthropics/skills](https://github.com/anthropics/skills) for official implementations

Present findings to the user:

- **Exact match found** → "There's already a skill that does this: [name] ([install count] installs). Want to install it, or do you need something different?"
- **Close match (80-90%)** → "There's a skill that does most of this: [name]. Want to adopt it and adapt the missing 10-20%, or build from scratch?"
- **Partial match** → "These skills cover part of what you need: [list]. Want to compose them, use one as a starting point, or build fresh?"
- **Nothing found** → "No existing skills match. Building from scratch."

**The default should be adopt-and-adapt, not build-from-scratch.** Building a new skill when a 90% solution exists is waste. The user can always choose to build fresh, but they should see what exists first.

**Question 3: Do you have a starting point?**
- "Yes, I found an existing skill to adapt" → install it, read its SKILL.md, proceed to Phase 2 with it as the base
- "Yes, I have my own draft SKILL.md" → ask for the path, read it, skip to Phase 2
- "Yes, notes or a checklist" → ask for the path or paste, extract the structure
- "No, starting from scratch" → proceed to Phase 1

**Question 4: What's the target domain?**
- Language/framework (Ruby/Rails, Python/Django, TypeScript/Node, Go, etc.)
- Domain (InSpec/compliance, frontend, DevOps, testing, security, etc.)
- "General purpose — no specific stack"

**Question 5: Who's the audience?**
- "My team (internal use)" → can include project-specific references
- "Public marketplace" → must follow publishing standards from the start
- "Both — internal now, public later" → follow publishing standards from the start

**Question 6: Does this skill need to gather context from the user during its workflow?**
- "Yes — it needs to ask what mode/variant/scope before proceeding"
- "No — it can auto-detect or has a single workflow"

This determines whether the skill itself will include a Q&A phase. Read the "Structured Q&A" section of [references/authoring-standards.md](references/authoring-standards.md) for the decision framework.

**For "Improve" or "Review"** — read the existing SKILL.md, then skip to Phase 3 (Validate).

## Phase 1: Research Before Drafting

Before writing, research what exists and what the current standards require.

1. **Fetch current standards** from the Sources of Truth table above:
   - Fetch the [Agent Skills Spec](https://agentskills.io/specification) — check for any changes to frontmatter schema, naming rules, or progressive disclosure guidance
   - Fetch [Best Practices](https://agentskills.io/skill-creation/best-practices) — review current writing style guidance, gotcha patterns, and calibration advice
   - Read [references/authoring-standards.md](references/authoring-standards.md) for this repo's publishing standards

2. **Search for existing skills:**
   ```bash
   npx skills find "<domain keywords>"
   ```
   If a similar skill exists, read it. Decide: adapt it, extend it, or build fresh. Check the [skills.sh leaderboard](https://skills.sh) for popular skills in the domain.

3. **Check the spec for key decisions:**
   - Will the skill need progressive disclosure (references/ for detailed content)?
   - Will it need scripts? If so, fetch [Using Scripts](https://agentskills.io/skill-creation/using-scripts) for current patterns
   - Will it support multiple modes (default + variants)?
   - Does it need structured Q&A to gather context from the user?

4. **Interview for depth:**
   After the initial Q&A, probe for specifics the user may not have volunteered:
   - "What are the edge cases?" — unusual inputs, error conditions, platform differences
   - "What does success look like?" — expected output format, quality bar
   - "What should the skill NOT do?" — scope boundaries prevent bloat
   - "Are there gotchas a first-time user would hit?" — these become the gotchas section

5. **If "Turn a workflow"** — extract the reusable pattern:
   - Which steps are specific to this task vs. generalizable?
   - Which corrections the user made reveal default agent behavior that's wrong?
   - Which tools/scripts were used repeatedly (candidates for scripts/)?

## Phase 2: Draft

### 2a: Frontmatter

```yaml
---
name: skill-name
description: >-
  What it does. Use when [scenario 1], [scenario 2], or [scenario 3].
  Also triggers on [phrase 1], [phrase 2].
compatibility: Required tools if any
license: Apache-2.0
---
```

Rules:
- `name`: lowercase + hyphens, 1-64 chars, must match directory name
- `description`: 1-1024 chars, WHAT + WHEN, include trigger phrases
- Make descriptions slightly "pushy" — agents under-trigger by default
- Put custom fields under `metadata:`, not at the top level

### 2b: Body structure

1. **Overview** — what this skill does, 2-3 sentences
2. **Q&A phase** (if the skill needs user context) — structured questions with options
3. **Core workflow** — numbered steps, imperative form
4. **Examples** — concrete input/output pairs
5. **Gotchas** — non-obvious facts the agent would get wrong
6. **Reference pointers** — "Read [file] when [specific condition]"

Key authoring rules:
- Under 500 lines — move detailed content to `references/`
- Bare relative paths — `scripts/foo.py` not absolute paths
- Explain WHY — reasoning works better than rigid MUSTs
- Principle-first — state the universal rule, then give stack-specific examples

### 2c: Directory structure

```
skill-name/
├── SKILL.md              # Core workflow, under 500 lines
├── references/           # Detailed docs (loaded on demand)
│   └── detailed-topic.md
├── scripts/              # Executable helpers (self-contained)
│   └── helper.py
└── assets/               # Templates, data files
```

**Progressive disclosure decisions:**
- Content needed EVERY run → stays in SKILL.md
- Content needed only in specific conditions → moves to references/
- Gotchas and anti-patterns → always stay in SKILL.md (must be seen before the problem hits)

**Scripts self-locate** — no `$SKILL_DIR` env vars:
```python
SCRIPT_DIR = Path(__file__).parent
DATA_DIR = SCRIPT_DIR.parent / "data"
```

### 2d: If the skill supports multiple modes

Use the default + escape hatch pattern:
- Put the default mode workflow in SKILL.md
- Put variant workflows in references/
- Add a mode detection table or Q&A at the top

### 2e: Write the draft

Write the SKILL.md to the target directory. Show the user the draft and ask: "Does this capture what you need? What's missing or wrong?"

## Phase 3: Validate Against Spec

**Start with the automated pre-check:** `bash scripts/audit-precheck.sh <skill-directory>` runs all grep-based checks from D1, D4, D5, D6 and produces a structured report. Review hits marked "CLASSIFY BY CONTEXT" manually, then continue with the non-greppable checks below.

For any remaining grep-based checks, **classify each hit by context before reporting:**

1. Run the grep command
2. For each hit, read the surrounding 3 lines
3. Classify: is this hit in actual skill content, or in an example/checklist/code block?
4. Report only REAL findings. Note FALSE POSITIVEs with evidence of why they're examples.

**Context classification rules:**
- Hit is inside a markdown table cell showing a "bad example" → FALSE POSITIVE
- Hit is inside a fenced code block demonstrating what to grep for → FALSE POSITIVE
- Hit is in a "how to verify" instruction describing the grep command itself → FALSE POSITIVE
- Hit is preceded by "BAD", "WRONG", "avoid", "don't", "never" as an anti-pattern example → FALSE POSITIVE
- Hit is in actual instructions, workflow steps, or prose → REAL FINDING

### Checklist

**Spec structure:**
- [ ] `name` matches directory name
- [ ] `description` includes "Use when..." with 2+ trigger scenarios
- [ ] `description` is 1-1024 characters
- [ ] SKILL.md under 500 lines (`wc -l`)
- [ ] `compatibility` field lists required external tools (if any)
- [ ] `license` field set
- [ ] No non-spec top-level frontmatter fields (custom fields go under `metadata:`)

**Paths and references (grep, then classify each hit):**
- [ ] `grep -rn '/Users/\|/home/' .` — zero REAL hits (exclude install instructions showing placeholder paths)
- [ ] `grep -rn '~/.claude/skills/' .` — zero REAL hits (exclude user-facing install examples)
- [ ] `grep -rn 'SKILL_DIR\|SKILLS_HOME' .` — zero REAL hits
- [ ] `grep -rn '/project-\|/derive-' .` — zero slash command references in content (exclude checklist examples)
- [ ] `grep -rn '\[\[' .` — zero wikilinks in content (exclude Ruby array literals `[[path, val]]`)

**Content quality (grep, then classify):**
- [ ] `grep -rni 'Aaron\|specific-person-name' .` — zero person names in content (exclude checklist examples showing what to avoid)
- [ ] `grep -rn 'On 2026-' .` — zero dated incidents in content (exclude checklist examples)
- [ ] `grep -ci 'comprehensive\|robust\|enterprise-grade' .` — zero marketing words in content (exclude checklist examples)

**Security:**
- [ ] `grep -rni 'api_key\|token\|password' scripts/` — verify env var usage, not hardcoded values
- [ ] `find . -name '*credential*' -o -name '*.key'` — zero credential files
- [ ] Scripts use `Path(__file__).parent` or `$(dirname "$0")`, not env vars for self-location

**Report format:** For each check, report PASS (zero real hits), WARN (hits that need review), or FAIL (confirmed real violations). For FALSE POSITIVEs, note: `FALSE POSITIVE: [reason] — line N is a checklist example, not content`.

Fix any FAIL before proceeding. Show what failed and the fix applied.

## Phase 4: Test

### Quick test (always)

1. Install locally: `ln -sfn /path/to/skill ~/.claude/skills/skill-name`
2. Start a new agent session
3. Verify the skill appears in available skills
4. Test with 2-3 prompts that SHOULD trigger it
5. Test with 1-2 near-miss prompts that should NOT trigger it
6. If the skill has a Q&A phase, verify the questions appear and answers flow correctly

### Regression testing (when improving or rewriting an existing skill)

If you rewrote or generalized a skill, verify the new version is at least as good as the old:

1. **Keep both versions available** — the original (e.g., in `~/.claude/skills/`) and the rewritten copy (e.g., in the repo's `skills/`)
2. **Pick 3-5 real tasks** the old skill was used on — actual card descriptions, real prompts from past work
3. **Walk each task through the new version** — does every gate/step/check still fire on the right triggers?
4. **Check for lost specificity** — did generalizing a gate weaken it? "Use project design tokens" should still lead the agent to `--vulcan-*` on a Vulcan project because the agent reads the project's design system docs.
5. **The key question:** For each gate/rule, would the new version catch the same failure the old version was created to prevent?

If a gate doesn't fire where it should, the generalization went too far — add specificity back without reverting to hardcoded project references.

### Eval loop (for important skills)

If the Anthropic `skill-creator` skill is installed, use its eval/iterate loop for rigorous testing — it handles with-skill vs baseline comparison, grading, and benchmark viewing.

If not installed, test manually: run each prompt, compare with/without the skill, note what worked and what didn't.

### Description optimization (if triggering accuracy matters)

Create 20 eval queries (10 should-trigger, 10 should-not-trigger — focus on near-misses, not obvious non-matches). Test whether the description activates correctly. Adjust wording based on misses and false triggers.

## Phase 5: Publish

For mitre-saf-skills:

1. Copy the skill into `skills/` in the repo
2. Re-run validation (Phase 3) against the repo copy
3. Add to `skills.sh.json` under the appropriate group
4. Update `README.md` skill catalog table
5. Verify: `npx skills add /path/to/repo --list` discovers the skill
6. Submit PR per [CONTRIBUTING.md](../../CONTRIBUTING.md)

## Improving an Existing Skill

1. Read the current SKILL.md completely — every line
2. Gather feedback: present structured options:
   - "It's not triggering when it should"
   - "It triggers but produces wrong output"
   - "It's missing scenarios or edge cases"
   - "It needs spec compliance fixes"
   - "I want to add a feature"
3. Run the validation checklist (Phase 3) — often the issue is a spec violation
4. If content quality: use the test loop (Phase 4) to identify what's failing
5. If triggering: optimize the description with eval queries
6. Apply principle-first writing — state the universal rule, give concrete examples
7. Re-validate and re-test after changes
