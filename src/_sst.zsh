_sst() {
  : >!"$PROCESSED_LIST" >!"$EXIFTOOL_LOG" >!"$AA_LOG"

  local -r current_month="${(%):-%D{%Y-%m}"
  local -r exiftool_args=(
    -stay_open True -@ "$PENDING_LIST" -common_args -struct -preserve -verbose
    -o "${OUTPUT_DIR}/${current_month}/"
    '-RawFileName<FileName'             '-PreservedFileName<FileName'
    '-MaxAvailHeight<ImageHeight'       '-MaxAvailWidth<ImageWidth'
    "-Model=${HW_MODEL}"                "-Software=${OS_VER}"
    "-OffsetTime*=${(%):-%D{%z}"        '-AllDates<FileModifyDate'
    -d '%y%m%d_%H%M%S'                  '-Filename<${FileModifyDate}%-c.%e'
    -@ "${ARG_FILES_DIR}/charlesmc.args"
    -@ "${ARG_FILES_DIR}/screenshot.args"
  )

  "$EXIFTOOL" "${(@)exiftool_args}" &>>!"$EXIFTOOL_LOG" &
  integer -r et_pid=$!
  _cmc_log DEBUG "Started ExifTool in the backround (PID: ${et_pid})"

  exec {pending_fd}>>!"$PENDING_LIST"
  exec {processed_fd}>>!"$PROCESSED_LIST"

  print -l -u $pending_fd -- '-echo2' 'ExifTool STARTED'

  {
    integer count=0
    if ! while IFS= read -r -t -u 0 file; do
      if [[ -z $file ]]; then
        _cmc_log DEBUG 'Skipping empty filename'
        continue
      fi

      _cmc_log INFO "Submitting: '${file:t}'"
      print -l -u $pending_fd -- "$file" '-execute'
      print -u $processed_fd -- "${file:t}"
      (( ++count ))
    done; then
      # return 66: BSD EX_NOINPUT
      _cmc_err 66 "No screenshots to process: '${INPUT_DIR:A}/'"
    fi
    print -l -u $pending_fd -- '-echo3' 'ExifTool Finished' '-stay_open' 'False' '-echo3' 'pahabol'

    local unit=screenshot
    if (( count > 1 )); then
      unit+=s
    fi
    _cmc_log INFO "Submitted ${count} ${unit} to ExifTool (PID:${et_pid})"

    local -r archive_name="Screenshots_${current_month}.aar"
    local aa_cmd=archive
    if [[ -f $archive_name ]]; then
      aa_cmd=update
    fi

    _cmc_log INFO 'Archiving original files...'
    "$AA" $aa_cmd -v -a lz4 -d "$INPUT_DIR" -o "${OUTPUT_DIR}/${archive_name}"\
      -include-path-list "$PROCESSED_LIST" &>>!"$AA_LOG" || \
      _cmc_err 73 "Apple Archive Failed: ${(j: ⏎ :)${(f)mapfile[$AA_LOG]}}"
      # return 73: BSD EX_CANTCREAT

    wait $et_pid || true
  } always {
    integer -r status_code=$?

    exec {pending_fd}>&-
    exec {processed_fd}>&-

    _cmc_log DEBUG "Status Code: ${status_code}"

    if (( status_code == 0 )); then
      : >!"$PENDING_LIST" >!"$EXIFTOOL_LOG"

      # rm -f "${(f)${mapfile[${TMPDIR}/processed.txt]}}" || \
      #   _cmc_log WARN "Failed to remove original screenshots"

      _cmc_log INFO "Processed ${count} ${unit}"
    elif (( status_code > 0 )); then
      kill $et_pid 2>/dev/null
      return $status_code
    fi
  }

  return 0
}
