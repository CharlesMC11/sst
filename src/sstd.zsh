#!/opt/homebrew/bin/zsh -f
# A script for adding certain metadata to screenshots, then renaming them.

setopt ERR_EXIT NO_CLOBBER EXTENDED_GLOB NULL_GLOB NUMERIC_GLOB_SORT
zmodload -F zsh/datetime +b:strftime
zmodload -F zsh/files    +b:rm
zmodload -F zsh/mapfile  +p:mapfile
zmodload -F zsh/system   +b:zsystem

autoload -Uz sst-log sst-err sst

readonly SCREENSHOTS_LIST="${TMPDIR:A}/files.txt"
readonly LOG_FILE="${TMPDIR:A}/${SERVICE_NAME}.log"

################################################################################

exec {fd}>|"$LOCK_PATH"

if zsystem flock -t 0 -f $fd "$LOCK_PATH"; then

  exec {log_fd}>>!"$LOG_FILE"
  sst-log INFO "Lock acquired; start..."

  sleep $EXECUTION_DELAY  # Give time for all screenshots to be written to disk

  sst

  integer -r status_code=$?
  if (( status_code == 0 )); then
    subtitle='📷 Success'
    sound=Glass
  else
    subtitle="⚠️ Failure: $status_code"
    sound=Basso
  fi

  readonly msg="${${(f)mapfile[$LOG_FILE]}[-1]}"
  osascript -e "display notification \"${msg##*\]?}\" with title \"${MAIN_NAME}\" subtitle \"${subtitle}\" sound name \"${sound}\""

  : >!"$LOG_FILE"
else
  # return 75: BSD EX_TEMPFAIL
  sst-err 75 "Execution lock; exiting..."
fi
