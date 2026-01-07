-- journal.lua
-- Neovim journaling system - no plugins required
-- Add to your init.lua: require('journal').setup()

local M = {}

-- Load stoic prompts module (same directory as this file)
local stoic_prompts = nil
local function get_stoic_prompts()
  if stoic_prompts then
    return stoic_prompts
  end
  local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
  local prompts_path = script_dir .. "stoic_prompts.lua"
  local ok, prompts = pcall(dofile, prompts_path)
  if ok and prompts then
    stoic_prompts = prompts
    return stoic_prompts
  end
  return nil
end

-- Configuration
M.config = {
  journal_dir = vim.fn.expand("~/Coding/journal/site/src/content/journal"),
  template_dir = vim.fn.expand("~/Coding/journal/templates"),
  site_dir = vim.fn.expand("~/Coding/journal/site"),
  auto_publish = true,
  keymaps = true, -- Set to false when using with LazyVim (it handles keymaps)
}

-- Utility: Get formatted date parts
local function get_date_parts(date)
  date = date or os.date("*t")
  return {
    year = tostring(date.year),
    month = string.format("%02d", date.month),
    day = string.format("%02d", date.day),
    month_num = date.month, -- numeric for stoic prompts lookup
    day_num = date.day,     -- numeric for stoic prompts lookup
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

-- Utility: Validate date is within acceptable bounds
-- Rejects dates before 1900-01-01 or more than 1 year in the future
local function validate_date(date)
  -- Check year bounds
  if date.year < 1900 then
    return false, "Date cannot be before 1900-01-01"
  end

  -- Check if date is valid (handles leap years, month boundaries)
  local time = os.time({ year = date.year, month = date.month, day = date.day })
  if not time then
    return false, "Invalid date (check month/day values)"
  end

  -- Verify date didn't get normalized (e.g., Feb 30 -> Mar 2)
  local normalized = os.date("*t", time)
  if normalized.year ~= date.year or normalized.month ~= date.month or normalized.day ~= date.day then
    return false, string.format("Invalid date: %04d-%02d-%02d does not exist", date.year, date.month, date.day)
  end

  -- Check if more than 1 year in the future
  local now = os.time()
  local one_year_ahead = now + (365 * 24 * 60 * 60)
  if time > one_year_ahead then
    return false, "Date cannot be more than 1 year in the future"
  end

  return true, nil
end

-- Utility: Read template file
local function read_template(template_type)
  local template_path = M.config.template_dir .. "/" .. template_type .. ".md"
  local file = io.open(template_path, "r")
  if not file then
    vim.notify("Template not found: " .. template_path, vim.log.levels.ERROR)
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

-- Utility: Replace template placeholders
-- extra_vars: optional table with additional placeholders like {PROJECT_NAME = "My Project"}
local function fill_template(template, date_parts, extra_vars)
  local filled = template
  filled = filled:gsub("{{DATE}}", date_parts.full)
  filled = filled:gsub("{{YEAR}}", date_parts.year)
  filled = filled:gsub("{{MONTH}}", date_parts.month_name)
  filled = filled:gsub("{{WEEK}}", date_parts.week)
  filled = filled:gsub("{{WEEKDAY}}", date_parts.weekday)

  -- Add daily stoic prompt
  local prompts = get_stoic_prompts()
  if prompts then
    local stoic_prompt = prompts.get_prompt(date_parts.month_num, date_parts.day_num)
    local stoic_theme = prompts.get_theme(date_parts.month_num)
    filled = filled:gsub("{{STOIC_PROMPT}}", stoic_prompt)
    filled = filled:gsub("{{STOIC_THEME}}", stoic_theme)
  else
    filled = filled:gsub("{{STOIC_PROMPT}}", "What wisdom will guide me today?")
    filled = filled:gsub("{{STOIC_THEME}}", "Reflection")
  end

  -- Replace type-specific placeholders (project name, book title, destination)
  if extra_vars then
    for key, value in pairs(extra_vars) do
      filled = filled:gsub("{{" .. key .. "}}", value)
    end
  end

  return filled
end

-- Create or open daily journal entry
function M.journal_new(args)
  local entry_type = args and args.type or "daily"
  local date_str = args and args.date

  local date
  if date_str then
    local y, m, d = date_str:match("(%d+)-(%d+)-(%d+)")
    if y then
      date = { year = tonumber(y), month = tonumber(m), day = tonumber(d) }
      -- Validate date bounds
      local valid, err = validate_date(date)
      if not valid then
        vim.notify(err, vim.log.levels.ERROR)
        return
      end
    else
      vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
      return
    end
  else
    date = os.date("*t")
  end

  local parts = get_date_parts(date)
  local filename, dir
  local extra_vars = {} -- Type-specific template variables

  if entry_type == "daily" then
    dir = M.config.journal_dir .. "/" .. parts.year .. "/" .. parts.month
    filename = parts.full .. ".md"
  elseif entry_type == "weekly" then
    dir = M.config.journal_dir .. "/" .. parts.year .. "/weekly"
    filename = parts.year .. "-W" .. parts.week .. ".md"
  elseif entry_type == "monthly" then
    dir = M.config.journal_dir .. "/" .. parts.year .. "/monthly"
    filename = parts.year .. "-" .. parts.month .. ".md"
  elseif entry_type == "yearly" then
    dir = M.config.journal_dir .. "/" .. parts.year .. "/yearly"
    filename = parts.year .. ".md"
  elseif entry_type == "project" then
    -- Project entries need a name
    local project_name = args and args.name
    if not project_name then
      vim.ui.input({ prompt = "Project name: " }, function(name)
        if name and name ~= "" then
          M.journal_new({ type = "project", name = name, date = args and args.date })
        end
      end)
      return
    end
    -- Slugify name for filename
    local slug = project_name:lower():gsub("[^%w]+", "-"):gsub("^-", ""):gsub("-$", "")
    dir = M.config.journal_dir .. "/" .. parts.year .. "/projects"
    filename = slug .. ".md"
    extra_vars.PROJECT_NAME = project_name
  elseif entry_type == "book" then
    -- Book entries need a title
    local book_title = args and args.name
    if not book_title then
      vim.ui.input({ prompt = "Book title: " }, function(name)
        if name and name ~= "" then
          M.journal_new({ type = "book", name = name, date = args and args.date })
        end
      end)
      return
    end
    local slug = book_title:lower():gsub("[^%w]+", "-"):gsub("^-", ""):gsub("-$", "")
    dir = M.config.journal_dir .. "/" .. parts.year .. "/books"
    filename = slug .. ".md"
    extra_vars.BOOK_TITLE = book_title
  elseif entry_type == "travel" then
    -- Travel entries need a destination
    local destination = args and args.name
    if not destination then
      vim.ui.input({ prompt = "Destination: " }, function(name)
        if name and name ~= "" then
          M.journal_new({ type = "travel", name = name, date = args and args.date })
        end
      end)
      return
    end
    local slug = destination:lower():gsub("[^%w]+", "-"):gsub("^-", ""):gsub("-$", "")
    dir = M.config.journal_dir .. "/" .. parts.year .. "/travel"
    filename = slug .. ".md"
    extra_vars.DESTINATION = destination
  else
    vim.notify("Unknown entry type: " .. entry_type, vim.log.levels.ERROR)
    return
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
      local content = fill_template(template, parts, extra_vars)
      local lines = vim.split(content, "\n")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      vim.cmd("write")
      vim.notify("Created new " .. entry_type .. " entry: " .. filename, vim.log.levels.INFO)
    end
  else
    vim.notify("Opened existing entry: " .. filename, vim.log.levels.INFO)
  end
end

-- Open previous entry
function M.journal_prev()
  local current = vim.fn.expand("%:t:r")
  local y, m, d = current:match("(%d+)-(%d+)-(%d+)")
  if not y then
    vim.notify("Not in a dated journal entry", vim.log.levels.WARN)
    return
  end

  local time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
  local prev_time = time - (24 * 60 * 60)
  local prev_date = os.date("*t", prev_time)
  local parts = get_date_parts(prev_date)

  M.journal_new({ date = parts.full })
end

-- Open next entry
function M.journal_next()
  local current = vim.fn.expand("%:t:r")
  local y, m, d = current:match("(%d+)-(%d+)-(%d+)")
  if not y then
    vim.notify("Not in a dated journal entry", vim.log.levels.WARN)
    return
  end

  local time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
  local next_time = time + (24 * 60 * 60)
  local next_date = os.date("*t", next_time)
  local parts = get_date_parts(next_date)

  M.journal_new({ date = parts.full })
end

-- Publish site
function M.publish()
  vim.notify("Publishing journal...", vim.log.levels.INFO)

  local cmd = "cd " .. M.config.site_dir .. " && npm run build 2>&1"

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.schedule(function()
              -- Only show important lines
              if line:match("error") or line:match("Error") then
                vim.notify(line, vim.log.levels.ERROR)
              end
            end)
          end
        end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          vim.notify("Journal published successfully", vim.log.levels.INFO)
        else
          vim.notify("Publish failed with code: " .. code, vim.log.levels.ERROR)
        end
      end)
    end,
  })
end

-- Export entries to a single file
-- Supports markdown and JSON formats with optional date range
function M.journal_export(args)
  args = args or {}
  local format = args.format or "markdown"
  local start_date = args.start_date
  local end_date = args.end_date
  local output_path = args.output

  -- Parse date range if provided
  local start_time, end_time
  if start_date then
    local y, m, d = start_date:match("(%d+)-(%d+)-(%d+)")
    if y then
      start_time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
    end
  end
  if end_date then
    local y, m, d = end_date:match("(%d+)-(%d+)-(%d+)")
    if y then
      end_time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 23, min = 59, sec = 59 })
    end
  end

  -- Collect all entries
  local entries = {}
  local pattern = M.config.journal_dir .. "/**/*.md"
  local files = vim.fn.glob(pattern, false, true)

  for _, filepath in ipairs(files) do
    local name = vim.fn.fnamemodify(filepath, ":t:r")
    -- Only include dated daily entries
    local y, m, d = name:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if y then
      local entry_time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })

      -- Apply date range filter
      local in_range = true
      if start_time and entry_time < start_time then
        in_range = false
      end
      if end_time and entry_time > end_time then
        in_range = false
      end

      if in_range then
        -- Read file content
        local file = io.open(filepath, "r")
        if file then
          local content = file:read("*all")
          file:close()

          -- Parse frontmatter
          local frontmatter = {}
          local body = content
          local fm_start, fm_end = content:find("^%-%-%-\n")
          if fm_start then
            local _, fm_close = content:find("\n%-%-%-\n", fm_end)
            if fm_close then
              local fm_text = content:sub(fm_end + 1, fm_close - 4)
              body = content:sub(fm_close + 1)
              -- Simple YAML parsing for common fields
              for line in fm_text:gmatch("[^\n]+") do
                local key, value = line:match("^(%w+):%s*(.+)$")
                if key and value then
                  -- Remove quotes if present
                  value = value:gsub("^[\"'](.+)[\"']$", "%1")
                  frontmatter[key] = value
                end
              end
            end
          end

          table.insert(entries, {
            date = name,
            filepath = filepath,
            frontmatter = frontmatter,
            content = body,
          })
        end
      end
    end
  end

  -- Sort by date ascending
  table.sort(entries, function(a, b)
    return a.date < b.date
  end)

  if #entries == 0 then
    vim.notify("No entries found in specified date range", vim.log.levels.WARN)
    return
  end

  -- Generate output
  local output
  if format == "json" then
    -- Build JSON manually (Lua doesn't have native JSON)
    local json_entries = {}
    for _, entry in ipairs(entries) do
      local meta_parts = {}
      for key, value in pairs(entry.frontmatter) do
        -- Escape special characters in JSON strings
        local escaped = value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
        table.insert(meta_parts, string.format('"%s": "%s"', key, escaped))
      end
      local body_escaped = entry.content:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\t', '\\t')
      local json_entry = string.format(
        '    {\n      "date": "%s",\n      "metadata": {%s},\n      "content": "%s"\n    }',
        entry.date,
        table.concat(meta_parts, ", "),
        body_escaped
      )
      table.insert(json_entries, json_entry)
    end
    output = "{\n  \"entries\": [\n" .. table.concat(json_entries, ",\n") .. "\n  ]\n}"
  else
    -- Markdown format: concatenate with section headers
    local md_parts = {}
    table.insert(md_parts, "# Journal Export")
    table.insert(md_parts, "")
    if start_date or end_date then
      table.insert(md_parts, string.format("Date range: %s to %s", start_date or "beginning", end_date or "present"))
      table.insert(md_parts, "")
    end
    table.insert(md_parts, string.format("Total entries: %d", #entries))
    table.insert(md_parts, "")
    table.insert(md_parts, "---")
    table.insert(md_parts, "")

    for _, entry in ipairs(entries) do
      table.insert(md_parts, "## " .. entry.date)
      if entry.frontmatter.mood then
        table.insert(md_parts, "*Mood: " .. entry.frontmatter.mood .. "*")
      end
      table.insert(md_parts, "")
      table.insert(md_parts, entry.content)
      table.insert(md_parts, "")
      table.insert(md_parts, "---")
      table.insert(md_parts, "")
    end
    output = table.concat(md_parts, "\n")
  end

  -- Determine output path
  if not output_path then
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local ext = format == "json" and "json" or "md"
    output_path = vim.fn.expand("~/journal_export_" .. timestamp .. "." .. ext)
  end

  -- Write output file
  local file = io.open(output_path, "w")
  if file then
    file:write(output)
    file:close()
    vim.notify(string.format("Exported %d entries to %s", #entries, output_path), vim.log.levels.INFO)
    -- Open the exported file
    vim.cmd("edit " .. output_path)
  else
    vim.notify("Failed to write export file: " .. output_path, vim.log.levels.ERROR)
  end
end

-- Calculate journaling streak
-- Returns current streak and longest streak
function M.calculate_streak()
  -- Get all dated entries
  local dates = {}
  local pattern = M.config.journal_dir .. "/**/*.md"
  local files = vim.fn.glob(pattern, false, true)

  for _, filepath in ipairs(files) do
    local name = vim.fn.fnamemodify(filepath, ":t:r")
    local y, m, d = name:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if y then
      local entry_time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
      table.insert(dates, entry_time)
    end
  end

  if #dates == 0 then
    return 0, 0
  end

  -- Sort dates ascending
  table.sort(dates)

  -- Calculate longest streak
  local longest_streak = 1
  local current_run = 1
  local one_day = 24 * 60 * 60

  for i = 2, #dates do
    local diff = dates[i] - dates[i - 1]
    -- Allow for some tolerance around one day (DST, etc)
    if diff >= (one_day - 3600) and diff <= (one_day + 3600) then
      current_run = current_run + 1
      if current_run > longest_streak then
        longest_streak = current_run
      end
    else
      current_run = 1
    end
  end

  -- Calculate current streak (counting back from today/yesterday)
  local now = os.time()
  local today = os.date("*t", now)
  local today_noon = os.time({ year = today.year, month = today.month, day = today.day, hour = 12 })
  local yesterday_noon = today_noon - one_day

  -- Check if today or yesterday has an entry
  local current_streak = 0
  local check_time = today_noon

  -- First check today
  local found_today = false
  for _, date_time in ipairs(dates) do
    local diff = math.abs(date_time - today_noon)
    if diff < (12 * 60 * 60) then
      found_today = true
      break
    end
  end

  -- If no entry today, start counting from yesterday
  if not found_today then
    check_time = yesterday_noon
  end

  -- Count consecutive days going backwards
  while true do
    local found = false
    for _, date_time in ipairs(dates) do
      local diff = math.abs(date_time - check_time)
      if diff < (12 * 60 * 60) then
        found = true
        current_streak = current_streak + 1
        break
      end
    end
    if not found then
      break
    end
    check_time = check_time - one_day
  end

  return current_streak, longest_streak
end

-- Display streak information
function M.show_streak()
  local current, longest = M.calculate_streak()
  local msg = string.format("Streak: %d day%s (longest: %d)", current, current == 1 and "" or "s", longest)
  vim.notify(msg, vim.log.levels.INFO)
end

-- Open a random past entry (skips current week)
function M.journal_random()
  -- Get all dated entries
  local entries = {}
  local pattern = M.config.journal_dir .. "/**/*.md"
  local files = vim.fn.glob(pattern, false, true)

  -- Calculate start of current week (Sunday)
  local now = os.time()
  local today = os.date("*t", now)
  local days_since_sunday = today.wday - 1 -- wday is 1=Sunday
  local week_start = now - (days_since_sunday * 24 * 60 * 60)
  -- Normalize to midnight
  local week_start_date = os.date("*t", week_start)
  week_start = os.time({ year = week_start_date.year, month = week_start_date.month, day = week_start_date.day, hour = 0, min = 0, sec = 0 })

  for _, filepath in ipairs(files) do
    local name = vim.fn.fnamemodify(filepath, ":t:r")
    local y, m, d = name:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if y then
      local entry_time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
      -- Skip entries from current week
      if entry_time < week_start then
        table.insert(entries, { name = name, path = filepath, time = entry_time })
      end
    end
  end

  if #entries == 0 then
    vim.notify("No past entries found (only current week exists)", vim.log.levels.WARN)
    return
  end

  -- Pick a random entry
  math.randomseed(os.time())
  local random_entry = entries[math.random(#entries)]

  -- Open the entry
  vim.cmd("edit " .. random_entry.path)

  -- Show notification with date info
  local entry_date = os.date("*t", random_entry.time)
  local days_ago = math.floor((now - random_entry.time) / (24 * 60 * 60))
  local weekday = os.date("%A", random_entry.time)

  local time_desc
  if days_ago < 30 then
    time_desc = days_ago .. " days ago"
  elseif days_ago < 365 then
    local months = math.floor(days_ago / 30)
    time_desc = months .. (months == 1 and " month" or " months") .. " ago"
  else
    local years = math.floor(days_ago / 365)
    time_desc = years .. (years == 1 and " year" or " years") .. " ago"
  end

  vim.notify(
    string.format("Random entry: %s (%s, %s)", random_entry.name, weekday, time_desc),
    vim.log.levels.INFO
  )
end

-- Insert image markdown at cursor
-- Creates assets directory and inserts markdown image syntax
function M.insert_image()
  -- Get current date from file or today
  local date = os.date("*t")
  local current_file = vim.fn.expand("%:t:r")
  if current_file:match("^%d%d%d%d%-%d%d%-%d%d$") then
    local y, m, d = current_file:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
    date = { year = tonumber(y), month = tonumber(m), day = tonumber(d) }
  end

  -- Construct assets path
  local assets_dir = string.format(
    "%s/site/public/journal/assets/%04d/%02d",
    M.config.journal_dir:gsub("/site/src/content/journal$", ""),
    date.year,
    date.month
  )

  -- Ensure assets directory exists
  vim.fn.mkdir(assets_dir, "p")

  -- Prompt for image filename
  vim.ui.input({ prompt = "Image filename (e.g., morning-coffee.jpg): " }, function(filename)
    if not filename or filename == "" then
      return
    end

    -- Construct relative path from journal entry to public assets
    local image_path = string.format("/journal/assets/%04d/%02d/%s", date.year, date.month, filename)
    local alt_text = filename:gsub("%.[^.]+$", ""):gsub("[-_]", " ")

    -- Insert markdown at cursor
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local before = line:sub(1, col)
    local after = line:sub(col + 1)
    local markdown = string.format("![%s](%s)", alt_text, image_path)

    vim.api.nvim_set_current_line(before .. markdown .. after)
    vim.api.nvim_win_set_cursor(0, { row, col + #markdown })

    vim.notify(
      string.format("Image inserted. Place file at:\n%s/%s", assets_dir, filename),
      vim.log.levels.INFO
    )
  end)
end

-- Toggle published status in current entry's frontmatter
function M.toggle_published()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Find frontmatter bounds
  local start_line, end_line
  for i, line in ipairs(lines) do
    if line == "---" then
      if not start_line then
        start_line = i
      else
        end_line = i
        break
      end
    end
  end

  if not start_line or not end_line then
    vim.notify("No frontmatter found in file", vim.log.levels.ERROR)
    return
  end

  -- Look for published: line
  local published_line = nil
  local current_value = false
  for i = start_line + 1, end_line - 1 do
    local line = lines[i]
    if line:match("^published:") then
      published_line = i
      current_value = line:match("true") ~= nil
      break
    end
  end

  local new_value = not current_value

  if published_line then
    -- Update existing line
    lines[published_line] = "published: " .. tostring(new_value)
  else
    -- Insert new line before closing ---
    table.insert(lines, end_line, "published: " .. tostring(new_value))
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local status = new_value and "PUBLISHED" or "PRIVATE"
  vim.notify("Entry marked as " .. status, vim.log.levels.INFO)
end

-- Copy shareable link for current entry to clipboard
function M.share_entry()
  local current_file = vim.fn.expand("%:t:r")
  local y, m, d = current_file:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")

  if not y then
    vim.notify("Not in a dated journal entry", vim.log.levels.WARN)
    return
  end

  -- Construct the public URL
  local site_url = "https://rizz.dad"
  local slug = string.format("%s/%s/%s-%s-%s", y, m, y, m, d)
  local share_url = site_url .. "/" .. slug

  -- Copy to system clipboard
  vim.fn.setreg("+", share_url)
  vim.fn.setreg("*", share_url)

  vim.notify("Copied to clipboard: " .. share_url, vim.log.levels.INFO)
end

-- Import entries from Day One or Journey
-- format: "dayone" or "journey"
-- input_path: path to export directory
function M.import_entries(format, input_path)
  if not format or not input_path then
    vim.notify("Usage: :JournalImport <format> <path>", vim.log.levels.ERROR)
    return
  end

  format = format:lower()
  if format ~= "dayone" and format ~= "journey" then
    vim.notify("Format must be 'dayone' or 'journey'", vim.log.levels.ERROR)
    return
  end

  -- Expand path
  input_path = vim.fn.expand(input_path)

  -- Check path exists
  if vim.fn.isdirectory(input_path) == 0 and vim.fn.filereadable(input_path) == 0 then
    vim.notify("Path does not exist: " .. input_path, vim.log.levels.ERROR)
    return
  end

  vim.notify("Importing from " .. format .. "...", vim.log.levels.INFO)

  -- Get script path
  local script_dir = M.config.journal_dir:gsub("/site/src/content/journal$", "")
  local import_script = script_dir .. "/scripts/import_journal.lua"

  -- Run import script
  local cmd = string.format(
    'lua "%s" %s "%s" "%s" 2>&1',
    import_script,
    format,
    input_path,
    M.config.journal_dir
  )

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.schedule(function()
              -- Show results
              if line:match("^Imported:") or line:match("^Results:") or line:match("^Done!") then
                vim.notify(line, vim.log.levels.INFO)
              elseif line:match("^Error:") or line:match("error") then
                vim.notify(line, vim.log.levels.ERROR)
              end
            end)
          end
        end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          vim.notify("Import complete! Run :JournalPublish to rebuild site.", vim.log.levels.INFO)
        else
          vim.notify("Import failed. Check the output for errors.", vim.log.levels.ERROR)
        end
      end)
    end,
  })
end

-- Backup journal to local or cloud storage
-- target: "local", "s3", "b2" etc.
-- encrypt: boolean to enable GPG encryption
function M.backup(target, encrypt)
  target = target or "local_backup"
  local encrypt_flag = encrypt and "--encrypt" or ""

  vim.notify("Starting journal backup...", vim.log.levels.INFO)

  -- Get script path
  local script_dir = M.config.journal_dir:gsub("/site/src/content/journal$", "")
  local backup_script = script_dir .. "/scripts/backup_journal.lua"

  -- Check if script exists
  if vim.fn.filereadable(backup_script) == 0 then
    vim.notify("Backup script not found: " .. backup_script, vim.log.levels.ERROR)
    return
  end

  -- Run backup script
  local cmd = string.format('lua "%s" backup --target %s %s 2>&1', backup_script, target, encrypt_flag)

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.schedule(function()
              -- Show important status lines
              if line:match("^===") or line:match("^%[%d") or line:match("Complete") then
                vim.notify(line, vim.log.levels.INFO)
              elseif line:match("^ERROR") then
                vim.notify(line, vim.log.levels.ERROR)
              end
            end)
          end
        end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          vim.notify("Backup completed successfully", vim.log.levels.INFO)
        else
          vim.notify("Backup failed with code: " .. code, vim.log.levels.ERROR)
        end
      end)
    end,
  })
end

-- List existing backups
function M.list_backups()
  local script_dir = M.config.journal_dir:gsub("/site/src/content/journal$", "")
  local backup_script = script_dir .. "/scripts/backup_journal.lua"

  if vim.fn.filereadable(backup_script) == 0 then
    vim.notify("Backup script not found", vim.log.levels.ERROR)
    return
  end

  local cmd = string.format('lua "%s" list 2>&1', backup_script)

  -- Run synchronously and show in quickfix
  local output = vim.fn.system(cmd)
  local lines = vim.split(output, "\n")

  -- Display in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(100, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "single",
    title = " Journal Backups ",
    title_pos = "center",
  })

  -- Set up keymaps to close
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
end

-- Quick entry mode for micro-journaling
-- Appends to today's entry or creates minimal one if it doesn't exist
function M.quick_entry()
  local date = os.date("*t")
  local parts = get_date_parts(date)
  local dir = M.config.journal_dir .. "/" .. parts.year .. "/" .. parts.month
  local filepath = dir .. "/" .. parts.full .. ".md"
  local file_exists = vim.fn.filereadable(filepath) == 1

  ensure_dir(dir)

  -- Prompt for the quick note
  vim.ui.input({ prompt = "Quick note: " }, function(note)
    if not note or note == "" then
      return
    end

    -- Get current time for timestamp
    local timestamp = os.date("%H:%M")

    if file_exists then
      -- Append to existing entry
      local file = io.open(filepath, "a")
      if file then
        file:write("\n\n**" .. timestamp .. "** — " .. note)
        file:close()
        vim.notify("Added quick note to " .. parts.full, vim.log.levels.INFO)

        -- If the file is already open, reload it
        local bufnr = vim.fn.bufnr(filepath)
        if bufnr ~= -1 then
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("edit!")
          end)
        end
      else
        vim.notify("Failed to write to entry", vim.log.levels.ERROR)
      end
    else
      -- Create minimal new entry with the quick note
      local minimal_frontmatter = {
        "---",
        "title: " .. '"' .. parts.full .. '"',
        "date: " .. parts.full,
        "type: daily",
        "tags: []",
        "draft: false",
        "published: false",
        "---",
        "",
        "## Quick Notes",
        "",
        "**" .. timestamp .. "** — " .. note,
        ""
      }

      local file = io.open(filepath, "w")
      if file then
        file:write(table.concat(minimal_frontmatter, "\n"))
        file:close()
        vim.notify("Created quick entry: " .. parts.full, vim.log.levels.INFO)
      else
        vim.notify("Failed to create entry", vim.log.levels.ERROR)
      end
    end
  end)
end

-- List recent entries
function M.journal_list()
  local entries = {}
  local pattern = M.config.journal_dir .. "/**/*.md"
  local files = vim.fn.glob(pattern, false, true)

  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    if name:match("^%d%d%d%d%-%d%d%-%d%d$") then
      table.insert(entries, { name = name, path = file })
    end
  end

  -- Sort by date descending
  table.sort(entries, function(a, b)
    return a.name > b.name
  end)

  -- Show in quickfix
  local qf_list = {}
  for _, entry in ipairs(entries) do
    table.insert(qf_list, {
      filename = entry.path,
      text = entry.name,
    })
  end

  vim.fn.setqflist(qf_list)
  vim.cmd("copen")
end

-- Setup commands and autocmds
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Ensure directories exist
  ensure_dir(M.config.journal_dir)
  ensure_dir(M.config.template_dir)

  -- Commands
  vim.api.nvim_create_user_command("JournalNew", function(args)
    local entry_type = "daily"
    local date = nil

    for _, arg in ipairs(args.fargs) do
      if arg == "week" or arg == "weekly" then
        entry_type = "weekly"
      elseif arg == "month" or arg == "monthly" then
        entry_type = "monthly"
      elseif arg == "year" or arg == "yearly" then
        entry_type = "yearly"
      elseif arg == "project" then
        entry_type = "project"
      elseif arg == "book" then
        entry_type = "book"
      elseif arg == "travel" then
        entry_type = "travel"
      elseif arg:match("%d+-%d+-%d+") then
        date = arg
      end
    end

    M.journal_new({ type = entry_type, date = date })
  end, {
    nargs = "*",
    desc = "Create new journal entry",
    complete = function()
      return { "daily", "weekly", "monthly", "yearly", "project", "book", "travel" }
    end,
  })

  vim.api.nvim_create_user_command("JournalPrev", M.journal_prev, {
    desc = "Open previous journal entry",
  })

  vim.api.nvim_create_user_command("JournalNext", M.journal_next, {
    desc = "Open next journal entry",
  })

  vim.api.nvim_create_user_command("JournalPublish", M.publish, {
    desc = "Publish journal site",
  })

  vim.api.nvim_create_user_command("JournalList", M.journal_list, {
    desc = "List journal entries",
  })

  vim.api.nvim_create_user_command("JournalRandom", M.journal_random, {
    desc = "Open random past journal entry",
  })

  vim.api.nvim_create_user_command("JournalStreak", M.show_streak, {
    desc = "Show journaling streak",
  })

  vim.api.nvim_create_user_command("JournalExport", function(args)
    local export_args = {}

    -- Parse arguments: [start_date] [end_date] [format]
    for _, arg in ipairs(args.fargs) do
      if arg == "json" or arg == "markdown" or arg == "md" then
        export_args.format = arg == "md" and "markdown" or arg
      elseif arg:match("^%d%d%d%d%-%d%d%-%d%d$") then
        if not export_args.start_date then
          export_args.start_date = arg
        else
          export_args.end_date = arg
        end
      end
    end

    M.journal_export(export_args)
  end, {
    nargs = "*",
    desc = "Export journal entries (args: [start_date] [end_date] [json|markdown])",
    complete = function()
      return { "json", "markdown", os.date("%Y-%m-%d") }
    end,
  })

  -- Auto-publish on save (if enabled)
  if M.config.auto_publish then
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = M.config.journal_dir .. "/**/*.md",
      callback = function()
        M.publish()
      end,
      desc = "Auto-publish journal on save",
    })
  end

  -- Image insertion command
  vim.api.nvim_create_user_command("JournalImage", function()
    M.insert_image()
  end, { desc = "Insert image markdown" })

  -- Publish toggle command (note: this overrides the earlier JournalPublish for site building)
  vim.api.nvim_create_user_command("JournalPublish", function()
    M.toggle_published()
  end, { desc = "Toggle entry published status" })

  -- Share command
  vim.api.nvim_create_user_command("JournalShare", function()
    M.share_entry()
  end, { desc = "Copy shareable link to clipboard" })

  -- Quick entry command
  vim.api.nvim_create_user_command("JournalQuick", function()
    M.quick_entry()
  end, { desc = "Add quick note to today's entry" })

  -- Import command
  vim.api.nvim_create_user_command("JournalImport", function(args)
    if #args.fargs < 2 then
      vim.notify("Usage: :JournalImport <format> <path>", vim.log.levels.ERROR)
      vim.notify("Formats: dayone, journey", vim.log.levels.INFO)
      return
    end
    M.import_entries(args.fargs[1], args.fargs[2])
  end, {
    nargs = "+",
    desc = "Import entries from Day One or Journey",
    complete = function(_, line)
      local args = vim.split(line, "%s+")
      if #args == 2 then
        return { "dayone", "journey" }
      elseif #args == 3 then
        return vim.fn.getcompletion(args[3], "dir")
      end
      return {}
    end,
  })

  -- Backup command
  vim.api.nvim_create_user_command("JournalBackup", function(args)
    local target = "local_backup"
    local encrypt = false

    for _, arg in ipairs(args.fargs) do
      if arg == "--encrypt" or arg == "-e" then
        encrypt = true
      elseif arg:match("^[%w_]+$") then
        target = arg
      end
    end

    M.backup(target, encrypt)
  end, {
    nargs = "*",
    desc = "Backup journal entries (args: [target] [--encrypt])",
    complete = function()
      return { "local_backup", "s3", "b2", "--encrypt" }
    end,
  })

  -- List backups command
  vim.api.nvim_create_user_command("JournalBackupList", function()
    M.list_backups()
  end, { desc = "List existing journal backups" })

  -- Wrapped/Year summary command
  vim.api.nvim_create_user_command("JournalWrapped", function(args)
    local year = args.fargs[1] or tostring(os.date("*t").year)
    local site_dir = M.config.site_dir
    local url = "http://localhost:4321/wrapped/" .. year

    -- Open in browser (try multiple commands)
    local open_cmd
    if vim.fn.executable("xdg-open") == 1 then
      open_cmd = "xdg-open"
    elseif vim.fn.executable("open") == 1 then
      open_cmd = "open"
    else
      vim.notify("Could not find browser opener. Visit: " .. url, vim.log.levels.INFO)
      return
    end

    vim.fn.jobstart(open_cmd .. " " .. url, { detach = true })
    vim.notify("Opening " .. year .. " Wrapped in browser", vim.log.levels.INFO)
  end, {
    nargs = "?",
    desc = "View yearly journal wrapped/summary",
    complete = function()
      local years = {}
      local current_year = os.date("*t").year
      for y = current_year, current_year - 5, -1 do
        table.insert(years, tostring(y))
      end
      return years
    end,
  })

  -- Keymaps (disabled when using LazyVim, which handles its own keymaps)
  if M.config.keymaps then
    vim.keymap.set("n", "<leader>jj", ":JournalNew<CR>", { desc = "New journal entry (today)" })
    vim.keymap.set("n", "<leader>jw", ":JournalNew week<CR>", { desc = "Weekly review" })
    vim.keymap.set("n", "<leader>jm", ":JournalNew month<CR>", { desc = "Monthly review" })
    vim.keymap.set("n", "<leader>jy", ":JournalNew year<CR>", { desc = "Yearly review" })
    vim.keymap.set("n", "<leader>jnp", ":JournalNew project<CR>", { desc = "New project log" })
    vim.keymap.set("n", "<leader>jnb", ":JournalNew book<CR>", { desc = "New book notes" })
    vim.keymap.set("n", "<leader>jnt", ":JournalNew travel<CR>", { desc = "New travel journal" })
    vim.keymap.set("n", "<leader>j[", M.journal_prev, { desc = "Previous entry" })
    vim.keymap.set("n", "<leader>j]", M.journal_next, { desc = "Next entry" })
    vim.keymap.set("n", "<leader>jp", M.publish, { desc = "Publish journal" })
    vim.keymap.set("n", "<leader>jl", M.journal_list, { desc = "List entries" })
    vim.keymap.set("n", "<leader>je", ":JournalExport<CR>", { desc = "Export entries" })
    vim.keymap.set("n", "<leader>jr", M.journal_random, { desc = "Random past entry" })
    vim.keymap.set("n", "<leader>js", M.show_streak, { desc = "Show streak" })
    vim.keymap.set("n", "<leader>ji", M.insert_image, { desc = "Insert image" })
    vim.keymap.set("n", "<leader>jP", M.toggle_published, { desc = "Toggle published status" })
    vim.keymap.set("n", "<leader>jS", M.share_entry, { desc = "Copy share link" })
    vim.keymap.set("n", "<leader>jq", M.quick_entry, { desc = "Quick note" })
    vim.keymap.set("n", "<leader>jB", function() M.backup() end, { desc = "Backup journal" })
  end

  -- Show streak in startup notification
  local current_streak, longest_streak = M.calculate_streak()
  local streak_info = ""
  if current_streak > 0 then
    streak_info = string.format(" | Streak: %d day%s", current_streak, current_streak == 1 and "" or "s")
  end
  vim.notify("Journal loaded. Use :JournalNew to start." .. streak_info, vim.log.levels.INFO)
end

return M
