---
name: project-docs
description: >-
  Write and update project documentation. Auto-detects the doc system (VitePress,
  MkDocs, Nuxt Content, Docusaurus, Sphinx) and loads the matching style guide.
  Use when creating or updating docs pages, READMEs, API references, deployment
  guides, or any project documentation.
license: Apache-2.0
---

# Project Documentation Standards

**Invoke this skill when writing or updating documentation pages.**

## MANDATORY: Read Source Before Writing

**BEFORE writing ANY documentation content, READ the actual source files the page describes.** This is a hard gate — no exceptions.

- Writing about a CLI? Read the command definitions (args, flags, descriptions).
- Writing about an API? Read the route contracts and handlers.
- Writing about workflows? Read the `scripts/` directory for actual scripts that exist.
- Writing about configuration? Read the env schema or config file — it's the source of truth.
- Writing about any feature? Read the implementation file, not your memory of it.

**The rule:** If you haven't run `Read` on the source file in this conversation, you cannot write documentation about it. "I remember what it does" is not sufficient — code changes between sessions. Documentation written from memory will be wrong, and wrong docs are worse than no docs.

## Step 1: Detect Documentation System

Check the project for these markers. First match wins.

| Marker | System | Guide to load |
|---|---|---|
| `docs/.vitepress/` or `.vitepress/` | VitePress | Read `guides/vitepress.md` |
| `mkdocs.yml` | MkDocs (Material) | Read `guides/mkdocs.md` |
| `nuxt.config.*` + `content/` dir | Nuxt Content 3 | Read `guides/nuxt-content.md` |
| `docusaurus.config.*` | Docusaurus | Read `guides/docusaurus.md` |
| `docs/conf.py` or `conf.py` | Sphinx | Read `guides/sphinx.md` |
| None found | Unknown | Ask the user (see fallback below) |

**If no doc system is detected**, ask the user:

**Which documentation system does this project use?**
- "VitePress" → Read `guides/vitepress.md`
- "MkDocs / Material" → Read `guides/mkdocs.md`
- "Nuxt Content" → Read `guides/nuxt-content.md`
- "Docusaurus" → Read `guides/docusaurus.md`
- "Sphinx" → Read `guides/sphinx.md`
- "None / plain markdown" → Use generic markdown conventions, no guide needed
- "Something else" → Use Context7 MCP to fetch docs for the system

**Action:** Run this check:
```bash
ls -d docs/.vitepress .vitepress mkdocs.yml docusaurus.config.* docs/conf.py content/ 2>/dev/null | head -1
```

Then use the Read tool to load ONLY the matching guide file. Do not load guides for other systems.

**If no marker is found:** Check if Context7 MCP is available. Use `resolve-library-id` with the doc framework name, then `query-docs` for conventions. If Context7 isn't available, ask the user what documentation system they use.

## Step 2: Apply Universal Documentation Principles

These apply regardless of which doc system is detected.

### When to Update Docs

Documentation must be updated in the SAME commit/PR as the code change when:
- A Dockerfile or docker-compose changes → update deployment docs
- A new API endpoint is added → update API docs
- A new rake task / CLI command is added → update command reference
- Configuration format changes → update config reference
- A migration changes schema → update data model docs (if documented)

### Writing Quality

- **Lead with the user's goal**, not the implementation ("To deploy with Docker" not "The Dockerfile uses multi-stage builds")
- **Code examples must be copy-pasteable** — no `...` elision in commands, no `<placeholder>` without explaining what to substitute
- **One heading level per topic** — don't nest deeper than `####`
- **Cross-reference related pages** — don't duplicate content, link to the single source of truth
- **Test your commands** — every `bash` code block should be runnable. If it requires setup, say so.

### File Co-location

These docs typically change together:
- Dockerfile + `deployment/docker.md` + `development/architecture.md`
- `config/` files + `getting-started/configuration.md` + `ENVIRONMENT_VARIABLES.md`
- New feature + user guide + API docs + changelog

### Markdown Conventions (universal)

- ATX headings (`##` not underline style)
- Fenced code blocks with language tags (```bash, ```ruby, ```yaml)
- Tables for structured reference data
- Relative links between docs pages (not absolute URLs to the deployed site)
- No trailing whitespace
- Single blank line between sections

## Step 3: Follow System-Specific Guide

After loading the matching guide from Step 1, follow its conventions for:
- Directory structure and file placement
- Configuration (sidebar, navigation, theme)
- Markdown extensions (admonitions, tabs, code groups, components)
- Frontmatter fields
- Build and dev server commands
- System-specific gotchas

## Related Skills

- project-card skill — Card template for beads issues
- project-tdd skill — TDD quality gates
- Context7 MCP — for fetching current docs of any framework dynamically
