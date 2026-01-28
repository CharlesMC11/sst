#!/opt/homebrew/bin/zsh -f
# A script for adding certain metadata to screenshots, then renaming them.

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL
setopt CHASE_LINKS
setopt WARN_CREATE_GLOBAL

setopt NO_NOTIFY
setopt NO_BEEP

setopt EXTENDED_GLOB
setopt NULL_GLOB
setopt NUMERIC_GLOB_SORT

zmodload zsh/datetime
zmodload zsh/files
zmodload zsh/parameter
zmodload zsh/mapfile
zmodload zsh/system
zmodload zsh/zutil

readonly SCRIPT_NAME=${0:t:r}

readonly DATE_GLOB='<1900-2199>-<01-12>-<01-31>'
readonly TIME_GLOB='<00-23>.<00-59>.<00-59>'
readonly FILENAME_GLOB="Screenshot ${~DATE_GLOB} at ${~TIME_GLOB}"
readonly FILENAME_SORTING_GLOB='*(.Om)'

readonly DATE_RE='(\d{2})(\d{2})-(\d{2})-(\d{2})'
readonly TIME_RE='(\d{2})\.(\d{2})\.(\d{2})'
readonly DATETIME_RE="^Screenshot ${DATE_RE} at ${TIME_RE}(\D*?\d*?\D*?)\..+$"
readonly FILENAME_REPLACEMENT_RE='$2$3$4_$5$6$7$8.%e'
readonly DATETIME_REPLACEMENT_RE='$1$2-$3-$4T$5:$6:$7'

# Show the options menu.
_sst::help() {
  print -l -- "usage: ${SCRIPT_NAME}" "\t-v --verbose" "\t-h --help" \
  "\t-i --input    (default = current directory)" \
  "\t-o --output   (default = current directory)" \
  "\t-z --timezone (default = system timezone)" \
  "\t-s --software (default = system software)" \
  "\t-m --model    (default = system hardware)" \
  "\t-@ --argfile  arg files"
}

# Print a log message
# $1: The log level: DEBUG | INFO | WARN | ERROR | CRITICAL
_sst::log() {
  readonly level=${(U)1}
  shift
  local datetime; strftime -s datetime '%F %T%z'

  integer fd=1
  [[ $level == (WARN|ERROR) ]] && fd=2

  print -u $fd -f "[%s]\t[%s]\t[%s]\t%s\n" -- "$datetime" "${SCRIPT_NAME}:$$" "$level" "$*"
}

# Print an error message, then return a status code.
# $1: The error code to return.
# $2: The error messages to print.
_sst::err() {
  integer -r status_code=$1
  shift

  _sst::log ERROR $@

  return $status_code
}

# Return an error code if the given is not a directory.
# $1: "Input" or "Output"
# $2: An input or output directory
_sst::is_directory() {
  if [[ -d $2 ]]; then
    return 0
  fi
  # return 65: BSD EX_DATAERR
  _sst::err 65 "$1 is not a directory: '$2'"
}

sst() {
  local -a arg_files
  local -AU opts
  zparseopts -D -E -M -A opts h=-help -help v=-verbose -verbose \
    i:=-input    -input:       o:=-output    -output: \
    m:=-model    -model:       s:=-software  -software: \
    z:=-timezone -timezone:    @+:=arg_files -argfile+:=arg_files

  if (( ${+opts[--help]} )); then
    _sst::help
    return 0
  fi

  readonly input_dir=${opts[--input]:-$PWD}
  readonly output_dir=${opts[--output]:-$PWD}

  _sst::is_directory Input "$input_dir"
  _sst::is_directory Output "$output_dir"

  cd "$input_dir"

  local -Ua pending_screenshots
  readonly pending_screenshots=( \
    ${~FILENAME_GLOB}.${~FILENAME_SORTING_GLOB} \
    ${~FILENAME_GLOB}*.${~FILENAME_SORTING_GLOB}
  )
  integer -r num_screenshots=${#pending_screenshots}
  if (( num_screenshots == 0 )); then
    # return 66: BSD EX_NOINPUT
    _sst::err 66 "No screenshots to process in '${input_dir}/'"
  fi

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
    local unit=screenshot
    if (( num_screenshots > 1 )); then
      unit+=s
    fi
    _sst::log INFO "Processed ${num_screenshots} ${unit}." \
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
  _sst::log INFO "Lock created in '${LOCK_PATH:h}/'; starting..."
else
  # return 75: BSD EX_TEMPFAIL
  _sst::err 75 "Lock exists in '${LOCK_PATH:h}/'; exiting..."
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
