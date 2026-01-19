#!/usr/bin/env -S zsh -f
# A script for preparing `shot-processor.zsh`. It will be called by `launchd`

setopt ERR_EXIT
setopt NO_UNSET

readonly LOCK=${TMPDIR}${USER}.screenshot-tagger.lock

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

if ! mkdir "$LOCK" 2>/dev/null; then
    echo 'Lock exists; script already in progress...' >&2
    exit 1
fi
# Taking multiple screenshots in succession causes the `launchd` to trigger the
# same amount of times. Checking for this lock in the `if` statement above
# ensures that only the first instance of the script executes the rest of the
# script body.
trap 'rm -rf "$LOCK"' EXIT

sleep $EXECUTION_DELAY # Give time for all screenshots to be written to disk

if [[ -f ${EXECUTABLE_DIR}/.env ]]; then
    source "${EXECUTABLE_DIR}/.env"
else
    echo 'Environment file not found; exiting...' >&2
    exit 2
fi

result=$(tagger-engine --verbose --input "${INPUT_DIR}" --output "${OUTPUT_DIR}"\
    -@ "${ARG_FILES_DIR}/charlesmc.args" -@ "${ARG_FILES_DIR}/screenshot.args" 2>&1)
integer -r exit_status=$?
readonly msg=$(echo "$result" | tail -n 1)

if (( exit_status == 0 )); then
    subtitle=Success
    sound=Glass
else
    subtitle="Failure ($exit_status)"
    sound=Basso
fi

osascript <<EOF &!
    display notification "${msg}" with title "Screenshot Tagger" subtitle "${subtitle}" sound name "${sound}"
EOF