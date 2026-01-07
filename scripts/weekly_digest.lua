#!/usr/bin/env lua
-- weekly_digest.lua
-- Generates weekly digest HTML for journal entries
-- Can be sent via email using external services (SendGrid, Postmark, etc.)
-- Usage: lua weekly_digest.lua [--send] [--to email@example.com]

local M = {}

-- Configuration
M.config = {
  journal_dir = os.getenv("HOME") .. "/Coding/journal/site/src/content/journal",
  output_dir = os.getenv("HOME") .. "/.journal-digests",
  site_url = "https://rizz.dad",
  from_email = "digest@rizz.dad",
  from_name = "Journal Digest",
  -- Email service config (set via environment variables)
  email_service = os.getenv("JOURNAL_EMAIL_SERVICE") or "none", -- sendgrid, postmark, none
  sendgrid_api_key = os.getenv("SENDGRID_API_KEY"),
  postmark_api_key = os.getenv("POSTMARK_API_KEY"),
}

-- Utility: Read file contents
local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

-- Utility: Write file contents
local function write_file(path, content)
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

-- Utility: Ensure directory exists
local function ensure_dir(path)
  os.execute('mkdir -p "' .. path .. '"')
end

-- Utility: Get week boundaries (Monday to Sunday)
local function get_week_range(weeks_ago)
  weeks_ago = weeks_ago or 0
  local now = os.time()
  local today = os.date("*t", now)

  -- Find last Monday (or today if Monday)
  local current_wday = today.wday -- 1=Sunday, 2=Monday, ...
  local days_since_monday = (current_wday - 2) % 7

  -- Calculate week start (Monday) and end (Sunday)
  local week_start = now - (days_since_monday + (weeks_ago * 7)) * 86400
  local week_end = week_start + (6 * 86400) -- Sunday

  return os.date("*t", week_start), os.date("*t", week_end)
end

-- Utility: Format date as YYYY-MM-DD
local function format_date(date)
  return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

-- Utility: Parse frontmatter from markdown
local function parse_frontmatter(content)
  local frontmatter = {}
  local in_frontmatter = false
  local lines = {}

  for line in content:gmatch("[^\n]+") do
    if line == "---" then
      if in_frontmatter then
        break
      else
        in_frontmatter = true
      end
    elseif in_frontmatter then
      local key, value = line:match("^(%w+):%s*(.*)$")
      if key then
        -- Clean up value (remove quotes)
        value = value:gsub('^"', ""):gsub('"$', ""):gsub("^'", ""):gsub("'$", "")
        frontmatter[key] = value
      end
    end
    table.insert(lines, line)
  end

  return frontmatter
end

-- Utility: Get mood score from emoji
local function get_mood_score(mood)
  local scores = {
    ["😊"] = 5, ["🥰"] = 5, ["😄"] = 5, ["🤩"] = 5, ["😎"] = 5,
    ["🙂"] = 4, ["😌"] = 4, ["🤗"] = 4, ["😏"] = 4,
    ["😐"] = 3, ["🤔"] = 3, ["😑"] = 3,
    ["😕"] = 2, ["😢"] = 2, ["😔"] = 2, ["😟"] = 2, ["🫤"] = 2,
    ["😞"] = 1, ["😭"] = 1, ["😤"] = 1, ["😠"] = 1, ["😩"] = 1,
  }
  return scores[mood]
end

-- Collect entries for a date range
local function collect_entries(start_date, end_date)
  local entries = {}
  local start_time = os.time({ year = start_date.year, month = start_date.month, day = start_date.day })
  local end_time = os.time({ year = end_date.year, month = end_date.month, day = end_date.day })

  -- Scan journal directory
  local function scan_dir(dir)
    local handle = io.popen('find "' .. dir .. '" -name "*.md" -type f 2>/dev/null')
    if not handle then return end

    for path in handle:lines() do
      local content = read_file(path)
      if content then
        local fm = parse_frontmatter(content)
        if fm.date and fm.type == "daily" then
          local y, m, d = fm.date:match("(%d+)-(%d+)-(%d+)")
          if y then
            local entry_time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
            if entry_time >= start_time and entry_time <= end_time then
              table.insert(entries, {
                date = fm.date,
                title = fm.title or fm.date,
                mood = fm.mood,
                mood_score = get_mood_score(fm.mood),
                content = content,
                path = path,
              })
            end
          end
        end
      end
    end
    handle:close()
  end

  scan_dir(M.config.journal_dir)

  -- Sort by date
  table.sort(entries, function(a, b) return a.date < b.date end)

  return entries
end

-- Find "on this week in history" entries
local function find_historical_entries(start_date, end_date)
  local historical = {}
  local current_year = start_date.year

  -- Check previous years
  local function scan_year(year)
    local year_dir = M.config.journal_dir .. "/" .. year
    local handle = io.popen('find "' .. year_dir .. '" -name "*.md" -type f 2>/dev/null')
    if not handle then return end

    for path in handle:lines() do
      local content = read_file(path)
      if content then
        local fm = parse_frontmatter(content)
        if fm.date and fm.type == "daily" then
          local y, m, d = fm.date:match("(%d+)-(%d+)-(%d+)")
          if y and tonumber(y) ~= current_year then
            -- Check if month-day falls within current week
            local entry_month, entry_day = tonumber(m), tonumber(d)
            local start_month, start_day = start_date.month, start_date.day
            local end_month, end_day = end_date.month, end_date.day

            local in_range = false
            if start_month == end_month then
              in_range = entry_month == start_month and entry_day >= start_day and entry_day <= end_day
            else
              -- Week spans month boundary
              in_range = (entry_month == start_month and entry_day >= start_day) or
                (entry_month == end_month and entry_day <= end_day)
            end

            if in_range then
              table.insert(historical, {
                date = fm.date,
                title = fm.title or fm.date,
                mood = fm.mood,
                years_ago = current_year - tonumber(y),
              })
            end
          end
        end
      end
    end
    handle:close()
  end

  -- Scan all previous years
  local handle = io.popen('ls -d "' .. M.config.journal_dir .. '"/[0-9]* 2>/dev/null')
  if handle then
    for year_path in handle:lines() do
      local year = year_path:match("(%d+)$")
      if year and tonumber(year) < current_year then
        scan_year(year)
      end
    end
    handle:close()
  end

  -- Sort by date descending
  table.sort(historical, function(a, b) return a.date > b.date end)

  return historical
end

-- Calculate journaling streak
local function calculate_streak()
  local now = os.time()
  local streak = 0
  local check_date = now

  while true do
    local d = os.date("*t", check_date)
    local date_str = format_date(d)
    local path = M.config.journal_dir .. "/" .. d.year .. "/" .. string.format("%02d", d.month) .. "/" .. date_str .. ".md"

    local file = io.open(path, "r")
    if file then
      file:close()
      streak = streak + 1
      check_date = check_date - 86400
    else
      -- Allow streak to start from yesterday
      if streak == 0 then
        check_date = check_date - 86400
        d = os.date("*t", check_date)
        date_str = format_date(d)
        path = M.config.journal_dir .. "/" .. d.year .. "/" .. string.format("%02d", d.month) .. "/" .. date_str .. ".md"
        file = io.open(path, "r")
        if file then
          file:close()
          streak = 1
          check_date = check_date - 86400
        else
          break
        end
      else
        break
      end
    end
  end

  return streak
end

-- Generate HTML digest
function M.generate_digest(weeks_ago)
  weeks_ago = weeks_ago or 1 -- Default to last week
  local start_date, end_date = get_week_range(weeks_ago)
  local entries = collect_entries(start_date, end_date)
  local historical = find_historical_entries(start_date, end_date)
  local streak = calculate_streak()

  -- Calculate mood average
  local mood_sum, mood_count = 0, 0
  for _, entry in ipairs(entries) do
    if entry.mood_score then
      mood_sum = mood_sum + entry.mood_score
      mood_count = mood_count + 1
    end
  end
  local mood_avg = mood_count > 0 and (mood_sum / mood_count) or nil
  local mood_avg_str = mood_avg and string.format("%.1f", mood_avg) or "N/A"

  -- Mood description
  local mood_desc = "No mood data"
  if mood_avg then
    if mood_avg >= 4.5 then mood_desc = "Excellent week!"
    elseif mood_avg >= 3.5 then mood_desc = "Good week"
    elseif mood_avg >= 2.5 then mood_desc = "Mixed feelings"
    elseif mood_avg >= 1.5 then mood_desc = "Challenging week"
    else mood_desc = "Tough week"
    end
  end

  -- Week label
  local week_label = string.format("%s to %s", format_date(start_date), format_date(end_date))

  -- Generate HTML
  local html = [[<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Weekly Journal Digest - ]] .. week_label .. [[</title>
  <style>
    body {
      font-family: 'Georgia', serif;
      line-height: 1.6;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
      background: #ffffff;
      color: #000000;
    }
    h1, h2, h3 {
      font-family: 'Georgia', serif;
      font-weight: normal;
    }
    h1 {
      font-size: 28px;
      border-bottom: 4px solid #000;
      padding-bottom: 10px;
      margin-bottom: 20px;
    }
    h2 {
      font-size: 20px;
      border-bottom: 1px solid #000;
      padding-bottom: 5px;
      margin-top: 30px;
    }
    .week-label {
      font-family: monospace;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 2px;
      color: #525252;
    }
    .stats {
      display: flex;
      gap: 20px;
      margin: 20px 0;
      padding: 15px;
      background: #f5f5f5;
    }
    .stat {
      text-align: center;
    }
    .stat-value {
      font-family: monospace;
      font-size: 24px;
      font-weight: bold;
    }
    .stat-label {
      font-family: monospace;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #525252;
    }
    .entry {
      padding: 15px 0;
      border-bottom: 1px solid #e5e5e5;
    }
    .entry-date {
      font-family: monospace;
      font-size: 12px;
      color: #525252;
    }
    .entry-title {
      font-size: 16px;
      margin: 5px 0;
    }
    .entry-mood {
      font-size: 20px;
    }
    .historical {
      background: #f5f5f5;
      padding: 15px;
      margin: 10px 0;
    }
    .historical-label {
      font-family: monospace;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #525252;
    }
    a {
      color: #000;
      text-decoration: underline;
    }
    .footer {
      margin-top: 30px;
      padding-top: 20px;
      border-top: 1px solid #e5e5e5;
      font-size: 12px;
      color: #525252;
      text-align: center;
    }
    .empty {
      font-style: italic;
      color: #525252;
      padding: 20px 0;
    }
  </style>
</head>
<body>
  <p class="week-label">Weekly Digest</p>
  <h1>]] .. week_label .. [[</h1>

  <div class="stats">
    <div class="stat">
      <div class="stat-value">]] .. #entries .. [[</div>
      <div class="stat-label">Entries</div>
    </div>
    <div class="stat">
      <div class="stat-value">]] .. mood_avg_str .. [[</div>
      <div class="stat-label">Mood Avg</div>
    </div>
    <div class="stat">
      <div class="stat-value">]] .. streak .. [[</div>
      <div class="stat-label">Day Streak</div>
    </div>
  </div>

  <p>]] .. mood_desc .. [[ ]] .. (mood_count > 0 and ("(" .. mood_count .. " days tracked)") or "") .. [[</p>

  <h2>This Week's Entries</h2>
]]

  if #entries > 0 then
    for _, entry in ipairs(entries) do
      html = html .. [[
  <div class="entry">
    <span class="entry-date">]] .. entry.date .. [[</span>
    ]] .. (entry.mood and ('<span class="entry-mood"> ' .. entry.mood .. '</span>') or "") .. [[
    <div class="entry-title">
      <a href="]] .. M.config.site_url .. "/" .. entry.date .. [[">]] .. entry.title .. [[</a>
    </div>
  </div>
]]
    end
  else
    html = html .. [[
  <p class="empty">No entries this week. Keep journaling!</p>
]]
  end

  if #historical > 0 then
    html = html .. [[

  <h2>On This Week in History</h2>
]]
    for _, entry in ipairs(historical) do
      html = html .. [[
  <div class="historical">
    <span class="historical-label">]] .. entry.years_ago .. [[ year]] .. (entry.years_ago > 1 and "s" or "") .. [[ ago</span>
    ]] .. (entry.mood and ('<span class="entry-mood"> ' .. entry.mood .. '</span>') or "") .. [[
    <div class="entry-title">
      <a href="]] .. M.config.site_url .. "/" .. entry.date .. [[">]] .. entry.title .. [[</a>
    </div>
  </div>
]]
    end
  end

  html = html .. [[

  <div class="footer">
    <p>Generated from your journal at <a href="]] .. M.config.site_url .. [[">]] .. M.config.site_url .. [[</a></p>
    <p>Keep writing. Your future self will thank you.</p>
  </div>
</body>
</html>
]]

  return html, {
    week_label = week_label,
    entries = #entries,
    mood_avg = mood_avg_str,
    streak = streak,
    historical = #historical,
  }
end

-- Save digest to file
function M.save_digest(weeks_ago)
  local html, stats = M.generate_digest(weeks_ago)
  ensure_dir(M.config.output_dir)

  local filename = "digest-" .. os.date("%Y-%m-%d") .. ".html"
  local path = M.config.output_dir .. "/" .. filename

  if write_file(path, html) then
    return path, stats
  end
  return nil, nil
end

-- Send digest via email (requires external service)
function M.send_digest(to_email, weeks_ago)
  local html, stats = M.generate_digest(weeks_ago)

  if M.config.email_service == "none" then
    return false, "No email service configured. Set JOURNAL_EMAIL_SERVICE env var."
  end

  local subject = "Journal Digest: " .. stats.week_label

  if M.config.email_service == "sendgrid" then
    if not M.config.sendgrid_api_key then
      return false, "SENDGRID_API_KEY not set"
    end

    -- Create JSON payload
    local payload = string.format([[{
      "personalizations": [{"to": [{"email": "%s"}]}],
      "from": {"email": "%s", "name": "%s"},
      "subject": "%s",
      "content": [{"type": "text/html", "value": %q}]
    }]], to_email, M.config.from_email, M.config.from_name, subject, html)

    -- Write payload to temp file
    local temp_file = os.tmpname()
    write_file(temp_file, payload)

    -- Send via curl
    local cmd = string.format(
      'curl -s -X POST "https://api.sendgrid.com/v3/mail/send" ' ..
        '-H "Authorization: Bearer %s" ' ..
        '-H "Content-Type: application/json" ' ..
        '-d @%s',
      M.config.sendgrid_api_key,
      temp_file
    )
    local result = os.execute(cmd)
    os.remove(temp_file)

    return result == 0, result == 0 and "Sent!" or "Failed to send"

  elseif M.config.email_service == "postmark" then
    if not M.config.postmark_api_key then
      return false, "POSTMARK_API_KEY not set"
    end

    local payload = string.format([[{
      "From": "%s",
      "To": "%s",
      "Subject": "%s",
      "HtmlBody": %q
    }]], M.config.from_email, to_email, subject, html)

    local temp_file = os.tmpname()
    write_file(temp_file, payload)

    local cmd = string.format(
      'curl -s -X POST "https://api.postmarkapp.com/email" ' ..
        '-H "X-Postmark-Server-Token: %s" ' ..
        '-H "Content-Type: application/json" ' ..
        '-d @%s',
      M.config.postmark_api_key,
      temp_file
    )
    local result = os.execute(cmd)
    os.remove(temp_file)

    return result == 0, result == 0 and "Sent!" or "Failed to send"
  end

  return false, "Unknown email service: " .. M.config.email_service
end

-- CLI interface
if arg then
  local send = false
  local to_email = nil
  local weeks_ago = 1

  for i, a in ipairs(arg) do
    if a == "--send" then
      send = true
    elseif a == "--to" and arg[i + 1] then
      to_email = arg[i + 1]
    elseif a == "--weeks" and arg[i + 1] then
      weeks_ago = tonumber(arg[i + 1]) or 1
    elseif a == "--help" or a == "-h" then
      print([[
Weekly Digest Generator

Usage: lua weekly_digest.lua [options]

Options:
  --weeks N     Generate digest for N weeks ago (default: 1)
  --send        Send digest via email (requires email service config)
  --to EMAIL    Recipient email address
  --help        Show this help

Environment Variables:
  JOURNAL_EMAIL_SERVICE   Email service: sendgrid, postmark, or none
  SENDGRID_API_KEY        API key for SendGrid
  POSTMARK_API_KEY        API key for Postmark

Examples:
  lua weekly_digest.lua                    # Generate and save last week's digest
  lua weekly_digest.lua --weeks 2          # Generate digest from 2 weeks ago
  lua weekly_digest.lua --send --to me@example.com  # Send digest
]])
      os.exit(0)
    end
  end

  if send and to_email then
    local ok, msg = M.send_digest(to_email, weeks_ago)
    print(ok and ("Digest sent to " .. to_email) or ("Error: " .. msg))
  else
    local path, stats = M.save_digest(weeks_ago)
    if path then
      print("Digest saved to: " .. path)
      print(string.format("  Week: %s", stats.week_label))
      print(string.format("  Entries: %d", stats.entries))
      print(string.format("  Mood avg: %s", stats.mood_avg))
      print(string.format("  Streak: %d days", stats.streak))
      print(string.format("  Historical: %d entries", stats.historical))
    else
      print("Error: Failed to save digest")
    end
  end
end

return M
