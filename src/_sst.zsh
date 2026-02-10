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

  {
    "$EXIFTOOL" "${(@)exiftool_args}" >>!"$EXIFTOOL_LOG" 2>&1 &
    integer -r et_pid=$!

    local message="${SERVICE_NAME} BEGIN"
    print -l -- -echo4 "$message" -execute >!"$PENDING_LIST"

    integer timeout=60
    while ! grep -q -e "$message" "$EXIFTOOL_LOG" &>/dev/null; do
      if (( timeout-- <= 0 )); then
        # return 69: BSD EX_UNAVAILABLE
        _cmc_err 69 "ExifTool could not be ready in time"
      fi

      _cmc_log DEBUG 'Waiting for ExifTool to be ready...'
      sleep 0.1
    done
    _cmc_log INFO "ExifTool:${et_pid} started"

    integer count=0
    if ! while IFS= read -r -t -u 0 file; do
      if [[ -z $file ]]; then
        _cmc_log DEBUG 'Skipping empty filename'
        continue
      fi

      _cmc_log INFO "Submitting: '${file:t}'"
      print -l -- "$file" '-execute' >>!"$PENDING_LIST"
      (( ++count ))
    done; then
      # return 66: BSD EX_NOINPUT
      _cmc_err 66 "No screenshots to process: '${INPUT_DIR}/'"
    fi

    message="${SERVICE_NAME} END"
    print -l -- -echo4 "$message" -execute >>!"$PENDING_LIST"
    while ! grep -q -e "$message" "$EXIFTOOL_LOG" &>/dev/null; do
      _cmc_log DEBUG 'Waiting for ExifTool to finish processing...'
      sleep 0.1
    done
    print -l -- '-stay_open' 'False' >>!"$PENDING_LIST"

    local unit=screenshot
    if (( count > 1 )); then
      unit+=s
    fi
    _cmc_log INFO "Submitted ${count} ${unit} to ExifTool:${et_pid}"
    grep -q "$INPUT_DIR" "$PENDING_LIST" >! "${TMPDIR}/processed.txt"

    local -r archive_name="Screenshots_${current_month}.aar"
    local aa_cmd=archive
    if [[ -f $archive_name ]]; then
      aa_cmd=update
    fi

    _cmc_log INFO 'Archiving original files...'
    "$AA" $aa_cmd -v -a lz4 -d "$INPUT_DIR" -o "${OUTPUT_DIR}/${archive_name}"\
      -include-path-list "${TMPDIR}/processed.txt" &>!"$AA_LOG" || \
      _cmc_err 73 "Apple Archive Failed: ${(j: ⏎ :)${(f)mapfile[$AA_LOG]}}"
      # return 73: BSD EX_CANTCREAT
  } always {
    integer -r status_code=$?

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
