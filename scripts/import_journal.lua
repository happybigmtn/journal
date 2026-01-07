#!/usr/bin/env lua
-- import_journal.lua
-- Import journal entries from Day One and Journey app exports
-- Usage: lua import_journal.lua <format> <input_path> [output_dir]
--
-- Formats:
--   dayone  - Day One JSON export (unzipped, expects Journal.json)
--   journey - Journey backup (expects directory with JSON files)

local json = nil
local ok, cjson = pcall(require, "cjson")
if ok then
  json = cjson
else
  -- Fallback: simple JSON parser for our needs
  json = {
    decode = function(str)
      -- This is a minimal parser; for production use, consider dkjson or cjson
      local function parse_value(s, pos)
        pos = pos or 1
        -- Skip whitespace
        pos = s:match("^%s*()", pos)
        local first = s:sub(pos, pos)

        if first == '"' then
          -- String
          local i = pos + 1
          local result = ""
          while i <= #s do
            local c = s:sub(i, i)
            if c == '"' then
              return result, i + 1
            elseif c == '\\' then
              local next_c = s:sub(i + 1, i + 1)
              if next_c == 'n' then
                result = result .. '\n'
              elseif next_c == 't' then
                result = result .. '\t'
              elseif next_c == 'r' then
                result = result .. '\r'
              elseif next_c == '"' then
                result = result .. '"'
              elseif next_c == '\\' then
                result = result .. '\\'
              else
                result = result .. next_c
              end
              i = i + 2
            else
              result = result .. c
              i = i + 1
            end
          end
        elseif first == '[' then
          -- Array
          local arr = {}
          pos = pos + 1
          while true do
            pos = s:match("^%s*()", pos)
            if s:sub(pos, pos) == ']' then
              return arr, pos + 1
            end
            if #arr > 0 then
              if s:sub(pos, pos) == ',' then
                pos = pos + 1
              end
            end
            local val
            val, pos = parse_value(s, pos)
            table.insert(arr, val)
          end
        elseif first == '{' then
          -- Object
          local obj = {}
          pos = pos + 1
          while true do
            pos = s:match("^%s*()", pos)
            if s:sub(pos, pos) == '}' then
              return obj, pos + 1
            end
            if next(obj) then
              if s:sub(pos, pos) == ',' then
                pos = pos + 1
              end
            end
            pos = s:match("^%s*()", pos)
            local key
            key, pos = parse_value(s, pos)
            pos = s:match("^%s*:%s*()", pos)
            local val
            val, pos = parse_value(s, pos)
            obj[key] = val
          end
        elseif s:sub(pos, pos + 3) == "true" then
          return true, pos + 4
        elseif s:sub(pos, pos + 4) == "false" then
          return false, pos + 5
        elseif s:sub(pos, pos + 3) == "null" then
          return nil, pos + 4
        else
          -- Number
          local num_str = s:match("^%-?%d+%.?%d*[eE]?[+-]?%d*", pos)
          if num_str then
            return tonumber(num_str), pos + #num_str
          end
        end
        error("Invalid JSON at position " .. pos)
      end

      local result, _ = parse_value(str, 1)
      return result
    end
  }
end

-- Configuration
local DEFAULT_OUTPUT_DIR = os.getenv("HOME") .. "/Coding/journal/site/src/content/journal"
local DEFAULT_ASSETS_DIR = os.getenv("HOME") .. "/Coding/journal/site/public/journal/assets"

-- Utility: Ensure directory exists
local function ensure_dir(path)
  os.execute('mkdir -p "' .. path .. '"')
end

-- Utility: Read file contents
local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "Cannot open file: " .. path
  end
  local content = file:read("*all")
  file:close()
  return content
end

-- Utility: Write file
local function write_file(path, content)
  local file = io.open(path, "w")
  if not file then
    return false, "Cannot write file: " .. path
  end
  file:write(content)
  file:close()
  return true
end

-- Utility: Copy file
local function copy_file(src, dst)
  local src_file = io.open(src, "rb")
  if not src_file then return false end
  local dst_file = io.open(dst, "wb")
  if not dst_file then
    src_file:close()
    return false
  end
  local content = src_file:read("*all")
  dst_file:write(content)
  src_file:close()
  dst_file:close()
  return true
end

-- Utility: Format date from Unix timestamp
local function format_date(timestamp)
  return os.date("%Y-%m-%d", timestamp)
end

-- Utility: Get date parts from timestamp
local function get_date_parts(timestamp)
  local date = os.date("*t", timestamp)
  return {
    year = string.format("%04d", date.year),
    month = string.format("%02d", date.month),
    day = string.format("%02d", date.day),
    full = format_date(timestamp)
  }
end

-- Utility: Strip HTML tags
local function strip_html(html)
  if not html then return "" end
  local text = html
  -- Remove script/style content
  text = text:gsub("<script.-</script>", "")
  text = text:gsub("<style.-</style>", "")
  -- Replace common HTML entities
  text = text:gsub("&nbsp;", " ")
  text = text:gsub("&amp;", "&")
  text = text:gsub("&lt;", "<")
  text = text:gsub("&gt;", ">")
  text = text:gsub("&quot;", '"')
  text = text:gsub("&#39;", "'")
  -- Replace <br> with newlines
  text = text:gsub("<br%s*/?>", "\n")
  text = text:gsub("<p>", "\n\n")
  text = text:gsub("</p>", "")
  -- Remove remaining tags
  text = text:gsub("<[^>]+>", "")
  -- Clean up whitespace
  text = text:gsub("\n%s*\n%s*\n", "\n\n")
  return text:match("^%s*(.-)%s*$") or ""
end

-- Utility: Escape YAML string
local function yaml_escape(str)
  if not str then return '""' end
  if str:match("[:\n\r#]") or str:match("^[%[%]{}>|*&!%%@`]") then
    return '"' .. str:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
  end
  return '"' .. str .. '"'
end

-- Map Day One mood to emoji
local function map_dayone_mood(mood)
  if not mood then return nil end
  mood = mood:lower()
  if mood:match("great") or mood:match("amazing") or mood:match("excellent") then
    return "happy"
  elseif mood:match("good") or mood:match("fine") then
    return "content"
  elseif mood:match("okay") or mood:match("neutral") then
    return "neutral"
  elseif mood:match("bad") or mood:match("down") then
    return "sad"
  elseif mood:match("terrible") or mood:match("awful") then
    return "very sad"
  end
  return mood
end

-- Generate frontmatter
local function generate_frontmatter(entry)
  local fm = {
    "---",
    "title: " .. yaml_escape(entry.title or entry.date),
    "date: " .. entry.date,
    "type: daily",
  }

  if entry.mood then
    table.insert(fm, "mood: " .. yaml_escape(entry.mood))
  end

  if entry.tags and #entry.tags > 0 then
    table.insert(fm, "tags: [" .. table.concat(entry.tags, ", ") .. "]")
  else
    table.insert(fm, "tags: []")
  end

  table.insert(fm, "draft: false")
  table.insert(fm, "published: false")
  table.insert(fm, "# Imported from " .. (entry.source or "unknown"))
  table.insert(fm, "---")

  return table.concat(fm, "\n")
end

-- Import Day One JSON export
local function import_dayone(input_path, output_dir, assets_dir)
  local journal_path = input_path
  if input_path:sub(-1) == "/" then
    journal_path = input_path .. "Journal.json"
  elseif not input_path:match("%.json$") then
    journal_path = input_path .. "/Journal.json"
  end

  local content, err = read_file(journal_path)
  if not content then
    return false, err
  end

  local data = json.decode(content)
  if not data or not data.entries then
    return false, "Invalid Day One JSON format (missing 'entries' array)"
  end

  local imported = 0
  local skipped = 0
  local errors = {}

  for _, entry in ipairs(data.entries) do
    -- Parse creation date
    local timestamp
    if entry.creationDate then
      -- Day One uses ISO 8601 format: "2024-01-15T10:30:00Z"
      local y, m, d = entry.creationDate:match("(%d+)-(%d+)-(%d+)")
      if y then
        timestamp = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
      end
    elseif entry.creationDeviceType then
      -- Fallback: try other date fields
      timestamp = os.time()
    end

    if not timestamp then
      table.insert(errors, "Skipped entry: no valid date")
      skipped = skipped + 1
      goto continue
    end

    local parts = get_date_parts(timestamp)
    local entry_dir = output_dir .. "/" .. parts.year .. "/" .. parts.month
    local filename = parts.full .. ".md"
    local filepath = entry_dir .. "/" .. filename

    -- Check if file already exists
    local existing = io.open(filepath, "r")
    if existing then
      existing:close()
      table.insert(errors, "Skipped: " .. filename .. " (already exists)")
      skipped = skipped + 1
      goto continue
    end

    -- Build entry data
    local entry_data = {
      date = parts.full,
      title = parts.full,
      mood = map_dayone_mood(entry.mood),
      tags = entry.tags or {},
      source = "Day One",
    }

    -- Get text content
    local text = entry.text or ""
    text = strip_html(text)

    -- Handle photos
    local photos_md = {}
    if entry.photos and #entry.photos > 0 then
      local photo_dir = assets_dir .. "/" .. parts.year .. "/" .. parts.month
      ensure_dir(photo_dir)

      for _, photo in ipairs(entry.photos) do
        if photo.identifier or photo.md5 then
          local photo_id = photo.identifier or photo.md5
          -- Look for photo in input directory
          local photo_filename = photo_id .. ".jpeg"
          local source_photo = input_path:gsub("Journal%.json$", ""):gsub("/$", "") .. "/photos/" .. photo_filename

          -- Try other extensions
          local extensions = { ".jpeg", ".jpg", ".png", ".heic" }
          local found_photo = nil
          for _, ext in ipairs(extensions) do
            local try_path = input_path:gsub("Journal%.json$", ""):gsub("/$", "") .. "/photos/" .. photo_id .. ext
            local f = io.open(try_path, "r")
            if f then
              f:close()
              found_photo = try_path
              photo_filename = photo_id .. ext
              break
            end
          end

          if found_photo then
            local dest_photo = photo_dir .. "/" .. photo_filename
            if copy_file(found_photo, dest_photo) then
              local photo_path = "/journal/assets/" .. parts.year .. "/" .. parts.month .. "/" .. photo_filename
              table.insert(photos_md, "![Photo](" .. photo_path .. ")")
            end
          end
        end
      end
    end

    -- Build markdown content
    local frontmatter = generate_frontmatter(entry_data)
    local body = text

    if #photos_md > 0 then
      body = body .. "\n\n## Photos\n\n" .. table.concat(photos_md, "\n\n")
    end

    -- Write entry file
    ensure_dir(entry_dir)
    local success, write_err = write_file(filepath, frontmatter .. "\n\n" .. body .. "\n")
    if success then
      imported = imported + 1
    else
      table.insert(errors, "Failed to write: " .. filename .. " - " .. (write_err or "unknown error"))
    end

    ::continue::
  end

  return true, {
    imported = imported,
    skipped = skipped,
    errors = errors,
    total = #data.entries
  }
end

-- Import Journey backup
local function import_journey(input_path, output_dir, assets_dir)
  -- Journey exports individual JSON files per entry
  local handle = io.popen('find "' .. input_path .. '" -name "*.json" -type f 2>/dev/null')
  if not handle then
    return false, "Cannot list files in directory"
  end

  local files = {}
  for line in handle:lines() do
    table.insert(files, line)
  end
  handle:close()

  if #files == 0 then
    return false, "No JSON files found in " .. input_path
  end

  local imported = 0
  local skipped = 0
  local errors = {}

  for _, json_file in ipairs(files) do
    local content, err = read_file(json_file)
    if not content then
      table.insert(errors, "Cannot read: " .. json_file)
      skipped = skipped + 1
      goto continue
    end

    local ok, entry = pcall(json.decode, content)
    if not ok or not entry then
      table.insert(errors, "Invalid JSON: " .. json_file)
      skipped = skipped + 1
      goto continue
    end

    -- Journey uses date_journal (milliseconds since epoch)
    local timestamp
    if entry.date_journal then
      timestamp = math.floor(entry.date_journal / 1000)
    elseif entry.date then
      -- Some formats use 'date' directly
      local y, m, d = tostring(entry.date):match("(%d+)-(%d+)-(%d+)")
      if y then
        timestamp = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
      end
    end

    if not timestamp then
      table.insert(errors, "No date in: " .. json_file)
      skipped = skipped + 1
      goto continue
    end

    local parts = get_date_parts(timestamp)
    local entry_dir = output_dir .. "/" .. parts.year .. "/" .. parts.month
    local filename = parts.full .. ".md"
    local filepath = entry_dir .. "/" .. filename

    -- Check if file already exists
    local existing = io.open(filepath, "r")
    if existing then
      existing:close()
      table.insert(errors, "Skipped: " .. filename .. " (already exists)")
      skipped = skipped + 1
      goto continue
    end

    -- Build entry data
    local entry_data = {
      date = parts.full,
      title = parts.full,
      tags = entry.tags or {},
      source = "Journey",
    }

    -- Get text content (Journey may use HTML)
    local text = entry.text or ""
    text = strip_html(text)

    -- Handle photos
    local photos_md = {}
    if entry.photos and #entry.photos > 0 then
      local photo_dir = assets_dir .. "/" .. parts.year .. "/" .. parts.month
      ensure_dir(photo_dir)

      for i, photo_ref in ipairs(entry.photos) do
        -- Journey photos are in the same directory with various naming
        local photo_filename = nil
        local source_photo = nil

        -- Try to find photo file
        local base_dir = json_file:match("(.*/)")
        if base_dir and type(photo_ref) == "string" then
          source_photo = base_dir .. photo_ref
        elseif base_dir then
          -- Try common patterns
          local patterns = {
            photo_ref,
            parts.full .. "_" .. i .. ".jpg",
            parts.full .. "_" .. i .. ".jpeg",
          }
          for _, pat in ipairs(patterns) do
            local try_path = base_dir .. tostring(pat)
            local f = io.open(try_path, "r")
            if f then
              f:close()
              source_photo = try_path
              photo_filename = tostring(pat)
              break
            end
          end
        end

        if source_photo and photo_filename then
          local dest_photo = photo_dir .. "/" .. photo_filename
          if copy_file(source_photo, dest_photo) then
            local photo_path = "/journal/assets/" .. parts.year .. "/" .. parts.month .. "/" .. photo_filename
            table.insert(photos_md, "![Photo](" .. photo_path .. ")")
          end
        end
      end
    end

    -- Build markdown content
    local frontmatter = generate_frontmatter(entry_data)
    local body = text

    if #photos_md > 0 then
      body = body .. "\n\n## Photos\n\n" .. table.concat(photos_md, "\n\n")
    end

    -- Write entry file
    ensure_dir(entry_dir)
    local success, write_err = write_file(filepath, frontmatter .. "\n\n" .. body .. "\n")
    if success then
      imported = imported + 1
    else
      table.insert(errors, "Failed to write: " .. filename .. " - " .. (write_err or "unknown error"))
    end

    ::continue::
  end

  return true, {
    imported = imported,
    skipped = skipped,
    errors = errors,
    total = #files
  }
end

-- Main entry point
local function main()
  local args = arg
  if #args < 2 then
    print("Usage: lua import_journal.lua <format> <input_path> [output_dir]")
    print("")
    print("Formats:")
    print("  dayone  - Day One JSON export (expects Journal.json in directory)")
    print("  journey - Journey backup (expects directory with JSON files)")
    print("")
    print("Examples:")
    print("  lua import_journal.lua dayone ~/Downloads/DayOne-Export/")
    print("  lua import_journal.lua journey ~/Downloads/Journey-Backup/")
    os.exit(1)
  end

  local format = args[1]:lower()
  local input_path = args[2]
  local output_dir = args[3] or DEFAULT_OUTPUT_DIR
  local assets_dir = DEFAULT_ASSETS_DIR

  print("Import Journal")
  print("==============")
  print("Format: " .. format)
  print("Input:  " .. input_path)
  print("Output: " .. output_dir)
  print("")

  local success, result
  if format == "dayone" then
    success, result = import_dayone(input_path, output_dir, assets_dir)
  elseif format == "journey" then
    success, result = import_journey(input_path, output_dir, assets_dir)
  else
    print("Error: Unknown format '" .. format .. "'. Use 'dayone' or 'journey'.")
    os.exit(1)
  end

  if not success then
    print("Error: " .. tostring(result))
    os.exit(1)
  end

  print("Results:")
  print("  Total entries: " .. result.total)
  print("  Imported:      " .. result.imported)
  print("  Skipped:       " .. result.skipped)

  if #result.errors > 0 then
    print("")
    print("Errors/Notes:")
    for _, err in ipairs(result.errors) do
      print("  - " .. err)
    end
  end

  print("")
  print("Done! Run 'npm run build' in site/ to rebuild the journal.")
end

-- Export for use as module
local M = {
  import_dayone = import_dayone,
  import_journey = import_journey,
}

-- Run main if called as script
if arg and arg[0] then
  main()
end

return M
