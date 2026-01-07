-- journal.lua
-- Neovim journaling system - no plugins required
-- Add to your init.lua: require('journal').setup()

local M = {}

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
      elseif arg:match("%d+-%d+-%d+") then
        date = arg
      end
    end

    M.journal_new({ type = entry_type, date = date })
  end, {
    nargs = "*",
    desc = "Create new journal entry",
    complete = function()
      return { "daily", "weekly", "monthly" }
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
    vim.keymap.set("n", "<leader>j[", M.journal_prev, { desc = "Previous entry" })
    vim.keymap.set("n", "<leader>j]", M.journal_next, { desc = "Next entry" })
    vim.keymap.set("n", "<leader>jp", M.publish, { desc = "Publish journal" })
    vim.keymap.set("n", "<leader>jl", M.journal_list, { desc = "List entries" })
  end

  vim.notify("Journal loaded. Use :JournalNew to start.", vim.log.levels.INFO)
end

return M
