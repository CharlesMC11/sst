#!/usr/bin/env -S zsh -f
# A script for renaming and adding metadata to screenshots

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

setopt EXTENDED_GLOB
setopt NULL_GLOB
setopt NUMERIC_GLOB_SORT

readonly SCRIPT_NAME=${0:t}

readonly DATE_FILTER_RE='<19-21><-9><-9>[^[:digit:]]#<-1><-9>[^[:digit:]]#<-3><-9>'
readonly TIME_FILTER_RE='<-2><-9>[^[:digit:]]#<-5><-9>[^[:digit:]]#<-5><-9>'
readonly FILENAME_FILTER_RE="[^[:digit:]]#${~DATE_FILTER_RE}[^[:digit:]]#${~TIME_FILTER_RE}"
readonly FILENAME_SORTING_RE='*(.Om)'

readonly DATE_EXTRACTOR_RE='([1-2][^2-8])?(\d{2})\D?([0-1]\d)\D?([0-3]\d)'
readonly TIME_EXTRACTOR_RE='([0-2]\d)\D?([0-5]\d)\D?([0-5]\d)'
readonly DATETIME_EXTRACTOR_RE="^.*?${DATE_EXTRACTOR_RE}\D*?${TIME_EXTRACTOR_RE}(\D*?\d*?\D*?)\..+$"
readonly FILENAME_REPLACEMENT_RE='$2$3$4_$5$6$7$8.%e'
readonly DATETIME_REPLACEMENT_RE='$1$2-$3-$4T$5:$6:$7'

show_usage () {
    echo "usage: ${SCRIPT_NAME}\n\
    -v  --verbose\n\
    -h  --help\n\
    -i  --input    (default = current directory)\n\
    -o  --output   (default = current directory)\n\
    -tz --timezone (default = system timezone)\n\
    -sw --software (default = system software)\n\
    -hw --hardware (default = system hardware)\n\
    -tg --tag      arg files"
}

error_on_invalid_option () {
    echo "${SCRIPT_NAME}: invalid option -- $1" 1>&2
    show_usage
    exit 1
}

# Exit with 2 if the arg is not a directory
# $1: "Input" or "Output"
# $2: An input or output directory
error_if_not_dir () {
    if [[ ! -d $2 ]]; then
        echo "$1 is not a directory: $2" 1>&2
        show_usage
        exit 2
    fi

    return 0
}

################################################################################

integer verbose_mode=0
output_dir=$PWD
timezone=$(date +%z)
software=$(sw_vers --productVersion)
hardware=$(system_profiler SPHardwareDataType | sed -En 's/^.*Model Name: //p')
declare -Ua arg_files
while (($#)); do
    case $1 in
        -h  | --help    ) show_usage; exit
        ;;
        -v  | --verbose ) verbose_mode=1; shift
        ;;
        -i  | --input   ) error_if_not_dir Input $2; cd "$2"; shift 2
        ;;
        -o  | --output  ) error_if_not_dir Output $2; output_dir=$2; shift 2
        ;;
        -tz | --timezone) timezone=$2; shift 2
        ;;
        -sw | --software) software=$2; shift 2
        ;;
        -hw | --hardware) hardware=$2; shift 2
        ;;
        -tg | --tag     ) arg_files+="-@ $2"; shift 2
        ;;
        -*  | --*       ) error_on_invalid_option $1
        ;;
        *               ) error_on_invalid_option $1
        ;;
    esac
done

typeset -Ua pending_screenshots
readonly pending_screenshots=(${~FILENAME_FILTER_RE}.${~FILENAME_SORTING_RE} ${~FILENAME_FILTER_RE}*.${~FILENAME_SORTING_RE})
if ! (( ${#pending_screenshots} )); then
    echo "No screenshots to process: ${input_dir:t2}" 1>&2
    exit 3
fi

# PERL string replacement patterns that will be used by ExifTool
readonly replacement_pattern="Filename;s/${DATETIME_EXTRACTOR_RE}"
readonly new_filename_pattern="\${${replacement_pattern}/${FILENAME_REPLACEMENT_RE}/}"
readonly new_datetime_pattern="\${${replacement_pattern}/${DATETIME_REPLACEMENT_RE}${timezone}/}"

exiftool "-Directory=${output_dir}"          "-Filename<${new_filename_pattern}"\
         "-AllDates<${new_datetime_pattern}" "-OffsetTime*=${timezone}"\
         '-MaxAvailHeight<ImageHeight'       '-MaxAvailWidth<ImageWidth'\
         "-Software=${software}"             "-Model=${hardware}"\
         '-RawFileName<FileName'             '-PreservedFileName<FileName'\
         -struct          -preserve          ${verbose_mode:+'-verbose'}\
         ${=arg_files}                       --\
         ${==pending_screenshots}            || exit 4

readonly archive_name="Screenshots_$(date +%y%m%d_%H%M%S).tar.gz"
if tar -czf "${output_dir}/${archive_name}" --options gzip:compression-level=1\
    ${==pending_screenshots}; then

    rm ${==pending_screenshots}
    if (( verbose_mode )); then
        echo "Created archive in '${output_dir}'"
    fi
else
    echo "Failed to create archive in '${output_dir}'" 1>&2
    exit 5
fi