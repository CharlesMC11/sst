cmc_ls_images() {
  readonly directory=${${1:-$PWD}:A}
  if [[ ! -d $directory ]]; then
    # return 65: BSD EX_NOINPUT
    _cmc_err 65 "Directory not found: '${directory}/'"
  fi
  _cmc_log DEBUG "Listing images in '${directory}/'"

  print -l -- "${directory}"/*.png(nOm.N)
}
