#!/usr/bin/env -S zsh -f
# A script for preparing `tagger-engine`. It will be called by `launchd`

setopt CHASE_LINKS
setopt ERR_EXIT
setopt NO_UNSET
setopt WARN_CREATE_GLOBAL
setopt NO_NOTIFY
setopt NO_BEEP

zmodload zsh/files

readonly LOCK=${TMPDIR}${USER}.${0:t:r}.lock

readonly HOMEBREW_PREFIX=/opt/homebrew

readonly EXECUTABLE_DIR=${HOME}/.local/bin/screenshot-tagger
readonly ARG_FILES_DIR=${HOME}/.local/share/exiftool

float -r EXECUTION_DELAY=0.5

export -Ua path
path=(
    "$EXECUTABLE_DIR"
    "${HOMEBREW_PREFIX}/bin"
    "${HOMEBREW_PREFIX}/opt/libarchive/bin"
    ${==path}
)

################################################################################

# Taking multiple screenshots in succession causes `launchd` to trigger the same
# amount of times. Checking for this lock in the `if` statement above ensures
# that only the first instance of the script executes the rest of the script
# body.
if mkdir -m 000 "$LOCK" 2>/dev/null; then
    trap 'rmdir "$LOCK"' EXIT
else
    print -u 2 -- 'Lock exists; exiting...'
    exit 1
fi

sleep $EXECUTION_DELAY # Give time for all screenshots to be written to disk

if [[ -f ${EXECUTABLE_DIR}/config.zsh ]]; then
    source "${EXECUTABLE_DIR}/config.zsh"
else
    print -u 2 -- 'Environment file not found; exiting...'
    exit 2
fi

local engine_output
engine_output=$(tagger-engine --verbose --input "${INPUT_DIR}"\
    --output "${OUTPUT_DIR}" -@ "${ARG_FILES_DIR}/charlesmc.args"\
    -@ "${ARG_FILES_DIR}/screenshot.args" 2>&1)

integer -r exit_status=$?
if (( exit_status == 0 )); then
    subtitle=Success
    sound=Glass
else
    subtitle="Failure (Error: $exit_status)"
    sound=Basso
fi

readonly msg=$(print -- "$engine_output" | tail -n 1)
osascript <<EOF
    display notification "${msg}" with title "Screenshot Tagger" subtitle "${subtitle}" sound name "${sound}"
EOF
