# Print an error message, then return a status code.
# $1: The error code to return.
# $2: The error messages to print.
_cmc_err() {
  integer -r code=$1; shift
  _cmc_log ERROR "$* (Code: $code)"

  return $code
}
