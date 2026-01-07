#!/bin/bash
# setup_backup_schedule.sh
# Sets up daily automatic journal backups via cron
# Usage: ./setup_backup_schedule.sh [--encrypt] [--target <target>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup_journal.lua"

# Default options
ENCRYPT=""
TARGET="local_backup"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --encrypt|-e)
            ENCRYPT="--encrypt"
            shift
            ;;
        --target|-t)
            TARGET="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--encrypt] [--target <target>]"
            exit 1
            ;;
    esac
done

# Verify backup script exists
if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    echo "ERROR: Backup script not found: $BACKUP_SCRIPT"
    exit 1
fi

# Verify lua is available
if ! command -v lua &> /dev/null; then
    echo "ERROR: lua command not found. Please install Lua."
    exit 1
fi

# Create log directory
LOG_DIR="${HOME}/.journal-backups/logs"
mkdir -p "$LOG_DIR"

# Generate cron entry
# Run daily at 2 AM
CRON_ENTRY="0 2 * * * /usr/bin/lua ${BACKUP_SCRIPT} backup --target ${TARGET} ${ENCRYPT} >> ${LOG_DIR}/backup.log 2>&1"

echo "=== Journal Backup Scheduler ==="
echo ""
echo "This will set up automatic daily backups at 2:00 AM"
echo ""
echo "Settings:"
echo "  Target: ${TARGET}"
echo "  Encrypt: ${ENCRYPT:-no}"
echo "  Log: ${LOG_DIR}/backup.log"
echo ""
echo "Cron entry to be added:"
echo "  ${CRON_ENTRY}"
echo ""

read -p "Add this to your crontab? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Add to crontab, preserving existing entries
    (crontab -l 2>/dev/null | grep -v "backup_journal.lua"; echo "$CRON_ENTRY") | crontab -
    echo ""
    echo "Cron job added successfully!"
    echo "To verify: crontab -l"
    echo "To remove: crontab -e (delete the journal backup line)"
else
    echo ""
    echo "Cancelled. To add manually, run:"
    echo "  crontab -e"
    echo ""
    echo "And add this line:"
    echo "  ${CRON_ENTRY}"
fi
