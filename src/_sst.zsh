_sst() {
  : >!"$LOG_FILE" >!"$PROCESSED_LIST" >!"$EXIFTOOL_LOG" >!"$AA_LOG"

  local buf; sysread buf
  local -Ua pending_screenshots; pending_screenshots=( "${(@)${(f)buf}}" )
  integer -r pending_count=${#pending_screenshots}

  if (( pending_count == 0 )); then
    # return 66: BSD EX_NOINPUT
    _cmc_err 66 "No screenshots to process: '${INPUT_DIR:A}/'"
  fi
  local unit='screenshot'
  if (( pending_count > 1 )); then unit+='s'; fi

  local -r current_month="${(%):-%D{%Y-%m}"
  local -r archive_name="Screenshots_${current_month}.aar"

  local -r timezone="${(%):-%D{%z}"
  local -r new_datetime_pattern="\${${REPLACEMENT_PATTERN}/${DATETIME_REPLACEMENT_RE}${timezone}/}"
  local -r new_filename_pattern="\${${REPLACEMENT_PATTERN}/${FILENAME_REPLACEMENT_RE}/}"

  local -r exiftool_args=(
    -struct -preserve -verbose
    -o "${OUTPUT_DIR}/${current_month}/"
    '-RawFileName<FileName'             '-PreservedFileName<FileName'
    '-MaxAvailHeight<ImageHeight'       '-MaxAvailWidth<ImageWidth'
    "-Model=${HW_MODEL}"                "-Software=${OS_VER}"
    "-OffsetTime*=${timezone}"          "-AllDates<${new_datetime_pattern}"
    "-Filename<${new_filename_pattern}%-c.%e"
    -@ "${ARG_FILES_DIR}/charlesmc.args"
    -@ "${ARG_FILES_DIR}/screenshot.args"
  )

  _cmc_log INFO "Processing ${pending_count} ${unit}"
  {
    if (( pending_count <= 15 )); then
      _cmc_log INFO 'Processing serially'

      "$EXIFTOOL" "${(@)exiftool_args}" -- "${(@)pending_screenshots}" \
        &>>!"$EXIFTOOL_LOG"
    else
      _cmc_log INFO 'Processing in parallel'

      # "$OSASCRIPT" -e "display notification \
      #   \"Processing ${pending_count} ${unit} in parallel\" with title \
      #   \"$SERVICE_NAME\" sound name \"Glass\""

      zargs -P $PERFORMANCE_CORE_COUNT -- "${(@)pending_screenshots}" -- \
        "$EXIFTOOL" "${(@)exiftool_args}" --
    fi

    print -l -- "${(@)pending_screenshots:t}" >>! "$PROCESSED_LIST"

    local aa_cmd=archive
    if [[ -f $archive_name ]]; then aa_cmd=update; fi
    _cmc_log INFO 'Archiving originals'
    "$AA" $aa_cmd -v -d "$INPUT_DIR" -o "${OUTPUT_DIR}/${archive_name}" -a lz4 \
      -t $PERFORMANCE_CORE_COUNT -include-path-list "$PROCESSED_LIST" \
      &>>!"$AA_LOG" || \
      _cmc_err 73 "Apple Archive Failed: ${(j: ⏎ :)${(f)mapfile[$AA_LOG]}}"
      # return 73: BSD EX_CANTCREAT
  } always {
    integer -r status_code=$?

    _cmc_log DEBUG "Status Code: ${status_code}"

    if (( status_code == 0 )); then
      local -Ua processed_screenshots
      processed_screenshots=( "${(@)${(f)mapfile[$PROCESSED_LIST]}/#/${INPUT_DIR:A}/}" )
      rm -f "${(@)processed_screenshots}"

      _cmc_log INFO "Processed ${pending_count} ${unit}"
    elif (( status_code > 0 )); then
      _cmc_err $status_code "An error occurred during processing"

      kill $et_pid 2>/dev/null
      return $status_code
    fi
  }

  return 0
}
