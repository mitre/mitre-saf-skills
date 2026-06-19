# Nuxt Content 3 + MDC Documentation Guide

Reference for building documentation sites with Nuxt Content v3 and `@nuxtjs/mdc`.

## Table of Contents

- [Directory Structure](#1-directory-structure)
- [MDC (Markdown Components) Syntax](#2-mdc-markdown-components-syntax)
- [Frontmatter Fields](#3-frontmatter-fields)
- [Content Navigation](#4-content-navigation)
- [Prose Components](#5-prose-components)
- [Code Highlighting (Shiki)](#6-code-highlighting-shiki)
- [Adding a New Page](#7-adding-a-new-page--controlling-navigation-order)
- [Deployment](#8-deployment)
- [Common Gotchas](#9-common-gotchas)
- [Nuxt UI MDC Components](#10-nuxt-ui-mdc-components-for-projects-using-nuxt-ui-docs-templates)

---

## 1. Directory Structure

```
project/
  content/                    # Default content directory
    index.md                  # Site root page
    getting-started/
      .navigation.yml         # Directory metadata (title, icon)
      1.installation.md       # Ordered by numeric prefix
      2.configuration.md
    guide/
      .navigation.yml
      1.basics.md
  content.config.ts           # Collection definitions + schemas
  nuxt.config.ts              # Module registration
  components/content/         # MDC-available Vue components
```

### nuxt.config.ts

```typescript
export default defineNuxtConfig({
  modules: ['@nuxt/content'],
  content: {
    // Options (most configuration moved to content.config.ts in v3)
    highlight: {
      theme: 'github-dark',
      langs: ['js', 'ts', 'vue', 'bash', 'yaml', 'json', 'ruby']
    }
  }
})
```

### content.config.ts (v3 collections)

```typescript
import { defineContentConfig, defineCollection, z } from '@nuxt/content'

export default defineContentConfig({
  collections: {
    docs: defineCollection({
      type: 'page',
      source: '**/*.md',
      schema: z.object({
        icon: z.string().optional(),
        badge: z.string().optional()
      })
    })
  }
})
```

---

## 2. MDC (Markdown Components) Syntax

MDC lets you use Vue components inside Markdown files.

### Block Component (double colon)

```markdown
::alert{type="warning" title="Heads up"}
This is the **default slot** content with full Markdown support.
::
```

### Block Component with Named Slots (triple colon for nesting)

```markdown
::card
---
icon: i-lucide-rocket
---

#title
Getting Started

#description
Follow these steps to set up your project.

#default
Full markdown body content here.
::
```

### Nested Components

```markdown
:::steps
::step{title="Install"}
Run `npx nuxi init` to scaffold your project.
::

::step{title="Configure"}
Edit `nuxt.config.ts` to add modules.
::
:::
```

### Inline Component (single colon)

```markdown
This is a paragraph with an :badge[Beta]{color="blue"} inline component.
```

### Props Syntax

- YAML block (between `---` fences inside the component)
- Inline attributes: `::component{prop="value" flag}`
- Boolean props: `::component{centered}` (truthy)

---

## 3. Frontmatter Fields

```yaml
---
title: Page Title                    # Required - used in nav + <title>
description: Short summary           # Meta description, SEO
navigation: true                     # Include in nav (default: true)
navigation.title: Short Nav Title    # Override title in navigation
navigation.icon: i-lucide-book       # Icon in navigation tree
navigation.badge: New                # Badge next to nav item
head:
  meta:
    - name: og:image
      content: /social-card.png
---
```

Set `navigation: false` to exclude a page from the navigation tree entirely.

---

## 4. Content Navigation

### Automatic (from directory structure)

Navigation is generated from the file system. Ordering uses numeric prefixes:

```
content/
  1.getting-started/       # First section
    1.installation.md      # First page in section
    2.setup.md             # Second page
  2.guide/                 # Second section
    1.basics.md
```

The numeric prefix is stripped from the URL: `1.installation.md` becomes `/getting-started/installation`.

### .navigation.yml (replaces _dir.yml in v3)

Place in any directory to set metadata for that nav section:

```yaml
title: Getting Started
icon: i-lucide-square-play
```

### Querying Navigation

```vue
<script setup lang="ts">
const { data: nav } = await useAsyncData('navigation', () => {
  return queryCollectionNavigation('docs')
})
</script>
```

Filter and order:

```typescript
queryCollectionNavigation('docs')
  .where('published', '=', true)
  .order('date', 'DESC')
```

---

## 5. Prose Components

Prose components override default Markdown element rendering. Place in `components/content/`:

| Component | Renders |
|-----------|---------|
| `ProseH1` - `ProseH6` | Headings |
| `ProseP` | Paragraphs |
| `ProseA` | Links |
| `ProseCode` | Inline `code` |
| `ProsePre` | Fenced code blocks |
| `ProseTable`, `ProseTh`, `ProseTr`, `ProseTd` | Tables |
| `ProseUl`, `ProseOl`, `ProseLi` | Lists |
| `ProseBlockquote` | Blockquotes |
| `ProseImg` | Images |
| `ProseHr` | Horizontal rules |

Override example (`components/content/ProseH1.vue`):

```vue
<template>
  <h1 class="text-3xl font-bold tracking-tight">
    <slot />
  </h1>
</template>
```

---

## 6. Code Highlighting (Shiki)

### Basic Syntax

````markdown
```typescript [nuxt.config.ts]{2-3}
export default defineNuxtConfig({
  modules: ['@nuxt/content'],  // highlighted
  devtools: { enabled: true }  // highlighted
})
```
````

- `[filename]` - displays a filename tab
- `{2-3}` - highlights lines 2 and 3
- Escape `]` in filenames with `\]`

### Code Groups

````markdown
::code-group
```bash [npm]
npm install @nuxt/content
```

```bash [yarn]
yarn add @nuxt/content
```

```bash [pnpm]
pnpm add @nuxt/content
```
::
````

### Configuration

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  content: {
    highlight: {
      theme: {
        default: 'github-light',
        dark: 'github-dark'
      },
      langs: ['js', 'ts', 'vue', 'bash', 'yaml', 'json', 'ruby', 'sql']
    }
  }
})
```

---

## 7. Adding a New Page + Controlling Navigation Order

1. Create the file with a numeric prefix for ordering:
   ```
   content/guide/3.new-page.md
   ```

2. Add frontmatter:
   ```yaml
   ---
   title: New Page
   description: What this page covers.
   navigation.icon: i-lucide-file-plus
   ---
   ```

3. The page automatically appears in navigation at position 3.

4. To reorder, rename prefixes (e.g., rename `3.old.md` to `4.old.md`).

5. To add a new section, create a directory with prefix + `.navigation.yml`.

---

## 8. Deployment

### Static Generation (SSG)

```bash
npx nuxi generate          # Outputs to .output/public/
```

### Server-Side Rendering (SSR)

```bash
npx nuxi build             # Outputs to .output/
```

### Platform Presets

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  nitro: {
    preset: 'cloudflare-pages'  // or 'vercel', 'netlify'
  }
})
```

| Platform | Preset | Deploy Command |
|----------|--------|---------------|
| Cloudflare Pages | `cloudflare-pages` | `npx wrangler pages deploy .output/public` |
| Vercel | `vercel` (auto-detected) | `vercel deploy` |
| Netlify | `netlify` (auto-detected) | Push to connected repo |
| GitHub Pages | `github-pages` | `nuxi generate` + deploy `.output/public` |

For static sites, set `routeRules` to prerender all content:

```typescript
export default defineNuxtConfig({
  routeRules: {
    '/**': { prerender: true }
  }
})
```

---

## 9. Common Gotchas

### MDC Indentation
- Content inside `::component` blocks must NOT be indented relative to the `::` markers.
- Indented content is treated as nested code blocks, not component slot content.

### Component Registration
- Components used in MDC must be in `components/content/` (auto-registered) or globally registered.
- Component names in MDC are kebab-case: `MyAlert.vue` becomes `::my-alert`.
- Subdirectories work: `components/content/landing/Hero.vue` becomes `::landing-hero`.

### Content Caching
- Development: hot-reload works automatically.
- Production (SSG): content is baked at build time. Rebuild to update.
- Production (SSR): content is cached. Clear `.nuxt/content` or set cache TTL.
- After changing `content.config.ts`, restart the dev server (schema changes are not hot-reloaded).

### Migration from v2 to v3
- `_dir.yml` renamed to `.navigation.yml`.
- Collections replace the query builder API (`queryContent()` becomes `queryCollection()`).
- Schema validation via Zod in `content.config.ts` (not optional frontmatter).
- `fetchContentNavigation()` replaced by `queryCollectionNavigation()`.

### MDCSlot vs Vue Slot
- Inside MDC components, use `<MDCSlot>` instead of `<slot>` to properly render Markdown.
- Use `unwrap="p"` to strip paragraph wrappers from single-line slot content:
  ```vue
  <MDCSlot unwrap="p" />
  ```

### YAML Frontmatter
- Must be the very first thing in the file (no blank lines before `---`).
- Dates must be valid ISO format or Zod parsing will fail silently.

---

## 10. Nuxt UI MDC Components (for projects using Nuxt UI docs templates)

If the project uses Nuxt UI's documentation template, these MDC components are available:

### Callouts
```markdown
::note
Background context.
::

::tip
Pro tip.
::

::warning
Be careful.
::

::caution
**NEVER do X.** Cannot be undone.
::

::callout{icon="i-lucide-shield-x" color="error"}
Custom icon + color callout.
::
```
Colors: `error`, `primary`, `secondary`, `success`, `info`, `warning`, `neutral`.

### Tabs
```markdown
::tabs
  :::tabs-item{label="Tab A"}
  Content for tab A.
  :::
  :::tabs-item{label="Tab B"}
  Content for tab B.
  :::
::
```
Inner components use one MORE colon than parent (MDC nesting rule).

### Steps (auto-numbered from h3 headings)
```markdown
::steps
### First step
Content.
### Second step
Content.
::
```

### Code Groups
```markdown
::code-group
```typescript [Before]
// old way
```
```typescript [After]
// new way
```
::
```

### Fields (API props, config options)
```markdown
::field{name="identifier" type="string" required}
Human-readable ID.
::
```

### Cards
```markdown
::card-group
::card{title="Feature A" icon="i-lucide-zap"}
Description.
::
::card{title="Feature B" icon="i-lucide-shield"}
Description.
::
::
```

### Accordion
```markdown
::accordion
  ::accordion-item{label="Question?"}
  Answer.
  ::
::
```

Browse icons at [icones.js.org](https://icones.js.org) — prefer `lucide` collection (`i-lucide-*`).
