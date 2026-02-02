# Print an error message, then return a status code.
# $1: The error code to return.
# $2: The error messages to print.
sst-err() {
  integer -r status_code=$1; shift
  sst-log ERROR $@

  return $status_code
}
