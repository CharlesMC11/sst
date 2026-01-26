#!/opt/homebrew/bin/zsh -f
# A script for adding certain metadata to screenshots, then renaming them.

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL
setopt CHASE_LINKS
setopt WARN_CREATE_GLOBAL

setopt EXTENDED_GLOB
setopt NULL_GLOB
setopt NUMERIC_GLOB_SORT

zmodload zsh/datetime
zmodload zsh/files
zmodload zsh/mapfile
zmodload zsh/zutil

readonly DATE_GLOB='<1900-2199>-<01-12>-<01-31>'
readonly TIME_GLOB='<00-23>.<00-59>.<00-59>'
readonly FILENAME_GLOB="Screenshot ${~DATE_GLOB} at ${~TIME_GLOB}"
readonly FILENAME_SORTING_GLOB='*(.Om)'

readonly DATE_RE='([1-2][^2-8])(\d{2})-([0-1]\d)-([0-3]\d)'
readonly TIME_RE='([0-2]\d)\.([0-5]\d)\.([0-5]\d)'
readonly DATETIME_RE="^Screenshot ${DATE_RE} at ${TIME_RE}(\D*?\d*?\D*?)\..+$"
readonly FILENAME_REPLACEMENT_RE='$2$3$4_$5$6$7$8.%e'
readonly DATETIME_REPLACEMENT_RE='$1$2-$3-$4T$5:$6:$7'

readonly TAGGER_ENGINE_NAME=tagger-engine

# Show the options menu.
_tagger-engine::help () {
  print -l -- "usage: ${TAGGER_ENGINE_NAME}" \
  "\t-v --verbose" \
  "\t-h --help" \
  "\t-i --input    (default = current directory)" \
  "\t-o --output   (default = current directory)" \
  "\t-z --timezone (default = system timezone)" \
  "\t-s --software (default = system software)" \
  "\t-m --model    (default = system hardware)" \
  "\t-@ --argfile  arg files"
}

# Print an log message, then return a status code.
# $1: The error code to return.
# $2: The error messages to print.
_tagger-engine::err () {
  integer status=$1
  shift

  local datetime; strftime -s datetime %Y-%m-%d %H:%M:%S
  print -l -u 2 -- "${TAGGER_ENGINE_NAME}: [$datetime] $@"

  _tagger-engine::help

  return $status
}

# Return an error code if the given is not a directory.
# $1: "Input" or "Output"
# $2: An input or output directory
_tagger-engine::is_directory () {
  [[  -d $2 ]] && return 0
  # return 65: BSD EX_DATAERR
  _tagger-engine::err 65 "$1 is not a directory: '$2'"
}

################################################################################

tagger-engine () {
  local -a arg_files
  local -AU opts
  zparseopts -D -E -M -A opts h=-help -help v=-verbose -verbose \
    i:=-input    -input:       o:=-output    -output: \
    m:=-model    -model:       s:=-software  -software: \
    z:=-timezone -timezone:    @+:=arg_files -argfile+:=arg_files

  (( ${+opts[--help]} )) && { _tagger-engine::help; return 0 }

  readonly input_dir=${opts[--input]:-$PWD}
  readonly output_dir=${opts[--output]:-$PWD}

  _tagger-engine::is_directory Input "$input_dir"
  _tagger-engine::is_directory Output "$output_dir"

  cd "$input_dir"

  local -Ua pending_screenshots
  readonly pending_screenshots=( \
    ${~FILENAME_GLOB}.${~FILENAME_SORTING_GLOB} \
    ${~FILENAME_GLOB}*.${~FILENAME_SORTING_GLOB}
  )
  if (( ${#pending_screenshots} == 0 )); then
    # return 66: BSD EX_NOINPUT
    _tagger-engine::err 66 "No screenshots to process in '${input_dir}/'"
  fi

  local -Ua bg_pids

  local datetime; strftime -s datetime %Y%m%d_%H%M%S
  readonly archive_name="Screenshots_${datetime}.aar"
  aa archive ${opts[--verbose]:+-v} \
    -a lz4 \
    -d "$input_dir" \
    -o "${output_dir}/${archive_name}"\
    -include-path-list =(print -l -- "${pending_screenshots[@]}") \
    &>|${TMPDIR%/}/aa.log &
  integer -r aa_pid=$!
  bg_pids+=($aa_pid)

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
    "${arg_files[@]}" \
    -@ =(print -l -- "${pending_screenshots[@]}") \
    -- &>|${TMPDIR%/}/et.log &
  integer -r et_pid=$!
  bg_pids+=($et_pid)

  {
    # return 73: BSD EX_CANTCREAT
    wait $aa_pid || _tagger-engine::err 73 "Archiving failed" "$mapfile[${TMPDIR%/}/aa.log]"
    # return 70: BSD EX_SOFTWARE
    wait $et_pid || _tagger-engine::err 70 "ExifTool failed" "$mapfile[${TMPDIR%/}/et.log]"
  } always {
    integer status=$?
    if (( $status > 0 )); then
      kill $bg_pids &>/dev/null
      return $status
    fi
  }

  rm -f -- "${pending_screenshots[@]}" ${TMPDIR%/}/*.log
  (( ${+opts[--verbose]} )) && print -- "${TAGGER_ENGINE_NAME}: Created archive: '${output_dir:t}/${archive_name}'"

  return 0
}

if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then
  tagger-engine $@
fi
