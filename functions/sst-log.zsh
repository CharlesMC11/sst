# Print a log message
# $1: The log level: DEBUG | INFO | WARN | ERROR | CRITICAL
sst-log() {
  readonly level=${(U)1}; shift

  print -P -u $log_fd -f "[%s]\t[%-8s]\t[%-5s]\t%s\n" -- "%D{%F %T}" "${SERVICE_NAME}:$$" "$level" "$*"
}
