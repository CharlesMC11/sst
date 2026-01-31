#!/opt/homebrew/bin/zsh -f
# A script for adding certain metadata to screenshots, then renaming them.

setopt CHASE_LINKS ERR_EXIT NO_UNSET WARN_CREATE_GLOBAL
setopt NO_BEEP NO_NOTIFY
setopt EXTENDED_GLOB NULL_GLOB NUMERIC_GLOB_SORT

zmodload zsh/datetime zsh/files zsh/parameter zsh/mapfile zsh/system zsh/zutil

readonly SCRIPT_NAME=${0:t:r}

readonly DATE_GLOB='<1900-2199>-<01-12>-<01-31>'
readonly TIME_GLOB='<00-23>.<00-59>.<00-59>'
readonly FILENAME_GLOB="Screenshot ${~DATE_GLOB} at ${~TIME_GLOB}"
readonly SORT_GLOB='*(.Om)'

readonly DATE_RE='(\d{2})(\d{2})-(\d{2})-(\d{2})'
readonly TIME_RE='(\d{2})\.(\d{2})\.(\d{2})'
readonly DATETIME_RE="^Screenshot ${DATE_RE} at ${TIME_RE}(\D*?\d*?\D*?)\..+$"
readonly FILENAME_REPLACEMENT_RE='$2$3$4_$5$6$7$8.%e'
readonly DATETIME_REPLACEMENT_RE='$1$2-$3-$4T$5:$6:$7'

readonly SCREENSHOTS_LIST="${TMPDIR:A}/files.txt"
readonly LOCK_PATH="${TMPDIR:A}/${SCRIPT_NAME}.lock"

float -r EXECUTION_DELAY=0.2

# Print a log message
# $1: The log level: DEBUG | INFO | WARN | ERROR | CRITICAL
_sst::log() {
  readonly level=${(U)1}; shift
  integer fd=1; [[ $level == (WARN|ERROR) ]] && fd=2

  print -P -u $fd -f "[%s]\t[%s]\t[%s]\t%s\n" -- "%D{%F %T}" "%x:$$" "$level" "$*"
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
  local -a arg_files
  local -AU opts
  zparseopts -D -E -M -A opts h=-help -help v=-verbose -verbose \
    i:=-input    -input:       o:=-output    -output: \
    m:=-model    -model:       s:=-software  -software: \
    z:=-timezone -timezone:    @+:=arg_files -argfile+:=arg_files

  if (( ${+opts[--help]} )); then
    print -l -- "usage: ${SCRIPT_NAME}" "\t-v --verbose" "\t-h --help" \
    "\t-i --input    (default = current directory)" \
    "\t-o --output   (default = current directory)" \
    "\t-z --timezone (default = system timezone)" \
    "\t-s --software (default = system software)" \
    "\t-m --model    (default = system hardware)" \
    "\t-@ --argfile  arg files"
    return 0
  fi

  readonly input_dir=${opts[--input]:-$PWD}
  readonly output_dir=${opts[--output]:-$PWD}

  _sst::log DEBUG 'Validating if directories are valid...'
  # return 65: BSD EX_DATAERR
  [[ -d $input_dir ]] || { _sst::err 65 "Input is not a directory: '${input_dir}'" }
  [[ -d $output_dir ]] || { _sst::err 65 "Output is not a directory: '${output_dir}'" }
  _sst::log DEBUG 'Validated.'

  cd "$input_dir"

  _sst::log DEBUG 'Gathering filenames...'
  local -Ua pending_screenshots
  readonly pending_screenshots=( \
    ${~FILENAME_GLOB}.${~SORT_GLOB} \
    ${~FILENAME_GLOB}*.${~SORT_GLOB}
  )
  integer -r num_pending=${#pending_screenshots}
  if (( num_pending == 0 )); then
    # return 66: BSD EX_NOINPUT
    _sst::err 66 "No screenshots to process in '${input_dir}/'"
  fi
  local unit=screenshot
  if (( num_pending > 1 )); then
    unit+=s
  fi
  _sst::log INFO "Processing ${num_pending} ${unit}..."
  print -l -- "${(@)pending_screenshots}" >| "$SCREENSHOTS_LIST"

  local -Ua bg_pids

  local datetime; strftime -s datetime %Y%m%d_%H%M%S
  readonly archive_name="Screenshots_${datetime}.aar"
  aa archive ${opts[--verbose]:+-v} -a lz4 \
    -d "$input_dir" -o "${output_dir}/${archive_name}"\
    -include-path-list =(print -l -- "${(@)pending_screenshots}") \
    &>|"${TMPDIR%/}/aa.log" &
  integer -r aa_pid=$!; bg_pids+=($aa_pid)

  readonly model=${opts[--model]:-$(sysctl -n hw.model)}
  readonly software=${opts[--software]:-$(sw_vers --productVersion)}
  local timezone; strftime -s timezone %z
  readonly timezone=${opts[--timezone]:-$timezone}

  # PERL string replacement patterns that will be used by ExifTool
  readonly replacement_pattern="Filename;s/${DATETIME_RE}"
  readonly new_filename_pattern="\${${replacement_pattern}/${FILENAME_REPLACEMENT_RE}/}"
  readonly new_datetime_pattern="\${${replacement_pattern}/${DATETIME_REPLACEMENT_RE}${timezone}/}"

  _sst::log INFO 'Injecting metadata with `ExifTool`...'
  exiftool -o . -struct -preserve ${opts[--verbose]:+-verbose} \
    "-Directory=${output_dir}" \
    "-Software=${software}"             "-Model=${model}" \
    "-Filename<${new_filename_pattern}" \
    "-AllDates<${new_datetime_pattern}" \
    "-OffsetTime*=${timezone}" \
    '-MaxAvailHeight<ImageHeight'       '-MaxAvailWidth<ImageWidth' \
    '-RawFileName<FileName'             '-PreservedFileName<FileName' \
    "${(@)arg_files}" \
    -@ =(print -l -- "${(@)pending_screenshots}") \
    -- &>|"${TMPDIR%/}/et.log" &
  integer -r et_pid=$!; bg_pids+=($et_pid)

  {
    _sst::log DEBUG 'Waiting for archiving and metadata injection to finish...'
    # return 73: BSD EX_CANTCREAT
    wait $aa_pid || _sst::err 73 'Archiving failed' "$mapfile[${TMPDIR%/}/aa.log]"
    # return 70: BSD EX_SOFTWARE
    wait $et_pid || _sst::err 70 'ExifTool failed' "$mapfile[${TMPDIR%/}/et.log]"
  } always {
    integer -r status_code=$?

    rm -f -- "${TMPPREFIX}"* 2>/dev/null

    if (( status_code == 0 )); then
      rm -f -- "${(@)pending_screenshots}" "${TMPDIR%/}"/*.log
    elif (( status_code > 0 )); then
      kill ${(@)bg_pids} 2>/dev/null
      return $status_code
    fi
  }

  if (( ${+opts[--verbose]} )); then
    _sst::log INFO "Processed ${num_pending} ${unit}." \
      "'${input_dir:t2}/' → '${output_dir:t2}/'"
  fi

  return 0
}

################################################################################

if [[ $options[interactive] == on ]]; then
  sst "$@"
  return $?
fi

integer fd
exec {fd}>|"${LOCK_PATH}" && trap 'exec {fd}>&-' EXIT

if zsystem flock -t 0 -f $fd "${LOCK_PATH}"; then
  _sst::log INFO "Lock acquired; start..."
else
  # return 75: BSD EX_TEMPFAIL
  _sst::err 75 "Execution lock; exiting..."
fi

sleep $EXECUTION_DELAY  # Give time for all screenshots to be written to disk

msg=$(sst --verbose --input "$INPUT_DIR" --output "$OUTPUT_DIR" --model "${HW_MODEL}" \
  -@ "${ARG_FILES_DIR}/charlesmc.args" -@ "${ARG_FILES_DIR}/screenshot.args")

integer -r status_code=$?
if (( status_code == 0 )); then
  subtitle=Success
  sound=Glass
else
  subtitle="Failure (Exit Code: $status_code)"
  sound=Basso
fi

print -- "${=msg}"
osascript <<EOF
  display notification "${msg#*: }" \
  with title "${SCRIPT_NAME}" \
  subtitle "${subtitle}" \
  sound name "${sound}"
EOF
