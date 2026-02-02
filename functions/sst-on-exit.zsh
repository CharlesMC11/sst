sst-on-exit() {
  sst-log DEBUG 'Moving temporary logs to system log'

  exec {log_fd}>&-

  if [[ -s $LOG_FILE ]]; then
    print -- "$mapfile[$LOG_FILE]" >>! "$SYSTEM_LOG"
    >!"$LOG_FILE"
  fi
}
