#!/usr/bin/env -S zsh -f
# A script for renaming screenshots and adding certain metadata

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL
setopt EXTENDED_GLOB

readonly SCRIPT_NAME=${0:t2:r}

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

output_dir=$PWD
timezone=$(date +%z)
software=$(sw_vers --productVersion)
hardware=$(system_profiler SPHardwareDataType | sed -En 's/^.*Model Name: //p')
declare -Ua tag_files
while (($#)); do
    case $1 in
        -h  | --help    ) show_usage; exit
        ;;
        -v  | --verbose ) integer -r is_verbose=1
        ;;
        -i  | --input   ) error_if_not_dir Input $2; cd "$2"; shift
        ;;
        -o  | --output  ) error_if_not_dir Output $2; output_dir=$2; shift
        ;;
        -tz | --timezone) timezone=$2; shift
        ;;
        -sw | --software) software=$2; shift
        ;;
        -hw | --hardware) hardware=$2; shift
        ;;
        -tg | --tag     ) tag_files+="-@ $2"; shift
        ;;
        -*  | --*       ) error_on_invalid_option $1
        ;;
        *               ) error_on_invalid_option $1
        ;;
    esac
    shift
done

setopt EXTENDED_GLOB
readonly orig_filename_pattern='*<19-21>#<-99>[^[:digit:]]#<-12>[^[:digit:]]#<-31>[^[:digit:]]#<-23>[^[:digit:]]#<-59>[^[:digit:]]#<-59>*.*(.N)'
declare -Ua screenshot_files
readonly screenshot_files=(${~orig_filename_pattern})
if ((${#screenshot_files} == 0)); then
    echo "No screenshots to process: ${PWD}" 1>&2
    exit 2
fi

# PERL string replacement patterns that will be used by ExifTool
readonly re='^.*?([1-2][^2-8])?(\d{2})\D?([0-1]\d)\D?([0-3]\d)\D*?([0-2]\d)\D?([0-5]\d)\D?([0-5]\d)(.*?)?\..+?$'
readonly orig_str_pattern="Filename;s/${re}"
readonly new_filename_pattern="\${${orig_str_pattern}/\$2\$3\$4_\$5\$6\$7\$8.%e/}"
readonly new_datetime_pattern="\${${orig_str_pattern}/\$1\$2-\$3-\$4T\$5:\$6:\$7${timezone}/}"

exiftool "-Directory=${output_dir}"          "-Filename<${new_filename_pattern}"\
         "-AllDates<${new_datetime_pattern}" "-OffsetTime*=${timezone}"\
         '-MaxAvailHeight<ImageHeight'       '-MaxAvailWidth<ImageWidth'\
         "-Software=${software}"             "-Model=${hardware}"\
         '-RawFileName<FileName'             '-PreservedFileName<FileName'\
         -struct          -preserve          ${is_verbose:+'-verbose'}\
         ${=tag_files}                       --\
         ${==screenshot_files}               || exit 3

tar -czf "${output_dir}/Screenshots_$(date +%y%m%d_%H%M%S).tar.gz"\
    ${is_verbose:+'-v'} --options gzip:compression-level=1 ${==screenshot_files}

rm ${==screenshot_files}
