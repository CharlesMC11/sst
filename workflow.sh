#!/usr/bin/env -S zsh -f
# A script for preparing `add_metadata/main.sh`. It will be sourced by a
# Folder Action

readonly SCREENSHOTS_DIR=${HOME}/MyFiles/Pictures/Screenshots
readonly PIPE=${SCREENSHOTS_DIR}/add_metadata

readonly HOMEBREW_PREFIX=/opt/homebrew

readonly EXECUTABLE_DIR=${HOME}/.local/bin/process_screenshots
readonly TAG_FILES_DIR=${HOME}/.local/share/exiftool

export -Ua path
path=("$EXECUTABLE_DIR" "${HOMEBREW_PREFIX}/bin" "${HOMEBREW_PREFIX}/opt/libarchive/bin" ${==path})

################################################################################

if [[ -p $PIPE ]]; then
    echo "Pipe '${PIPE}' exists; Folder action already in progress" 1>&2
    exit 1
fi
# Taking multiple screenshots in succession causes the Folder Action to trigger
# the same amount of times. Checking for this temporary pipe in the `if`
# statement above ensures that only the first instance of the Folder Action
# executes the rest of the script body.
mkfifo "$PIPE" && trap 'rm "$PIPE"' EXIT

main --verbose --input "${SCREENSHOTS_DIR}/.tmp" --output "$SCREENSHOTS_DIR"\
    --tag "${TAG_FILES_DIR}/charlesmc.args"\
    --tag "${TAG_FILES_DIR}/screenshot.args"
