# Ralph Agent Instructions

## Your Task

1. Read `scripts/ralph/prd.json`
2. Read `scripts/ralph/progress.txt`
   (check Codebase Patterns first)
3. Check you're on the correct branch
4. Pick highest priority story
   where `passes: false`
5. Implement that ONE story
6. Run build to verify: `cd site && npm run build`
7. Commit: `feat: [ID] - [Title]`
8. Update prd.json: `passes: true`
9. Append learnings to progress.txt

## Progress Format

APPEND to progress.txt:

## [Date] - [Story ID]

- What was implemented
- Files changed
- **Learnings:**
  - Patterns discovered
  - Gotchas encountered

---

## Codebase Patterns

Add reusable patterns to the TOP
of progress.txt:

## Codebase Patterns

- Astro pages: Use getCollection('journal') for entries
- Lua dates: os.date("*t") returns table, os.time() for unix
- CSS: Use custom properties from :root for consistency
- Templates: Use {{PLACEHOLDER}} for date substitution

## Project Structure

- `site/` - Astro static site
- `nvim/journal.lua` - Neovim configuration
- `templates/` - Markdown templates (daily, weekly, monthly)
- `scripts/` - Build and deployment scripts

## Key Files

- `site/src/content/config.ts` - Zod schema for frontmatter
- `site/src/styles/global.css` - Monochrome design system
- `nvim/journal.lua` - All Neovim commands and keymaps

## Stop Condition

If ALL stories pass, reply:
<promise>COMPLETE</promise>

Otherwise end normally.
