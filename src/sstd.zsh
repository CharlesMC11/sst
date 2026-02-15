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
readonly ARG_FILES_DIR='@@ARG_FILES_DIR@@'
readonly PENDING_LIST='@@PENDING_LIST@@'
readonly PROCESSED_LIST='@@PROCESSED_LIST@@'
readonly LOG_FILE='@@LOG_FILE@@'
readonly AA_LOG='@@AA_LOG@@'
readonly EXIFTOOL_LOG='@@EXIFTOOL_LOG@@'
readonly SYSTEM_LOG='@@SYSTEM_LOG@@'

readonly DATETIME_REPLACEMENT_RE='@@DATETIME_REPLACEMENT_RE@@'
readonly FILENAME_REPLACEMENT_RE='@@FILENAME_REPLACEMENT_RE@@'
readonly REPLACEMENT_PATTERN='@@REPLACEMENT_PATTERN@@'
readonly HW_MODEL='@@HW_MODEL@@'
integer -r PERFORMANCE_CORE_COUNT=@@PERFORMANCE_CORE_COUNT@@
readonly OS_VER='@@OS_VER@@'
float -r EXECUTION_DELAY=@@EXECUTION_DELAY@@

################################################################################

fpath=('@@FUNC_DIR@@')
autoload -Uz _cmc_log _cmc_err cmc_ls_images _sst _sst_notify _sst_on_exit

trap '_sst_on_exit' EXIT INT TERM

[[ -d $TMPDIR ]] || mkdir -p "$TMPDIR"

exec {log_fd}>>!"$LOG_FILE"
exec {fd}>|"$LOCK_PATH"

if zsystem flock -t 0 -f $fd "$LOCK_PATH"; then
  _cmc_log INFO "Lock acquired; starting..."

  sleep $EXECUTION_DELAY  # Give time for all screenshots to be written to disk

  cmc_ls_images "${INPUT_DIR}/" | _sst
  _sst_notify $?
else
  # return 75: BSD EX_TEMPFAIL
  _cmc_err 75 "Execution lock; exiting..."
fi
