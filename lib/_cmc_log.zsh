# Print a log message
# $1: The log level: DEBUG | INFO | WARN | ERROR | CRITICAL
_cmc_log() {
  readonly level=${(U)1}; shift
  print -P -u ${log_fd:-1} -f "[%s]\t[%-8s]\t[%-5s]\t%s\n" -- "%D{%F %T}" "%x:$$" "$level" "$*"
}
