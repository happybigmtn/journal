# Neovim Automated Journaling System

## Overview

A fully automated journaling system built in Neovim (no plugins) that publishes to a lightweight Astro static site with Minimalist Monochrome design. Incorporates Five Minute Journal, Daily Stoic, and life replay features.

## Technical Stack

- **Editor:** Neovim with custom Lua configuration (no plugins)
- **Static Site:** Astro 4.x
- **Styling:** Vanilla CSS with monochrome palette
- **Automation:** Neovim autocmds + shell scripts
- **Hosting:** GitHub Pages (optional)

---

## Phase 1: Astro Site Foundation

### 1.1 Initialize Astro Project

```bash
npm create astro@latest site -- --template minimal --no-install
cd site && npm install
```

### 1.2 Project Structure

```
journal/
├── site/                      # Astro static site
│   ├── src/
│   │   ├── content/
│   │   │   └── journal/       # Markdown entries
│   │   │       └── 2025/
│   │   │           └── 01/
│   │   │               └── 2025-01-08.md
│   │   ├── layouts/
│   │   │   └── BaseLayout.astro
│   │   │   └── EntryLayout.astro
│   │   ├── pages/
│   │   │   ├── index.astro    # Archive/timeline
│   │   │   ├── [...slug].astro
│   │   │   └── tags/
│   │   │       └── [tag].astro
│   │   └── styles/
│   │       └── global.css     # Monochrome styles
│   └── astro.config.mjs
├── nvim/                      # Neovim configuration
│   └── journal.lua
├── scripts/
│   └── publish.sh
└── templates/
    ├── daily.md
    ├── weekly.md
    └── monthly.md
```

### 1.3 Astro Configuration

```javascript
// site/astro.config.mjs
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://yourusername.github.io',
  base: '/journal',
  output: 'static',
  markdown: {
    shikiConfig: {
      theme: 'min-light'
    }
  }
});
```

### 1.4 Content Collection Schema

```typescript
// site/src/content/config.ts
import { defineCollection, z } from 'astro:content';

const journal = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    mood: z.string().optional(),
    tags: z.array(z.string()).default([]),
    type: z.enum(['daily', 'weekly', 'monthly']).default('daily'),
    draft: z.boolean().default(false),
  }),
});

export const collections = { journal };
```

---

## Phase 2: Minimalist Monochrome Design

### 2.1 Global Styles

```css
/* site/src/styles/global.css */

:root {
  --black: #000000;
  --charcoal: #1a1a1a;
  --gray-dark: #333333;
  --gray-mid: #666666;
  --gray-light: #999999;
  --off-white: #fafafa;
  --white: #ffffff;

  --font-serif: 'Georgia', 'Times New Roman', serif;
  --font-sans: 'Helvetica Neue', Arial, sans-serif;

  --max-width: 38rem;
  --line-height: 1.7;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html {
  font-size: 18px;
}

body {
  font-family: var(--font-serif);
  line-height: var(--line-height);
  color: var(--charcoal);
  background: var(--white);
  -webkit-font-smoothing: antialiased;
}

/* Typography */
h1, h2, h3 {
  font-family: var(--font-sans);
  font-weight: 400;
  letter-spacing: -0.02em;
  color: var(--black);
}

h1 { font-size: 2rem; margin-bottom: 1.5rem; }
h2 { font-size: 1.25rem; margin: 2rem 0 1rem; }
h3 { font-size: 1rem; margin: 1.5rem 0 0.75rem; }

p { margin-bottom: 1.25rem; }

/* Links */
a {
  color: var(--charcoal);
  text-decoration: underline;
  text-underline-offset: 2px;
}

a:hover {
  color: var(--black);
  background: var(--black);
  color: var(--white);
  text-decoration: none;
  padding: 0 2px;
}

/* Layout */
.container {
  max-width: var(--max-width);
  margin: 0 auto;
  padding: 3rem 1.5rem;
}

/* Entry styles */
.entry-date {
  font-family: var(--font-sans);
  font-size: 0.875rem;
  color: var(--gray-mid);
  letter-spacing: 0.05em;
  text-transform: uppercase;
  margin-bottom: 0.5rem;
}

.entry-mood {
  font-size: 0.875rem;
  color: var(--gray-light);
  margin-bottom: 2rem;
}

.prompt {
  font-style: italic;
  color: var(--gray-dark);
  margin-bottom: 0.5rem;
}

.response {
  margin-bottom: 1.5rem;
}

/* Archive */
.archive-year {
  font-family: var(--font-sans);
  font-size: 1.5rem;
  font-weight: 400;
  margin: 2rem 0 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--gray-light);
}

.archive-month {
  font-family: var(--font-sans);
  font-size: 0.875rem;
  color: var(--gray-mid);
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin: 1.5rem 0 0.5rem;
}

.archive-list {
  list-style: none;
}

.archive-list li {
  margin: 0.25rem 0;
}

.archive-list a {
  text-decoration: none;
  display: flex;
  justify-content: space-between;
  padding: 0.25rem 0;
}

.archive-list a:hover {
  background: none;
  color: var(--black);
}

/* Navigation */
.nav {
  display: flex;
  justify-content: space-between;
  font-family: var(--font-sans);
  font-size: 0.875rem;
  margin-top: 3rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--gray-light);
}

.nav a {
  text-decoration: none;
}

/* Tags */
.tags {
  margin-top: 2rem;
  font-family: var(--font-sans);
  font-size: 0.75rem;
  color: var(--gray-mid);
}

.tags a {
  margin-right: 0.5rem;
}

/* Responsive */
@media (max-width: 600px) {
  html { font-size: 16px; }
  .container { padding: 2rem 1rem; }
}

/* Images grayscale */
img {
  filter: grayscale(100%);
  max-width: 100%;
}
```

### 2.2 Base Layout

```astro
---
// site/src/layouts/BaseLayout.astro
import '../styles/global.css';

interface Props {
  title: string;
}

const { title } = Astro.props;
---

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital@0;1&display=swap" rel="stylesheet">
</head>
<body>
  <main class="container">
    <slot />
  </main>
</body>
</html>
```

### 2.3 Entry Layout

```astro
---
// site/src/layouts/EntryLayout.astro
import BaseLayout from './BaseLayout.astro';
import { getCollection } from 'astro:content';

const { entry } = Astro.props;
const { Content } = await entry.render();

// Get all entries for prev/next navigation
const allEntries = await getCollection('journal');
const sortedEntries = allEntries.sort((a, b) =>
  new Date(b.data.date).getTime() - new Date(a.data.date).getTime()
);
const currentIndex = sortedEntries.findIndex(e => e.slug === entry.slug);
const prevEntry = sortedEntries[currentIndex + 1];
const nextEntry = sortedEntries[currentIndex - 1];

const formatDate = (date: Date) => {
  return date.toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
};
---

<BaseLayout title={entry.data.title}>
  <a href="/">← Archive</a>

  <article>
    <header>
      <p class="entry-date">{formatDate(entry.data.date)}</p>
      {entry.data.mood && <p class="entry-mood">Mood: {entry.data.mood}</p>}
    </header>

    <Content />

    {entry.data.tags.length > 0 && (
      <div class="tags">
        {entry.data.tags.map(tag => (
          <a href={`/tags/${tag}`}>#{tag}</a>
        ))}
      </div>
    )}
  </article>

  <nav class="nav">
    {prevEntry ? (
      <a href={`/${prevEntry.slug}`}>← {formatDate(prevEntry.data.date)}</a>
    ) : <span></span>}
    {nextEntry ? (
      <a href={`/${nextEntry.slug}`}>{formatDate(nextEntry.data.date)} →</a>
    ) : <span></span>}
  </nav>
</BaseLayout>
```

---

## Phase 3: Journal Templates

### 3.1 Daily Template (Five Minute Journal + Stoic)

```markdown
<!-- templates/daily.md -->
---
title: "{{DATE}}"
date: {{DATE}}
mood: ""
tags: []
type: daily
---

## Morning

### I am grateful for...
1.
2.
3.

### What would make today great?
-

### Daily affirmation
I am

### What am I worried about? (Stoic premeditation)


---

## Evening

### 3 amazing things that happened today
1.
2.
3.

### How could I have made today even better?


### What did I learn today?


### What is within my control, and what is not?


---

## Daily Log

### Activities


### Highlights


### People I connected with


### How I felt


```

### 3.2 Weekly Template

```markdown
<!-- templates/weekly.md -->
---
title: "Week {{WEEK}} - {{YEAR}}"
date: {{DATE}}
tags: [weekly-review]
type: weekly
---

## Week in Review

### What went well this week?


### What didn't go well?


### What did I learn?


### What will I focus on next week?


---

## Highlights


## Gratitude

Looking back, I'm grateful for:


## Energy & Mood Patterns


## Key Accomplishments

```

### 3.3 Monthly Template

```markdown
<!-- templates/monthly.md -->
---
title: "{{MONTH}} {{YEAR}}"
date: {{DATE}}
tags: [monthly-review]
type: monthly
---

## Monthly Review

### Theme of the month


### Major accomplishments


### Challenges faced


### Lessons learned


---

## Goals Review

### What I set out to do


### What I actually did


### Adjustments for next month


---

## Memorable Moments


## People


## Books / Media / Ideas


## Health & Energy


## Looking Forward

What I'm excited about for next month:

```

---

## Phase 4: Neovim Configuration

### 4.1 Journal Module (No Plugins)

```lua
-- nvim/journal.lua
-- Neovim journaling system - no plugins required

local M = {}

-- Configuration
M.config = {
  journal_dir = vim.fn.expand("~/Coding/journal/site/src/content/journal"),
  template_dir = vim.fn.expand("~/Coding/journal/templates"),
  site_dir = vim.fn.expand("~/Coding/journal/site"),
  auto_publish = true,
}

-- Utility: Get formatted date parts
local function get_date_parts(date)
  date = date or os.date("*t")
  return {
    year = tostring(date.year),
    month = string.format("%02d", date.month),
    day = string.format("%02d", date.day),
    week = os.date("%V", os.time(date)),
    month_name = os.date("%B", os.time(date)),
    weekday = os.date("%A", os.time(date)),
    full = string.format("%04d-%02d-%02d", date.year, date.month, date.day),
  }
end

-- Utility: Ensure directory exists
local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

-- Utility: Read template file
local function read_template(template_type)
  local template_path = M.config.template_dir .. "/" .. template_type .. ".md"
  local file = io.open(template_path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

-- Utility: Replace template placeholders
local function fill_template(template, date_parts)
  local filled = template
  filled = filled:gsub("{{DATE}}", date_parts.full)
  filled = filled:gsub("{{YEAR}}", date_parts.year)
  filled = filled:gsub("{{MONTH}}", date_parts.month_name)
  filled = filled:gsub("{{WEEK}}", date_parts.week)
  filled = filled:gsub("{{WEEKDAY}}", date_parts.weekday)
  return filled
end

-- Create or open daily journal entry
function M.journal_new(args)
  local entry_type = args and args.type or "daily"
  local date_str = args and args.date

  local date
  if date_str then
    local y, m, d = date_str:match("(%d+)-(%d+)-(%d+)")
    date = { year = tonumber(y), month = tonumber(m), day = tonumber(d) }
  else
    date = os.date("*t")
  end

  local parts = get_date_parts(date)
  local filename, dir

  if entry_type == "daily" then
    dir = M.config.journal_dir .. "/" .. parts.year .. "/" .. parts.month
    filename = parts.full .. ".md"
  elseif entry_type == "weekly" then
    dir = M.config.journal_dir .. "/" .. parts.year .. "/weekly"
    filename = parts.year .. "-W" .. parts.week .. ".md"
  elseif entry_type == "monthly" then
    dir = M.config.journal_dir .. "/" .. parts.year .. "/monthly"
    filename = parts.year .. "-" .. parts.month .. ".md"
  end

  ensure_dir(dir)
  local filepath = dir .. "/" .. filename

  -- Check if file exists
  local file_exists = vim.fn.filereadable(filepath) == 1

  -- Open or create the file
  vim.cmd("edit " .. filepath)

  -- If new file, insert template
  if not file_exists then
    local template = read_template(entry_type)
    if template then
      local content = fill_template(template, parts)
      local lines = vim.split(content, "\n")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.cmd("write")
      print("Created new " .. entry_type .. " entry: " .. filename)
    end
  else
    print("Opened existing entry: " .. filename)
  end
end

-- Open previous entry
function M.journal_prev()
  local current = vim.fn.expand("%:t:r")
  local y, m, d = current:match("(%d+)-(%d+)-(%d+)")
  if not y then return end

  local time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
  local prev_time = time - (24 * 60 * 60)
  local prev_date = os.date("*t", prev_time)

  M.journal_new({ date = get_date_parts(prev_date).full })
end

-- Open next entry
function M.journal_next()
  local current = vim.fn.expand("%:t:r")
  local y, m, d = current:match("(%d+)-(%d+)-(%d+)")
  if not y then return end

  local time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
  local next_time = time + (24 * 60 * 60)
  local next_date = os.date("*t", next_time)

  M.journal_new({ date = get_date_parts(next_date).full })
end

-- Publish site
function M.publish()
  local cmd = "cd " .. M.config.site_dir .. " && npm run build"
  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 then
        print("Journal published successfully")
      else
        print("Publish failed with code: " .. code)
      end
    end,
    on_stderr = function(_, data)
      if data[1] ~= "" then
        print("Publish error: " .. table.concat(data, "\n"))
      end
    end,
  })
end

-- Setup commands and autocmds
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Commands
  vim.api.nvim_create_user_command("JournalNew", function(args)
    local entry_type = "daily"
    local date = nil

    for _, arg in ipairs(args.fargs) do
      if arg == "week" or arg == "weekly" then
        entry_type = "weekly"
      elseif arg == "month" or arg == "monthly" then
        entry_type = "monthly"
      elseif arg:match("%d+-%d+-%d+") then
        date = arg
      end
    end

    M.journal_new({ type = entry_type, date = date })
  end, { nargs = "*" })

  vim.api.nvim_create_user_command("JournalPrev", M.journal_prev, {})
  vim.api.nvim_create_user_command("JournalNext", M.journal_next, {})
  vim.api.nvim_create_user_command("JournalPublish", M.publish, {})

  -- Auto-publish on save (if enabled)
  if M.config.auto_publish then
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = M.config.journal_dir .. "/**/*.md",
      callback = function()
        M.publish()
      end,
    })
  end

  -- Keymaps (optional)
  vim.keymap.set("n", "<leader>jn", ":JournalNew<CR>", { desc = "New journal entry" })
  vim.keymap.set("n", "<leader>jw", ":JournalNew week<CR>", { desc = "Weekly review" })
  vim.keymap.set("n", "<leader>jm", ":JournalNew month<CR>", { desc = "Monthly review" })
  vim.keymap.set("n", "<leader>jp", M.journal_prev, { desc = "Previous entry" })
  vim.keymap.set("n", "<leader>jn", M.journal_next, { desc = "Next entry" })
end

return M
```

---

## Phase 5: Archive & Navigation Pages

### 5.1 Archive Index

```astro
---
// site/src/pages/index.astro
import BaseLayout from '../layouts/BaseLayout.astro';
import { getCollection } from 'astro:content';

const allEntries = await getCollection('journal', ({ data }) => !data.draft);

// Group by year and month
const grouped = allEntries.reduce((acc, entry) => {
  const date = new Date(entry.data.date);
  const year = date.getFullYear();
  const month = date.toLocaleDateString('en-US', { month: 'long' });

  if (!acc[year]) acc[year] = {};
  if (!acc[year][month]) acc[year][month] = [];
  acc[year][month].push(entry);

  return acc;
}, {} as Record<number, Record<string, typeof allEntries>>);

// Sort years descending
const years = Object.keys(grouped).map(Number).sort((a, b) => b - a);

const formatDay = (date: Date) => {
  return date.toLocaleDateString('en-US', { day: 'numeric', weekday: 'short' });
};
---

<BaseLayout title="Journal">
  <h1>Journal</h1>
  <p style="color: var(--gray-mid); margin-bottom: 2rem;">
    A record of days. Thoughts, gratitude, lessons.
  </p>

  {years.map(year => (
    <section>
      <h2 class="archive-year">{year}</h2>
      {Object.keys(grouped[year]).map(month => (
        <div>
          <h3 class="archive-month">{month}</h3>
          <ul class="archive-list">
            {grouped[year][month]
              .sort((a, b) => new Date(b.data.date).getTime() - new Date(a.data.date).getTime())
              .map(entry => (
                <li>
                  <a href={`/${entry.slug}`}>
                    <span>{formatDay(new Date(entry.data.date))}</span>
                    {entry.data.mood && <span style="color: var(--gray-light)">{entry.data.mood}</span>}
                  </a>
                </li>
              ))
            }
          </ul>
        </div>
      ))}
    </section>
  ))}
</BaseLayout>
```

### 5.2 Dynamic Entry Pages

```astro
---
// site/src/pages/[...slug].astro
import EntryLayout from '../layouts/EntryLayout.astro';
import { getCollection } from 'astro:content';

export async function getStaticPaths() {
  const entries = await getCollection('journal');
  return entries.map(entry => ({
    params: { slug: entry.slug },
    props: { entry },
  }));
}

const { entry } = Astro.props;
---

<EntryLayout entry={entry} />
```

### 5.3 Tag Pages

```astro
---
// site/src/pages/tags/[tag].astro
import BaseLayout from '../../layouts/BaseLayout.astro';
import { getCollection } from 'astro:content';

export async function getStaticPaths() {
  const entries = await getCollection('journal');
  const tags = [...new Set(entries.flatMap(e => e.data.tags))];

  return tags.map(tag => ({
    params: { tag },
    props: {
      tag,
      entries: entries.filter(e => e.data.tags.includes(tag))
        .sort((a, b) => new Date(b.data.date).getTime() - new Date(a.data.date).getTime())
    }
  }));
}

const { tag, entries } = Astro.props;
---

<BaseLayout title={`#${tag}`}>
  <a href="/">← Archive</a>
  <h1>#{tag}</h1>
  <p style="color: var(--gray-mid)">{entries.length} entries</p>

  <ul class="archive-list" style="margin-top: 2rem;">
    {entries.map(entry => (
      <li>
        <a href={`/${entry.slug}`}>
          {new Date(entry.data.date).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
          })}
        </a>
      </li>
    ))}
  </ul>
</BaseLayout>
```

---

## Phase 6: Automation Scripts

### 6.1 Publish Script

```bash
#!/bin/bash
# scripts/publish.sh

SITE_DIR="$(dirname "$0")/../site"

cd "$SITE_DIR" || exit 1

echo "Building journal site..."
npm run build

if [ $? -eq 0 ]; then
    echo "Build successful!"

    # Optional: Deploy to GitHub Pages
    # npm run deploy

    # Optional: Git commit
    # cd .. && git add . && git commit -m "Journal update $(date +%Y-%m-%d)"
else
    echo "Build failed!"
    exit 1
fi
```

---

## Acceptance Criteria

- [ ] `:JournalNew` creates daily entry with template
- [ ] `:JournalNew week` creates weekly review
- [ ] `:JournalNew month` creates monthly review
- [ ] Entries auto-publish on save
- [ ] Archive page groups by year/month
- [ ] Prev/Next navigation works
- [ ] Tags filter entries correctly
- [ ] Design is pure black/white
- [ ] Mobile responsive
- [ ] No Neovim plugins used

---

## References

- [Astro Content Collections](https://docs.astro.build/en/guides/content-collections/)
- [Five Minute Journal Format](https://www.intelligentchange.com/)
- [Daily Stoic Journal Prompts](https://dailystoic.com/journal/)
- [Plain Text Journaling](https://oppi.li/posts/plain_text_journaling/)
