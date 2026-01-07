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
local function fill_template(template, date_parts)
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
      local content = fill_template(template, parts)
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
      elseif arg:match("%d+-%d+-%d+") then
        date = arg
      end
    end

    M.journal_new({ type = entry_type, date = date })
  end, {
    nargs = "*",
    desc = "Create new journal entry",
    complete = function()
      return { "daily", "weekly", "monthly", "yearly" }
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

  -- Keymaps (disabled when using LazyVim, which handles its own keymaps)
  if M.config.keymaps then
    vim.keymap.set("n", "<leader>jj", ":JournalNew<CR>", { desc = "New journal entry (today)" })
    vim.keymap.set("n", "<leader>jw", ":JournalNew week<CR>", { desc = "Weekly review" })
    vim.keymap.set("n", "<leader>jm", ":JournalNew month<CR>", { desc = "Monthly review" })
    vim.keymap.set("n", "<leader>jy", ":JournalNew year<CR>", { desc = "Yearly review" })
    vim.keymap.set("n", "<leader>j[", M.journal_prev, { desc = "Previous entry" })
    vim.keymap.set("n", "<leader>j]", M.journal_next, { desc = "Next entry" })
    vim.keymap.set("n", "<leader>jp", M.publish, { desc = "Publish journal" })
    vim.keymap.set("n", "<leader>jl", M.journal_list, { desc = "List entries" })
    vim.keymap.set("n", "<leader>je", ":JournalExport<CR>", { desc = "Export entries" })
    vim.keymap.set("n", "<leader>jr", M.journal_random, { desc = "Random past entry" })
    vim.keymap.set("n", "<leader>js", M.show_streak, { desc = "Show streak" })
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
