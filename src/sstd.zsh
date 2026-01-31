#!/opt/homebrew/bin/zsh -f
# A script for adding certain metadata to screenshots, then renaming them.

setopt ERR_EXIT NO_CLOBBER EXTENDED_GLOB NULL_GLOB NUMERIC_GLOB_SORT
zmodload -F zsh/datetime +b:strftime
zmodload -F zsh/files    +b:rm
zmodload -F zsh/mapfile  +p:mapfile
zmodload -F zsh/system   +p:zsystem

readonly SCREENSHOTS_LIST="${TMPDIR:A}/files.txt"
readonly LOG_FILE="${TMPDIR:A}/${SERVICE_NAME}.log"

integer log_fd
exec {log_fd}>>!"$LOG_FILE"

# Print a log message
# $1: The log level: DEBUG | INFO | WARN | ERROR | CRITICAL
_sst::log() {
  readonly level=${(U)1}; shift

  print -P -u $log_fd -f "[%s]\t[%s]\t[%s]\t%s\n" -- "%D{%F %T}" "${MAIN_NAME}:$$" "$level" "$*"
}

# Print an error message, then return a status code.
# $1: The error code to return.
# $2: The error messages to print.
_sst::err() {
  integer -r status_code=$1; shift
  _sst::log ERROR $@

  return $status_code
}

sst() {
  cd "$INPUT_DIR"

  _sst::log DEBUG 'Gathering filenames...'
  local -Ua pending_screenshots
  readonly pending_screenshots=( *.png(nOm.N) )
  integer -r num_pending=${#pending_screenshots}
  if (( num_pending == 0 )); then
    # return 66: BSD EX_NOINPUT
    _sst::err 66 "No screenshots to process in '${INPUT_DIR}/'"
  fi
  local unit=screenshot
  if (( num_pending > 1 )); then
    unit+=s
  fi
  _sst::log INFO "Processing ${num_pending} ${unit}..."
  print -l -- "${(@)pending_screenshots}" >|"$SCREENSHOTS_LIST"

  local -Ua bg_pids

  readonly current_month="${(%):-%D{%Y-%m}"

  readonly archive_name="Screenshots_${current_month}.aar"
  local aa_cmd=archive
  [[ -f $archive_name ]] && aa_cmd=append

  _sst::log INFO 'Archiving original files...'
  aa $aa_cmd -v -a lz4 -d "$INPUT_DIR" -o "${OUTPUT_DIR}/${archive_name}"\
    -include-path-list "$SCREENSHOTS_LIST" &>|"$AA_LOG" &
  integer -r aa_pid=$!; bg_pids+=($aa_pid)

  _sst::log INFO 'Injecting metadata with `ExifTool`...'
  exiftool -o "${OUTPUT_DIR}/${current_month}/" -struct -preserve -verbose \
    '-RawFileName<FileName'             '-PreservedFileName<FileName' \
    '-MaxAvailHeight<ImageHeight'       '-MaxAvailWidth<ImageWidth' \
    "-Model=${HW_MODEL}"                "-Software=${OS_VER}" \
    "-OffsetTime*=${(%):-%D{%z}"        '-AllDates<FileModifyDate' \
    -d '%y%m%d_%H%M%S'                  '-Filename<${FileModifyDate}%-c.%e' \
    -@ "${ARG_FILES_DIR}/charlesmc.args" \
    -@ "${ARG_FILES_DIR}/screenshot.args" \
    --  ${(@)pending_screenshots}       &>|"$EXIFTOOL_LOG" &
  integer -r et_pid=$!; bg_pids+=($et_pid)

  {
    _sst::log DEBUG 'Waiting for archiving and metadata injection to finish...'
    # return 73: BSD EX_CANTCREAT
    wait $aa_pid || _sst::err 73 'aa:' "${(j: ⏎ :)${(f)mapfile[$AA_LOG]}}"
    # return 70: BSD EX_SOFTWARE
    wait $et_pid || _sst::err 70 'exiftool:' "${(j: ⏎ :)${(f)mapfile[$EXIFTOOL_LOG]}}"
  } always {
    integer -r status_code=$?

    if (( status_code == 0 )); then
      _sst::log INFO 'Tasks successful. Cleaning up...'

      rm -f -- "${(@)pending_screenshots}"

      _sst::log INFO "Processed ${num_pending} ${unit}." "'${INPUT_DIR:A}/' → '${OUTPUT_DIR:A}/'"

      exec {log_fd}>&-
      print -- "$mapfile[$LOG_FILE]"

      : >!$SCREENSHOTS_LIST >!$AA_LOG >!$EXIFTOOL_LOG

    elif (( status_code > 0 )); then
      kill ${(@)bg_pids} 2>/dev/null
      return $status_code
    fi
  }


  return 0
}

################################################################################

integer fd
exec {fd}>|"$LOCK_PATH"

if zsystem flock -t 0 -f $fd "$LOCK_PATH"; then
  _sst::log INFO "Lock acquired; start..."

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
  _sst::err 75 "Execution lock; exiting..."
fi
