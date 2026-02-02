sst-notify(){
  integer -r status_code=$1
  if (( status_code == 0 )); then
    subtitle='📷 Success'
    sound=Glass
  else
    subtitle="⚠️ Failure: $status_code"
    sound=Basso
  fi

  readonly msg="${${(f)mapfile[$LOG_FILE]}[-1]}"
  "$OSASCRIPT" -e "display notification \"${msg##*\]?}\" with title \"${SERVICE_NAME}\" subtitle \"${subtitle}\" sound name \"${sound}\""
}
