# MkDocs with Material Theme — Reference Guide

## Directory Structure

```
project-root/
├── mkdocs.yml              # Main configuration
├── docs/
│   ├── index.md            # Homepage (required)
│   ├── assets/stylesheets/extra.css
│   ├── guide/
│   │   ├── index.md        # Section landing
│   │   └── installation.md
│   └── reference/api.md
├── overrides/              # Template overrides (optional)
└── site/                   # Build output (gitignored)
```

Files in `docs/` map to URL paths: `docs/guide/installation.md` becomes `/guide/installation/`.

---

## mkdocs.yml — Full Configuration

```yaml
site_name: My Project
site_url: https://docs.example.com/
site_description: Project documentation
repo_url: https://github.com/org/project
repo_name: org/project
edit_uri: edit/main/docs/

theme:
  name: material
  palette:
    - scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.tabs            # Top-level nav as horizontal tabs
    - navigation.tabs.sticky     # Tabs visible on scroll
    - navigation.sections        # Bold top-level sidebar items
    - navigation.instant         # SPA-like XHR page loads
    - navigation.instant.prefetch
    - navigation.top             # Back-to-top button
    - search.suggest             # Search autocomplete
    - search.highlight           # Highlight matches on page
    - content.code.copy          # Copy button on code blocks
    - content.code.annotate      # Code annotations (1)!
    - content.tabs.link          # Linked content tabs
    - toc.integrate              # TOC in left sidebar
  icon:
    repo: fontawesome/brands/github

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - User Guide:
      - guide/index.md
      - Installation: guide/installation.md
      - Configuration: guide/configuration.md
  - Reference:
      - API: reference/api.md

markdown_extensions:
  - toc:
      permalink: true
      toc_depth: 3
  - tables
  - attr_list
  - md_in_html
  - def_list
  - admonition
  - pymdownx.details
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.highlight:
      anchor_linenums: true
      line_spans: __span
      pygments_lang_class: true
  - pymdownx.inlinehilite
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.emoji:
      emoji_index: !!python/name:material.extensions.emoji.twemoji
      emoji_generator: !!python/name:material.extensions.emoji.to_svg
  - pymdownx.tasklist:
      custom_checkbox: true
  - pymdownx.snippets
  - pymdownx.keys
  - pymdownx.mark

plugins:
  - search
  - tags

extra_css:
  - assets/stylesheets/extra.css

docs_dir: docs
site_dir: site
strict: true
use_directory_urls: true
```

---

## Adding a New Page

1. Create the file: `docs/guide/deployment.md`
2. Wire into `nav` in `mkdocs.yml`:
   ```yaml
   nav:
     - User Guide:
         - guide/index.md
         - Installation: guide/installation.md
         - Deployment: guide/deployment.md   # new entry
   ```

If `nav` is omitted entirely, MkDocs auto-discovers pages alphabetically. Once `nav` is defined, only listed pages appear in navigation.

---

## Markdown Extensions Reference

### Admonitions

```markdown
!!! note "Optional Title"
    Content MUST be indented exactly 4 spaces.

!!! warning
    Default title is the type name capitalized.

??? tip "Collapsible (closed by default)"
    Requires `pymdownx.details` extension.

???+ example "Collapsible (open by default)"
    The `+` makes it start expanded.
```

**Types**: `note`, `abstract`, `info`, `tip`, `success`, `question`, `warning`, `failure`, `danger`, `bug`, `example`, `quote`

### Content Tabs

```markdown
=== "Python"

    ```python
    print("Hello")
    ```

=== "JavaScript"

    ```javascript
    console.log("Hello");
    ```
```

### Code Annotations

````markdown
```yaml
theme:
  name: material # (1)!
```

1. Annotation text appears as an expandable tooltip.
````

Requires `content.code.annotate` in theme features.

### Icons and Emojis

```markdown
:material-account-circle:     — Material Design icons
:fontawesome-brands-github:   — Font Awesome icons
:octicons-heart-fill-24:      — Octicons
:smile:                       — Twemoji
```

### Keys and Attribute Lists

```markdown
++ctrl+alt+del++                                    — Keyboard keys
[Button](url){ .md-button .md-button--primary }     — Styled link
![Image](img.png){ width="300" }                    — Image attrs
```

---

## Material Theme Features Summary

| Feature | Config Key | Effect |
|---------|-----------|--------|
| Navigation tabs | `navigation.tabs` | Top-level sections as tab bar |
| Instant loading | `navigation.instant` | No full page reload (XHR) |
| Search suggest | `search.suggest` | Autocomplete dropdown |
| Dark mode | Two `palette` entries + `toggle` | User-switchable light/dark |
| Back to top | `navigation.top` | Floating button on scroll-up |
| Code copy | `content.code.copy` | Copy button on fenced blocks |
| Integrated TOC | `toc.integrate` | TOC merges into left sidebar |

**Color schemes**: `default` (light), `slate` (dark). Custom schemes via `[data-md-color-scheme="name"] { ... }` in extra CSS.

---

## Dev Server and Build Commands

```bash
pip install mkdocs-material       # Installs mkdocs + all extensions

mkdocs serve                      # Dev server at http://127.0.0.1:8000
mkdocs serve -a 0.0.0.0:8080     # Custom host/port
mkdocs serve --dirtyreload        # Faster (only rebuilds changed files)

mkdocs build                      # Production build to site/
mkdocs build --strict             # Fail on warnings (use in CI)
mkdocs build --clean              # Remove stale files first

mkdocs gh-deploy --force          # Deploy to GitHub Pages
```

---

## Common Gotchas

1. **Admonition indentation**: Content MUST be indented exactly 4 spaces. Wrong indentation silently breaks rendering.
2. **Plugin ordering**: `search` should be first. Plugins execute in listed order.
3. **Nav paths relative to `docs_dir`**: Use `guide/install.md`, not `docs/guide/install.md`.
4. **Superfences before tabbed**: `pymdownx.superfences` must precede `pymdownx.tabbed`.
5. **`strict: true`**: Always enable in CI — warnings become errors, catches broken links.
6. **`!!python/name:` is not a comment**: Emoji extension YAML syntax is required verbatim.
7. **`use_directory_urls: true`** (default): `page.md` becomes `page/index.html`. Use trailing `/` in links.
8. **`alternate_style: true` required**: Tabs without it use deprecated rendering.
9. **Missing `pymdownx.details`**: Collapsible admonitions (`???`) silently render as plain text.
10. **Mermaid needs `custom_fences`**: Diagrams require explicit config under `pymdownx.superfences`.
