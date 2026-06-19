# VitePress Documentation Guide

Reference for Claude Code agents writing and maintaining VitePress documentation sites.

## 1. Directory Structure

```
docs/
  .vitepress/
    config.mts        # Site config (TypeScript, ES modules)
    theme/            # Custom theme entry + CSS overrides (optional)
  public/             # Static assets copied verbatim to site root
  guide/              # Content pages — any nested layout works
  index.md            # Site home page (/)
```

- `.vitepress/dist/` is the build output (gitignored)
- File path = URL path: `docs/guide/foo.md` becomes `/guide/foo.html`
- `docs/index.md` is `/`

## 2. Config File (`.vitepress/config.mts`)

```ts
import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'en-US',
  title: 'Project Name',
  description: 'SEO description.',
  base: '/',  // '/repo/' for GitHub Pages project sites

  themeConfig: {
    logo: '/logo.svg',
    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Deploy', link: '/deployment/docker' },
      { text: 'v2.3', items: [
        { text: 'Changelog', link: '/changelog' },
        { text: 'Releases', link: 'https://github.com/org/repo/releases' }
      ]}
    ],
    sidebar: {
      '/guide/': [{
        text: 'Introduction', collapsed: false,
        items: [
          { text: 'Getting Started', link: '/guide/getting-started' },
          { text: 'Configuration', link: '/guide/configuration' }
        ]
      }],
      '/deployment/': [{
        text: 'Deployment',
        items: [
          { text: 'Docker', link: '/deployment/docker' },
          { text: 'Upgrade Guide', link: '/deployment/upgrade-guide' }
        ]
      }]
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/org/repo' }],
    search: { provider: 'local' },
    editLink: { pattern: 'https://github.com/org/repo/edit/main/docs/:path' }
  }
})
```

**Sidebar types:**
- Array `sidebar: [{ text, items }]` -- single sidebar for all pages
- Object `sidebar: { '/guide/': [...] }` -- per-path sidebars
- Item shape: `{ text: string, link?: string, items?: Item[], collapsed?: boolean }`

## 3. Markdown Extensions

### Custom Containers

```md
::: info
Informational note.
:::

::: tip
Helpful suggestion.
:::

::: warning BREAKING CHANGE
Custom title after the type keyword.
:::

::: danger
Critical issue or destructive action.
:::

::: details Click to expand
Collapsed content.
:::
```

### Code Groups (tabbed blocks)

````md
::: code-group

```sh [npm]
npm install vitepress
```

```sh [yarn]
yarn add vitepress
```

:::
````

### Line Highlighting and Line Numbers

````md
```ts {2}
const a = 1
const b = 2  // highlighted
const c = 3
```

```ts {1,4,6-8}
// highlight specific lines and ranges
```

```ts:line-numbers
// shows line numbers in output
```
````

### Import Code Snippets

```md
<<< @/snippets/config.ts
<<< @/snippets/config.ts{2,4-6}
<<< @/snippets/file.ts#region-name{1}
```

`@` resolves to project source root. Mark regions in source with `// #region name` / `// #endregion name`.

## 4. Frontmatter

```yaml
---
title: Page Title            # <title> tag, sidebar override
description: SEO description # <meta name="description">
outline: [2, 3]             # TOC heading depth (default: 2)
layout: doc                  # doc | home | page (no chrome)
editLink: false              # disable edit link for this page
lastUpdated: true            # git last-updated timestamp
aside: false                 # hide outline panel
---
```

**Home page layout** uses `layout: home` with `hero` and `features` keys:

```yaml
---
layout: home
hero:
  name: Project Name
  text: Tagline
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
features:
  - title: Fast
    details: Built on Vite.
---
```

## 5. Adding a New Page

1. Create the file: `docs/deployment/upgrade-guide.md`
2. Add frontmatter (`title`, `description` minimum)
3. Add to sidebar in `.vitepress/config.mts`:
   ```ts
   items: [
     { text: 'Docker', link: '/deployment/docker' },
     { text: 'Upgrade Guide', link: '/deployment/upgrade-guide' }  // new
   ]
   ```
4. Optionally add to `nav` for top-level visibility
5. Link from other pages: `[Upgrade Guide](/deployment/upgrade-guide)` (no `.md`, no `.html`)

## 6. Asset Handling

| Location | Processing | Reference style |
|----------|-----------|-----------------|
| `docs/public/` | Copied verbatim | Absolute: `![](/logo.svg)` |
| Anywhere in `docs/` | Vite-processed (hashed) | Relative: `![](./assets/img.png)` |

- `public/` for favicons, `robots.txt`, CNAME, OG images
- Relative paths for screenshots/diagrams (enables cache-busting)

## 7. Dev Server and Build

```json
{
  "scripts": {
    "docs:dev": "vitepress dev docs",
    "docs:build": "vitepress build docs",
    "docs:preview": "vitepress preview docs"
  }
}
```

```sh
npm run docs:dev      # Dev server, hot reload (localhost:5173)
npm run docs:build    # Static build → docs/.vitepress/dist/
npm run docs:preview  # Serve built site locally
```

## 8. Common Gotchas

**Vue 3 peer dep conflict** -- VitePress requires Vue 3. If the host app uses Vue 2, keep a separate `package.json` inside `docs/` and install VitePress there. Do NOT hoist into root `node_modules`.

**Base path** -- Set `base: '/repo-name/'` for GitHub Pages project sites. Omit or use `'/'` for custom domains.

**Dead links break build** -- VitePress fails on dead internal links. Fix them or set `ignoreDeadLinks: true`.

**Sidebar link format** -- Must start with `/`, no `.md` or `.html` extension, must match file path relative to docs root exactly.

**Frontmatter must be first** -- No content before the opening `---`. Not even blank lines or HTML comments.

**Use `.mts` not `.ts`** -- For the config file, `.mts` ensures ESM resolution works across all Node versions.

**Clean URLs** -- `cleanUrls: true` removes `.html` from URLs. Requires host support (most static hosts do).

**Multi-sidebar not showing** -- Sidebar object keys must match URL prefix. Page at `/guide/foo` needs key `/guide/` (trailing slash).
