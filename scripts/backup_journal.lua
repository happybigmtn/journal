#!/usr/bin/env lua
-- backup_journal.lua
-- Automated backup script for journal entries
-- Supports local, S3, and Backblaze B2 targets via rclone
-- Usage: lua backup_journal.lua [--target <target>] [--encrypt] [--verify]

-- Get the directory this script is in
local script_path = debug.getinfo(1, "S").source:sub(2)
-- Handle relative paths by getting absolute path
local function get_absolute_path(path)
  if path:sub(1,1) ~= "/" then
    local handle = io.popen("pwd")
    local cwd = handle:read("*l")
    handle:close()
    path = cwd .. "/" .. path
  end
  return path
end
script_path = get_absolute_path(script_path)
local script_dir = script_path:match("(.*/)")
local project_root = script_dir:gsub("/scripts/$", "")

-- Configuration
local config = {
  journal_dir = project_root .. "/site/src/content/journal",
  backup_dir = os.getenv("HOME") .. "/.journal-backups",

  -- Encryption settings
  encrypt = false,
  gpg_recipient = nil, -- Set to your GPG key ID for asymmetric encryption

  -- Remote targets (configured via rclone)
  -- Run 'rclone config' to set up remotes
  targets = {
    local_backup = "local", -- Built-in: tar to backup_dir
    -- s3 = "s3:my-bucket/journal-backups",
    -- b2 = "b2:my-bucket/journal-backups",
  },

  -- Retention: keep last N backups
  retention_count = 30,

  -- Verify checksums after backup
  verify = true,
}

-- Utility: run shell command and return output
local function run(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  local result = handle:read("*a")
  local success = handle:close()
  return result, success
end

-- Utility: check if command exists
local function command_exists(cmd)
  local _, success = run("command -v " .. cmd)
  return success
end

-- Utility: get timestamp for backup naming
local function get_timestamp()
  return os.date("%Y%m%d_%H%M%S")
end

-- Utility: calculate SHA256 checksum
local function sha256sum(filepath)
  local output, success = run("sha256sum " .. filepath)
  if success then
    return output:match("^(%x+)")
  end
  return nil
end

-- Utility: get file size in bytes
local function filesize(filepath)
  local handle = io.open(filepath, "rb")
  if handle then
    local size = handle:seek("end")
    handle:close()
    return size
  end
  return 0
end

-- Utility: format bytes as human readable
local function format_size(bytes)
  local units = {"B", "KB", "MB", "GB"}
  local unit_index = 1
  while bytes >= 1024 and unit_index < #units do
    bytes = bytes / 1024
    unit_index = unit_index + 1
  end
  return string.format("%.2f %s", bytes, units[unit_index])
end

-- Create backup archive
local function create_archive(timestamp)
  local archive_name = "journal_backup_" .. timestamp .. ".tar.gz"
  local archive_path = config.backup_dir .. "/" .. archive_name

  -- Ensure backup directory exists
  os.execute("mkdir -p " .. config.backup_dir)

  -- Create tar archive
  local cmd = string.format(
    "tar -czf %s -C %s .",
    archive_path,
    config.journal_dir
  )

  local output, success = run(cmd)
  if not success then
    print("ERROR: Failed to create archive")
    print(output)
    return nil
  end

  return archive_path
end

-- Encrypt file with GPG
local function encrypt_file(filepath)
  if not command_exists("gpg") then
    print("WARNING: gpg not found, skipping encryption")
    return filepath
  end

  local encrypted_path = filepath .. ".gpg"
  local cmd

  if config.gpg_recipient then
    -- Asymmetric encryption with recipient's public key
    cmd = string.format(
      "gpg --batch --yes -e -r %s -o %s %s",
      config.gpg_recipient,
      encrypted_path,
      filepath
    )
  else
    -- Symmetric encryption (will prompt for passphrase if interactive)
    -- Use --passphrase-fd for automated scripts
    cmd = string.format(
      "gpg --batch --yes -c -o %s %s",
      encrypted_path,
      filepath
    )
  end

  local output, success = run(cmd)
  if not success then
    print("ERROR: Encryption failed")
    print(output)
    return filepath
  end

  -- Remove unencrypted file
  os.remove(filepath)

  return encrypted_path
end

-- Upload to remote target via rclone
local function upload_to_remote(filepath, target)
  if not command_exists("rclone") then
    print("WARNING: rclone not found, cannot upload to remote")
    return false
  end

  local filename = filepath:match("([^/]+)$")
  local remote_path = target .. "/" .. filename

  local cmd = string.format("rclone copy %s %s", filepath, target)
  local output, success = run(cmd)

  if not success then
    print("ERROR: Upload to " .. target .. " failed")
    print(output)
    return false
  end

  return true
end

-- Verify backup integrity
local function verify_backup(filepath, expected_checksum)
  local actual_checksum = sha256sum(filepath)
  if actual_checksum == expected_checksum then
    print("  Checksum verified: " .. actual_checksum:sub(1, 16) .. "...")
    return true
  else
    print("ERROR: Checksum mismatch!")
    print("  Expected: " .. expected_checksum)
    print("  Actual:   " .. (actual_checksum or "nil"))
    return false
  end
end

-- Clean up old backups (retention policy)
local function cleanup_old_backups()
  local pattern = config.backup_dir .. "/journal_backup_*.tar.gz*"
  local output = run("ls -t " .. pattern .. " 2>/dev/null")

  local files = {}
  for file in output:gmatch("[^\n]+") do
    table.insert(files, file)
  end

  -- Remove files beyond retention count
  local removed = 0
  for i = config.retention_count + 1, #files do
    os.remove(files[i])
    removed = removed + 1
  end

  if removed > 0 then
    print("Cleaned up " .. removed .. " old backup(s)")
  end
end

-- Save backup metadata
local function save_metadata(filepath, checksum, timestamp)
  local metadata_file = config.backup_dir .. "/backup_manifest.txt"
  local handle = io.open(metadata_file, "a")
  if handle then
    local filename = filepath:match("([^/]+)$")
    local size = filesize(filepath)
    handle:write(string.format(
      "%s\t%s\t%s\t%d\n",
      timestamp,
      filename,
      checksum,
      size
    ))
    handle:close()
  end
end

-- Main backup function
local function backup(target_name, encrypt, verify)
  target_name = target_name or "local_backup"
  encrypt = encrypt or config.encrypt
  verify = verify or config.verify

  local timestamp = get_timestamp()
  print("=== Journal Backup ===")
  print("Timestamp: " .. timestamp)
  print("Source: " .. config.journal_dir)
  print()

  -- Step 1: Create archive
  print("[1/4] Creating archive...")
  local archive_path = create_archive(timestamp)
  if not archive_path then
    return false
  end
  print("  Created: " .. archive_path)
  print("  Size: " .. format_size(filesize(archive_path)))

  -- Calculate checksum before encryption
  local checksum = sha256sum(archive_path)
  print("  Checksum: " .. checksum:sub(1, 16) .. "...")

  -- Step 2: Encrypt (optional)
  local final_path = archive_path
  if encrypt then
    print()
    print("[2/4] Encrypting...")
    final_path = encrypt_file(archive_path)
    print("  Encrypted: " .. final_path)
    print("  Size: " .. format_size(filesize(final_path)))
  else
    print()
    print("[2/4] Encryption skipped")
  end

  -- Step 3: Upload to remote (if not local)
  print()
  if target_name ~= "local_backup" then
    print("[3/4] Uploading to " .. target_name .. "...")
    local target = config.targets[target_name]
    if target then
      if upload_to_remote(final_path, target) then
        print("  Upload complete")
      else
        return false
      end
    else
      print("ERROR: Unknown target: " .. target_name)
      return false
    end
  else
    print("[3/4] Local backup (no upload)")
  end

  -- Step 4: Verify
  print()
  if verify and not encrypt then
    print("[4/4] Verifying backup...")
    if not verify_backup(final_path, checksum) then
      return false
    end
  else
    print("[4/4] Verification " .. (encrypt and "skipped (encrypted)" or "skipped"))
  end

  -- Save metadata
  save_metadata(final_path, checksum, timestamp)

  -- Cleanup old backups
  print()
  cleanup_old_backups()

  print()
  print("=== Backup Complete ===")
  print("Location: " .. final_path)

  return true
end

-- List existing backups
local function list_backups()
  print("=== Existing Backups ===")
  print()

  local manifest_file = config.backup_dir .. "/backup_manifest.txt"
  local handle = io.open(manifest_file, "r")

  if handle then
    print(string.format("%-20s %-45s %s", "Timestamp", "Filename", "Size"))
    print(string.rep("-", 80))

    for line in handle:lines() do
      local ts, filename, _, size = line:match("([^\t]+)\t([^\t]+)\t([^\t]+)\t(%d+)")
      if ts then
        print(string.format("%-20s %-45s %s", ts, filename, format_size(tonumber(size))))
      end
    end
    handle:close()
  else
    -- Fall back to listing directory
    local output = run("ls -lhS " .. config.backup_dir .. "/journal_backup_* 2>/dev/null")
    if output ~= "" then
      print(output)
    else
      print("No backups found in " .. config.backup_dir)
    end
  end
end

-- Restore from backup
local function restore(backup_file, target_dir)
  if not backup_file then
    print("ERROR: Specify backup file to restore")
    return false
  end

  target_dir = target_dir or config.journal_dir

  print("=== Restoring Backup ===")
  print("From: " .. backup_file)
  print("To: " .. target_dir)
  print()

  -- Handle encrypted backups
  local archive_path = backup_file
  if backup_file:match("%.gpg$") then
    print("Decrypting...")
    archive_path = backup_file:gsub("%.gpg$", "")
    local cmd = string.format("gpg --batch --yes -d -o %s %s", archive_path, backup_file)
    local _, success = run(cmd)
    if not success then
      print("ERROR: Decryption failed")
      return false
    end
  end

  -- Create target directory if needed
  os.execute("mkdir -p " .. target_dir)

  -- Extract archive
  local cmd = string.format("tar -xzf %s -C %s", archive_path, target_dir)
  local output, success = run(cmd)

  -- Cleanup decrypted temp file
  if archive_path ~= backup_file then
    os.remove(archive_path)
  end

  if not success then
    print("ERROR: Extraction failed")
    print(output)
    return false
  end

  print("Restore complete!")
  return true
end

-- Parse command line arguments
local function parse_args(args)
  local options = {
    command = "backup",
    target = "local_backup",
    encrypt = false,
    verify = true,
    file = nil,
    dir = nil,
  }

  local i = 1
  while i <= #args do
    local arg = args[i]

    if arg == "--target" or arg == "-t" then
      i = i + 1
      options.target = args[i]
    elseif arg == "--encrypt" or arg == "-e" then
      options.encrypt = true
    elseif arg == "--no-verify" then
      options.verify = false
    elseif arg == "--file" or arg == "-f" then
      i = i + 1
      options.file = args[i]
    elseif arg == "--dir" or arg == "-d" then
      i = i + 1
      options.dir = args[i]
    elseif arg == "backup" then
      options.command = "backup"
    elseif arg == "list" then
      options.command = "list"
    elseif arg == "restore" then
      options.command = "restore"
    elseif arg == "help" or arg == "--help" or arg == "-h" then
      options.command = "help"
    end

    i = i + 1
  end

  return options
end

-- Print help
local function print_help()
  print([[
Journal Backup Script

Usage:
  lua backup_journal.lua [command] [options]

Commands:
  backup    Create a new backup (default)
  list      List existing backups
  restore   Restore from a backup
  help      Show this help message

Options:
  --target, -t <name>  Backup target (default: local_backup)
                       Configure remotes with 'rclone config'
  --encrypt, -e        Encrypt backup with GPG
  --no-verify          Skip checksum verification
  --file, -f <path>    Backup file for restore
  --dir, -d <path>     Target directory for restore

Examples:
  lua backup_journal.lua backup
  lua backup_journal.lua backup --encrypt
  lua backup_journal.lua backup --target s3
  lua backup_journal.lua list
  lua backup_journal.lua restore --file ~/.journal-backups/journal_backup_20250107.tar.gz

Configuration:
  Edit the 'config' table at the top of this script to:
  - Set up remote targets (requires rclone)
  - Configure GPG encryption recipient
  - Adjust retention policy
]])
end

-- Main entry point
local function main(args)
  local options = parse_args(args)

  if options.command == "help" then
    print_help()
  elseif options.command == "list" then
    list_backups()
  elseif options.command == "restore" then
    restore(options.file, options.dir)
  else
    backup(options.target, options.encrypt, options.verify)
  end
end

-- Run if called directly (not required as module)
if arg then
  main(arg)
end

-- Export for use as module (from Neovim)
return {
  backup = backup,
  list = list_backups,
  restore = restore,
  config = config,
}
