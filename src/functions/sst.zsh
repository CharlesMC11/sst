sst() {
  cd "$INPUT_DIR"

  local -Ua pending_screenshots
  readonly pending_screenshots=( *.png(nOm.N) )
  integer -r num_pending=${#pending_screenshots}
  if (( num_pending == 0 )); then
    # return 66: BSD EX_NOINPUT
    sst-err 66 "No screenshots to process in '${INPUT_DIR}/'"
  fi
  local unit=screenshot
  if (( num_pending > 1 )); then
    unit+=s
  fi
  sst-log INFO "Processing ${num_pending} ${unit}..."
  print -l -- "${(@)pending_screenshots}" >|"$PENDING_LIST"

  local -Ua bg_pids

  readonly current_month="${(%):-%D{%Y-%m}"

  readonly archive_name="Screenshots_${current_month}.aar"
  local aa_cmd=archive
  [[ -f $archive_name ]] && aa_cmd=append

  sst-log INFO 'Archiving original files in the background...'
  "$AA" $aa_cmd -v -a lz4 -d "$INPUT_DIR" -o "${OUTPUT_DIR}/${archive_name}"\
    -include-path-list "$PENDING_LIST" &>|"$AA_LOG" &
  integer -r aa_pid=$!; bg_pids+=($aa_pid)

  sst-log INFO 'Injecting metadata in the background...'
  "$EXIFTOOL" -o "${OUTPUT_DIR}/${current_month}/" -struct -preserve -verbose \
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
    sst-log DEBUG 'Waiting for background tasks to finish...'
    # return 73: BSD EX_CANTCREAT
    wait $aa_pid || sst-err 73 "Apple Archive Failed: ${(j: ⏎ :)${(f)mapfile[$AA_LOG]}}"
    # return 70: BSD EX_SOFTWARE
    wait $et_pid || sst-err 70 "ExifTool Failed: ${(j: ⏎ :)${(f)mapfile[$EXIFTOOL_LOG]}}"
  } always {
    integer -r status_code=$?

    if (( status_code == 0 )); then
      sst-log INFO 'Archiving and tagging successful'

      rm -f -- "${(@)pending_screenshots}"
      : >!"$PENDING_LIST" >!"$AA_LOG" >!"$EXIFTOOL_LOG"

      sst-log INFO "Processed ${num_pending} ${unit}"
    elif (( status_code > 0 )); then
      kill ${(@)bg_pids} 2>/dev/null
      return $status_code
    fi
  }

  return 0
}