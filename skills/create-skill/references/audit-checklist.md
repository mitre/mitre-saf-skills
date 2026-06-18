# Skill Audit Checklist

Systematic review of an existing skill across 7 dimensions. Read the entire SKILL.md and all files in the skill directory before starting. Report each check as PASS, WARN, or FAIL with evidence.

## How to Run an Audit

1. **Fetch current standards first** — the spec evolves. Before auditing, fetch:
   - [Agent Skills Spec](https://agentskills.io/specification) — current frontmatter schema, naming rules, progressive disclosure
   - [Best Practices](https://agentskills.io/skill-creation/best-practices) — current writing style, calibration guidance
   - Use Context7 MCP (`resolve-library-id` for "agentskills") or web fetch. If neither is available, proceed with the checklist below — it reflects the spec as of the last update, but the live spec is authoritative.
2. Read the SKILL.md completely
3. List all files in the skill directory (`references/`, `scripts/`, `assets/`)
4. Read every supporting file
5. Run each dimension below, comparing against both the fetched spec AND this checklist
6. **Classify grep hits by context** — see "Avoiding False Positives" below
7. Produce a findings report grouped by severity (FAIL → WARN → PASS)
8. End with a summary: total findings, top 3 fixes, overall publish-readiness

## Avoiding False Positives

Grep-based checks catch patterns in ALL text, including examples, checklists, and documentation of what NOT to do. A checklist that says `"Aaron said X" → state X directly` will trigger on "Aaron" even though it's an example of a bad pattern, not an actual violation.

**Context classification (apply to every grep hit):**

Before marking a finding as FAIL or WARN, check WHERE the match occurs:

| Context | How to identify | Verdict |
|---------|----------------|---------|
| Inside a markdown table cell showing an example | Line contains `\|` table delimiters AND the match is in a "bad example" or "how to verify" column | **FALSE POSITIVE** — skip |
| Inside a fenced code block as an example | Between `` ``` `` markers, showing what to grep FOR | **FALSE POSITIVE** — skip |
| Inside a "how to verify" instruction | Line describes the grep command itself (e.g., "grep for `.local`") | **FALSE POSITIVE** — skip |
| In a "bad example" showing what not to do | Line is preceded by "BAD", "WRONG", "avoid", or is in a "don't do this" context | **FALSE POSITIVE** — skip |
| In actual skill instructions or content | Not in any of the above contexts | **REAL FINDING** — report it |

**The practical approach:** When grep returns hits, read the surrounding 3 lines. If the match is inside a table, code block, or "what to look for" instruction, classify it as a false positive and note "FALSE POSITIVE: checklist example" in the report rather than omitting it — transparency about what was checked and why it was excluded.

**Why grep alone isn't enough:** Static analysis tools (semgrep, markdownlint, shellcheck) solve this by parsing structure — ASTs for code, markdown structure for docs. Grep operates on raw text with no structural awareness. For markdown skills, the agent IS the structural parser: it can read the markdown, understand that a table cell is an example, and classify accordingly. This is one of the few cases where an AI agent genuinely outperforms a script — it understands context.

## Dimension 1: Spec Compliance

Check the skill against the Agent Skills specification requirements.

| Check | How to verify | Severity if failed |
|-------|---------------|-------------------|
| `name` matches directory name | Compare frontmatter `name:` to parent directory | FAIL |
| `name` is valid (lowercase, hyphens, 1-64 chars, no leading/trailing/consecutive hyphens) | Inspect the value | FAIL |
| `description` is 1-1024 characters | Count characters | FAIL |
| `description` says what AND when | Look for "Use when..." or trigger scenarios | WARN |
| SKILL.md under 500 lines | `wc -l` | WARN |
| No non-spec top-level frontmatter fields | Only `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools` allowed. Custom fields go under `metadata:` | WARN |
| File references use relative paths | `grep -rn '~/\|/Users/\|/home/' .` should return 0 | FAIL |
| References are one level deep | No `references/sub/sub/file.md` chains | WARN |

## Dimension 2: Description Quality

The description determines whether the skill triggers. This is the highest-leverage field.

| Check | How to verify | Severity if failed |
|-------|---------------|-------------------|
| Includes "Use when..." with 2+ concrete scenarios | Read the description | WARN |
| Names the domain clearly | Does a reader immediately know what domain this covers? | WARN |
| Slightly "pushy" — agents under-trigger by default | Would an agent activate this for edge cases, not just obvious ones? | WARN |
| No marketing words | grep for "comprehensive", "robust", "enterprise-grade", "production-ready", "seamless" — classify each hit by context before reporting | FAIL |
| No vague descriptions | "Helps with X" is too vague. Must say what it DOES and WHEN | WARN |
| Under 1024 characters | Count | FAIL |
| Would NOT false-trigger on adjacent domains | Does the description scope tightly enough? E.g., "spec files" could mis-trigger on `.spec.ts` if it's meant for RSpec | WARN |

## Dimension 3: Progressive Disclosure

Is content organized for efficient context usage?

| Check | How to verify | Severity if failed |
|-------|---------------|-------------------|
| Core workflow is in SKILL.md (not buried in references) | The steps the agent follows every time should be front and center | WARN |
| Gotchas/anti-patterns are in SKILL.md (not in references) | These must be seen before the agent hits the problem | WARN |
| Detailed/conditional content is in references/ | Content only needed in specific modes or conditions should not load every time | WARN |
| "Read when..." pointers are specific conditions | Not "see references/" but "Read X when Y condition is met" | WARN |
| Large reference files (>300 lines) have a table of contents | Per spec recommendation | WARN |
| Total SKILL.md is under 5000 tokens (~500 lines) | Measure or estimate | WARN |

**Analysis to perform:** For each section of SKILL.md, ask: "Is this needed on EVERY activation, or only in specific conditions?" If only specific conditions, it should be in `references/` with a conditional pointer.

## Dimension 4: Portability

Will this skill work across Claude Code, Cursor, Codex, Copilot, Windsurf, Gemini, and Cline?

**All grep checks in this dimension require context classification** — apply the "Avoiding False Positives" rules above to every hit before reporting. Install instructions (`ln -sfn ... ~/.claude/skills/`), checklist examples, and "what to grep for" instructions are false positives.

| Check | How to verify | Severity if failed |
|-------|---------------|-------------------|
| No absolute paths | `grep -rn '/Users/\|/home/\|~/.claude/\|~/.cursor/\|~/.agents/' .` = 0 | FAIL |
| No `$SKILL_DIR` or `$SKILLS_HOME` variables | The spec has no such standard — use relative paths | FAIL |
| No tool-specific features | grep for `TodoWrite`, `TaskCreate`, `AskUserQuestion`, `.claude/hooks/`, `.claude/settings.json`, `.claude/agents/` | WARN |
| No slash command references | grep for `/skill-name` patterns (use plain skill names instead) | WARN |
| No wikilink references | grep for `[[skill-name]]` (use plain skill names instead) | WARN |
| No subagent-specific language | "spawn a bounded review agent" → "conduct an independent review" | WARN |
| Scripts use self-location | Python: `Path(__file__).parent`. Bash: `$(dirname "$0")`. Not env vars. | FAIL |
| `compatibility` field lists external requirements | If the skill needs tools not bundled with the agent | WARN |

## Dimension 5: Content Quality

Is the skill well-written and effective?

**Context classification is critical here.** Checks for person names, dates, and internal references will hit examples in checklists and anti-pattern documentation. Read each hit in context — a table cell showing `"Aaron said X" → state X directly` is an example of what to fix, not a violation.

| Check | How to verify | Severity if failed |
|-------|---------------|-------------------|
| Principle-first writing | Universal principles stated before stack-specific examples | WARN |
| Concrete examples provided | Not just abstract rules — show input/output pairs or code | WARN |
| Imperative form | "Run this command" not "You should run this command" | WARN |
| Explains WHY for non-obvious rules | Agent understands reasoning, not just rote instructions | WARN |
| No person names with attribution | grep for names — classify each hit by context. This table cell is an example, not a violation. | FAIL (if publishing) |
| No dated internal incidents | grep for date patterns — classify by context. "In a prior incident" is the replacement pattern. | FAIL (if publishing) |
| No internal epic/card IDs | beads IDs, PR numbers specific to one project — classify by context | FAIL (if publishing) |
| No internal repo references | Private repos, internal hostnames, personal paths — classify by context | FAIL |
| Multi-stack examples where applicable | E.g., "rubocop:disable (Ruby), eslint-disable (JS), @ts-ignore (TS)" | WARN |

## Dimension 6: Security

Would publishing this skill expose sensitive information?

**Context classification applies here too** — a script that documents `os.environ.get("API_KEY")` as the correct pattern should not be flagged for containing "API_KEY". The check is whether the key is hardcoded, not whether the string appears.

| Check | How to verify | Severity if failed |
|-------|---------------|-------------------|
| No hardcoded credentials | `grep -rni 'api_key\|token\|password\|secret' scripts/` — verify env var usage | FAIL |
| No credential files | `find . -name '*credential*' -o -name '*.key' -o -name '*.pem'` | FAIL |
| No internal hostnames | grep for `.local`, `192.168.`, `10.0.`, internal domain names | FAIL |
| Scripts read secrets from env vars | `os.environ.get("KEY")` not hardcoded values | FAIL |
| No embedded .git/ repos | `find . -name '.git' -type d` | FAIL |
| No large binary files | Model weights, vector DBs, training data should not be in the skill | WARN |
| No internal strategy/planning docs | `.beads/recovery-context.md` type content | FAIL |
| Third-party content has license clearance | CIS Benchmark content is copyrighted. NIST/DISA/STIG is public domain. | WARN |

## Dimension 7: Q&A Opportunities

Should this skill be gathering context it's currently guessing at?

**Analysis to perform:** Walk through the skill's workflow and at each decision point ask:

1. Can the agent determine this from context, arguments, or auto-detection?
2. If not, could structured options help the user choose?
3. Is there a clear default, or is the choice genuinely ambiguous?

| Pattern | Recommendation |
|---------|---------------|
| Skill has multiple modes but guesses from context | Add Q&A fallback when detection is ambiguous |
| Skill needs to scope its work (which domains, which platform) | Add scoping Q&A with "all" as default |
| Skill auto-detects something but detection can fail | Add Q&A as a fallback path |
| Skill has a single linear workflow with no choices | No Q&A needed |
| Skill gets all input from arguments or card descriptions | No Q&A needed |

## Output Format

After running all 7 dimensions, produce a report:

```markdown
# Skill Audit: <skill-name>

## Summary
- **Total findings:** N real (X FAIL, Y WARN, Z PASS) + M false positives classified
- **Publish readiness:** READY / NEEDS WORK / NOT PUBLISHABLE
- **Top 3 fixes:** (highest impact changes)

## FAIL (must fix)
| Dimension | Check | Evidence | Fix |
|-----------|-------|----------|-----|
| ... | ... | ... | ... |

## WARN (should fix)
| Dimension | Check | Evidence | Fix |
|-----------|-------|----------|-----|
| ... | ... | ... | ... |

## FALSE POSITIVES (classified and excluded)
| Dimension | Check | Hit | Why excluded |
|-----------|-------|-----|-------------|
| D5 | Person name | Line 87: `"Aaron said X" → state X` | Checklist example showing what to fix |
| D2 | Marketing word | Line 42: `grep for "comprehensive"` | Audit instruction, not content |

## PASS (no issues)
- List of passed checks (collapsed or brief)

## Q&A Opportunities
- Where structured questions could improve the skill's workflow
```
