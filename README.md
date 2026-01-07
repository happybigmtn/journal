# Journal

Automated Neovim journaling system with Astro static site publishing.

**Design Philosophy:** Minimalist Monochrome - austere, timeless, editorial.

## Features

- Daily/weekly/monthly journal entries via Neovim (no plugins)
- Structured prompts inspired by Five Minute Journal & Daily Stoic
- Automatic publishing to static Astro site on save
- Life replay timeline with tag-based navigation
- Black & white, typography-focused design

## Quick Start

### 1. Install dependencies

```bash
cd site && npm install
```

### 2. Add to Neovim config

Add to your `init.lua`:

```lua
-- Option A: Source directly
dofile(vim.fn.expand("~/Coding/journal/nvim/journal.lua")).setup()

-- Option B: Add to runtimepath
vim.opt.runtimepath:append("~/Coding/journal/nvim")
require("journal").setup()
```

### 3. Start journaling

```vim
:JournalNew           " Create today's entry
:JournalNew week      " Create weekly review
:JournalNew month     " Create monthly review
:JournalNew 2025-01-08  " Specific date
```

## Commands

| Command | Description |
|---------|-------------|
| `:JournalNew` | New daily entry |
| `:JournalNew week` | Weekly review |
| `:JournalNew month` | Monthly review |
| `:JournalPrev` | Previous entry |
| `:JournalNext` | Next entry |
| `:JournalPublish` | Build site |
| `:JournalList` | List all entries |

## Keymaps

| Key | Action |
|-----|--------|
| `<leader>jj` | New daily entry |
| `<leader>jw` | Weekly review |
| `<leader>jm` | Monthly review |
| `<leader>j[` | Previous entry |
| `<leader>j]` | Next entry |
| `<leader>jp` | Publish site |
| `<leader>jl` | List entries |

## Structure

```
journal/
├── site/                    # Astro static site
│   ├── src/
│   │   ├── content/journal/ # Markdown entries
│   │   ├── layouts/
│   │   ├── pages/
│   │   └── styles/
│   └── dist/                # Built site
├── nvim/
│   └── journal.lua          # Neovim configuration
├── templates/
│   ├── daily.md
│   ├── weekly.md
│   └── monthly.md
└── scripts/
    └── publish.sh
```

## Preview

```bash
cd site && npm run dev
```

Open http://localhost:4321/journal

## Deploy

### GitHub Pages

1. Enable GitHub Pages in repo settings
2. Set source to GitHub Actions
3. Add `.github/workflows/deploy.yml`

### Manual

```bash
./scripts/publish.sh
# Upload site/dist/ to your host
```

## Customization

### Templates

Edit files in `templates/` to customize prompts.

### Styling

Edit `site/src/styles/global.css`. Monochrome palette uses CSS variables:

```css
--black: #000000;
--charcoal: #1a1a1a;
--gray-dark: #333333;
--gray-mid: #666666;
--gray-light: #999999;
--white: #ffffff;
```

### Configuration

In your `init.lua`:

```lua
require("journal").setup({
  journal_dir = "~/path/to/journal/site/src/content/journal",
  template_dir = "~/path/to/journal/templates",
  site_dir = "~/path/to/journal/site",
  auto_publish = true,  -- Publish on save
})
```
