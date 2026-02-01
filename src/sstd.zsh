#!@@ZSH@@ -f
# A script for adding certain metadata to screenshots, then renaming them.

setopt ERR_EXIT NO_CLOBBER NO_UNSET EXTENDED_GLOB NULL_GLOB NUMERIC_GLOB_SORT
zmodload -F zsh/datetime +b:strftime
zmodload -F zsh/files    +b:rm
zmodload -F zsh/mapfile  +p:mapfile
zmodload -F zsh/system   +b:zsystem

readonly SERVICE_NAME='@@SERVICE_NAME@@'
readonly AA='@@AA@@'
readonly EXIFTOOL='@@EXIFTOOL@@'
readonly OSASCRIPT='@@OSASCRIPT@@'

readonly INPUT_DIR='@@INPUT_DIR@@'
readonly OUTPUT_DIR='@@OUTPUT_DIR@@'

readonly TMPDIR='@@TMPDIR@@'
readonly LOCK_PATH='@@LOCK_PATH@@'
readonly PENDING_LIST='@@PENDING_LIST@@'
readonly LOG_FILE='@@LOG_FILE@@'
readonly AA_LOG='@@AA_LOG@@'
readonly EXIFTOOL_LOG='@@EXIFTOOL_LOG@@'
readonly SYSTEM_LOG='@@SYSTEM_LOG@@'

readonly HW_MODEL='@@HW_MODEL@@'
readonly OS_VER='@@OS_VER@@'
float -r EXECUTION_DELAY=@@EXECUTION_DELAY@@

################################################################################

fpath=('@@FUNC_DIR@@')
autoload -Uz sst-cleanup sst-err sst-log sst-notify sst

trap 'sst-cleanup' EXIT INT TERM

[[ -d $TMPDIR ]] || mkdir -p "$TMPDIR"

exec {log_fd}>>!"$LOG_FILE"
exec {fd}>|"$LOCK_PATH"

if zsystem flock -t 0 -f $fd "$LOCK_PATH"; then
  sst-log INFO "Lock acquired; starting..."

  sleep $EXECUTION_DELAY  # Give time for all screenshots to be written to disk

  sst
  sst-notify $?
else
  # return 75: BSD EX_TEMPFAIL
  sst-err 75 "Execution lock; exiting..."
fi
