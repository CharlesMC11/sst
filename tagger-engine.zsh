#!/usr/bin/env -S zsh -f
# A script for renaming and adding metadata to screenshots

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL
setopt CHASE_LINKS
setopt WARN_CREATE_GLOBAL

setopt EXTENDED_GLOB
setopt NULL_GLOB
setopt NUMERIC_GLOB_SORT

zmodload zsh/datetime
zmodload zsh/files
zmodload zsh/mapfile
zmodload zsh/zutil

readonly DATE_FILTER_RE='<19-21><-9><-9>[^[:digit:]]#<-1><-9>[^[:digit:]]#<-3><-9>'
readonly TIME_FILTER_RE='<-2><-9>[^[:digit:]]#<-5><-9>[^[:digit:]]#<-5><-9>'
readonly FILENAME_FILTER_RE="[^[:digit:]]#${~DATE_FILTER_RE}[^[:digit:]]#${~TIME_FILTER_RE}"
readonly FILENAME_SORTING_RE='*(.Om)'

readonly DATE_EXTRACTOR_RE='([1-2][^2-8])?(\d{2})\D?([0-1]\d)\D?([0-3]\d)'
readonly TIME_EXTRACTOR_RE='([0-2]\d)\D?([0-5]\d)\D?([0-5]\d)'
readonly DATETIME_EXTRACTOR_RE="^.*?${DATE_EXTRACTOR_RE}\D*?${TIME_EXTRACTOR_RE}(\D*?\d*?\D*?)\..+$"
readonly FILENAME_REPLACEMENT_RE='$2$3$4_$5$6$7$8.%e'
readonly DATETIME_REPLACEMENT_RE='$1$2-$3-$4T$5:$6:$7'

_tagger-engine::show_usage () {
    print -l -- "usage: ${0:t:r}"\
    "\t-v --verbose"\
    "\t-h --help"\
    "\t-i --input    (default = current directory)"\
    "\t-o --output   (default = current directory)"\
    "\t-z --timezone (default = system timezone)"\
    "\t-s --software (default = system software)"\
    "\t-m --model    (default = system hardware)"\
    "\t-@ --argfile  arg files"
}

# $1: "Input" or "Output"
# $2: An input or output directory
_tagger-engine::error_if_not_dir () {
    if [[ ! -d $2 ]]; then
        print -u 2 -- "${SCRIPT_NAME}: $1 is not a directory: '$2'"
        _show_usage
        return 66 # BSD: Cannot open input
    fi
    return 0
}

################################################################################

tagger-engine::main() {
    local -a arg_files
    local -AU opts
    zparseopts -D -E -M -A opts h=-help -help v=-verbose -verbose\
        i:=-input    -input:       o:=-output    -output:\
        m:=-model    -model:       s:=-software  -software:\
        z:=-timezone -timezone:    @+:=arg_files -argfile+:=arg_files

    if (( ${+opts[--help]} )); then
        _tagger-engine::show_usage
        return 0
    fi

    readonly input_dir=${opts[--input]:-$PWD}
    readonly output_dir=${opts[--output]:-$PWD}

    _tagger-engine::error_if_not_dir Input "$input_dir"
    _tagger-engine::error_if_not_dir Output "$output_dir"

    cd "$input_dir"

    readonly model=${opts[--model]:-${HW_MODEL:-$(sysctl -n hw.model)}}
    readonly software=${opts[--software]:-$(sw_vers --productVersion)}
    local timezone; strftime -s timezone %z
    readonly timezone=${opts[--timezone]:-$timezone}

    local -Ua pending_screenshots
    readonly pending_screenshots=( \
        ${~FILENAME_FILTER_RE}.${~FILENAME_SORTING_RE} \
        ${~FILENAME_FILTER_RE}*.${~FILENAME_SORTING_RE}
    )
    if (( ${#pending_screenshots} == 0 )); then
        print -u 2 -- "${SCRIPT_NAME}: No screenshots to process in '${input_dir}/'"
        return 65 #BSD: Data format error
    fi

    typeset -gUa bg_pids

    _cleanup () {
        for pid in $bg_pids; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
            fi
        done
        rm -f *.log
    }

    trap _cleanup EXIT TERM

    local datetime; strftime -s datetime %Y%m%d_%H%M%S
    readonly archive_name="Screenshots_${datetime}.aar"
    aa archive ${opts[--verbose]:+-v} -a lz4 -d "$input_dir" \
        -o "${output_dir}/${archive_name}"\
        -include-path-list <(print -l -- "${pending_screenshots[@]}") \
        2>>aa.log 1>>aa.log &
    integer -r aa_pid=$!
    bg_pids+=($aa_pid)

    # PERL string replacement patterns that will be used by ExifTool
    readonly replacement_pattern="Filename;s/${DATETIME_EXTRACTOR_RE}"
    readonly new_filename_pattern="\${${replacement_pattern}/${FILENAME_REPLACEMENT_RE}/}"
    readonly new_datetime_pattern="\${${replacement_pattern}/${DATETIME_REPLACEMENT_RE}${timezone}/}"

    exiftool "-Directory=${output_dir}"          "-Filename<${new_filename_pattern}"\
            "-AllDates<${new_datetime_pattern}" "-OffsetTime*=${timezone}"\
            '-MaxAvailHeight<ImageHeight'       '-MaxAvailWidth<ImageWidth'\
            "-Software=${software}"             "-Model=${model}"\
            '-RawFileName<FileName'             '-PreservedFileName<FileName'\
            -struct          -preserve          ${opts[--verbose]:+-verbose}\
            "${arg_files[@]}"                   --\
            "${pending_screenshots[@]}"         2>>exiftool.log 1>>exiftool.log &
    integer -r et_pid=$!
    bg_pids+=($et_pid)

    if ! wait $aa_pid; then
        print -l -u 2 -- "${SCRIPT_NAME}: Archiving failed" "$mapfile[aa.log]"
        return 70 # BSD: Internal software error
    fi

    if ! wait $et_pid; then
        print -l -u 2 -- "${SCRIPT_NAME}: ExifTool failed" "$mapfile[et.log]"
        return 70 # BSD: Internal software error
    fi

    rm -f "${pending_screenshots[@]}"
    if (( ${+opts[--verbose]} )); then
        print -- "${SCRIPT_NAME}: Created archive: '${output_dir:t}/${archive_name}'"
    fi

    return 0
}

if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then
    tagger-engine::main $@
fi