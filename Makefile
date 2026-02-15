.DELETE_ON_ERROR:

# System Environment
ZSH						:= $(shell which zsh)
SHELL					:= $(ZSH)
.SHELLFLAGS				:= -fc
export HOMEBREW_PREFIX	:= $(shell brew --prefix)
AA						:= $(shell which aa)
EXIFTOOL				:= $(shell which exiftool)
OSASCRIPT				:= $(shell which osascript)
CONFIGS					:= Makefile

# Identity
AUTHOR					:= charlesmc
SERVICE_NAME			:= sst
RDNN					:= me.$(AUTHOR).$(SERVICE_NAME)

# Primary Paths
ROOT_DIR				:= /Volumes/Workbench
export BIN_DIR			:= $(ROOT_DIR)/$(SERVICE_NAME)
export FUNC_DIR			:= $(BIN_DIR)/functions
export INPUT_DIR		:= $(ROOT_DIR)/Screenshots
OUTPUT_DIR				:= $(HOME)/MyFiles/Pictures/Screenshots

# Transient Paths
TMPDIR					:= $(BIN_DIR)/tmp
LOCK_PATH				:= $(TMPDIR)/$(SERVICE_NAME).lock
ARG_FILES_DIR			:= $(HOME)/.local/share/exiftool
PENDING_LIST			:= $(TMPDIR)/pending.fifo
PROCESSED_LIST			:= $(TMPDIR)/processed.txt
LOG_FILE				:= $(TMPDIR)/$(SERVICE_NAME).log
AA_LOG					:= $(TMPDIR)/aa.log
EXIFTOOL_LOG			:= $(TMPDIR)/exiftool.log
export SYSTEM_LOG		:= $(HOME)/Library/Logs/$(RDNN).log

# Tool Configuration
export AGENT_NAME		:= $(SERVICE_NAME)d
PLIST_TEMPLATE			:= $(SERVICE_NAME).plist.template
export PLIST_NAME		:= $(RDNN).plist
PLIST_PATH				:= $(HOME)/Library/LaunchAgents/$(PLIST_NAME)

# Preferences & System Info
SCREENCAPTURE_PREF		:= com.apple.screencapture location

PREFIX_RE				:= (?:Screenshot)
DATE_RE					:= (\\d{2})(\\d{2})-(\\d{2})-(\\d{2})
TIME_RE					:= (\\d{2})\\.(\\d{2})\\.(\\d{2})
DATETIME_RE				:= ^$(PREFIX_RE) $(DATE_RE) at $(TIME_RE).+$$
DATETIME_REPLACEMENT_RE	:= $$1$$2:$$3:$$4 $$5:$$6:$$7
FILENAME_REPLACEMENT_RE	:= $$2$$3$$4_$$5$$6$$7
REPLACEMENT_PATTERN		:= Filename;s/$(DATETIME_RE)

HW_MODEL				:= $(shell system_profiler SPHardwareDataType | \
							sed -En 's/^.*Model Name: //p')
PERFORMANCE_CORE_COUNT	:= $(shell sysctl -n hw.perflevel0.physicalcpu)
OS_VER					:= $(shell sw_vers --productVersion)
EXECUTION_DELAY			:=0.2
export THROTTLE_INTERVAL:=3

# Source Files
FUNC_SRCS				:= $(wildcard src/_*.zsh) $(wildcard lib/*.zsh)

# Commands
INSTALL					:= install -pv -m 755
SED_DELETE_WHITESPACE	:= -e '/^[[:space:]]*\#[^!]/d' -e '/^[[:space:]]*$$/d'
SED_REPLACE				:= -e 's|@@ZSH@@|$(ZSH)|g' \
							-e 's|@@AA@@|$(AA)|g' \
							-e 's|@@EXIFTOOL@@|$(EXIFTOOL)|g' \
							-e 's|@@OSASCRIPT@@|$(OSASCRIPT)|g' \
							-e 's|@@SERVICE_NAME@@|$(SERVICE_NAME)|g' \
							-e 's|@@FUNC_DIR@@|$(FUNC_DIR)|g' \
							-e 's|@@TMPDIR@@|$(TMPDIR)|g ' \
							-e 's|@@INPUT_DIR@@|$(INPUT_DIR)|g' \
							-e 's|@@OUTPUT_DIR@@|$(OUTPUT_DIR)|g' \
							-e 's|@@LOCK_PATH@@|$(LOCK_PATH)|g' \
							-e 's|@@ARG_FILES_DIR@@|$(ARG_FILES_DIR)|g' \
							-e 's|@@PENDING_LIST@@|$(PENDING_LIST)|g' \
							-e 's|@@PROCESSED_LIST@@|$(PROCESSED_LIST)|g' \
							-e 's|@@LOG_FILE@@|$(LOG_FILE)|g' \
							-e 's|@@AA_LOG@@|$(AA_LOG)|g' \
							-e 's|@@EXIFTOOL_LOG@@|$(EXIFTOOL_LOG)|g' \
							-e 's|@@SYSTEM_LOG@@|$(SYSTEM_LOG)|g' \
							-e 's|@@REPLACEMENT_PATTERN@@|$(REPLACEMENT_PATTERN)|g' \
							-e 's|@@DATETIME_REPLACEMENT_RE@@|$(DATETIME_REPLACEMENT_RE)|g' \
							-e 's|@@FILENAME_REPLACEMENT_RE@@|$(FILENAME_REPLACEMENT_RE)|g' \
							-e 's|@@HW_MODEL@@|$(HW_MODEL)|g' \
							-e 's|@@PERFORMANCE_CORE_COUNT@@|$(PERFORMANCE_CORE_COUNT)|g' \
							-e 's|@@OS_VER@@|$(OS_VER)|g' \
							-e 's|@@EXECUTION_DELAY@@|$(EXECUTION_DELAY)|g'

UNINSTALLER				:= $(BIN_DIR)/uninstall

.PHONY: all install start stop uninstall clean status open-log clean-log check-ram-disk

all: start

check-ram-disk:
# return 78: BSD EX_CONFIG
	@if [[ ! -d "$(ROOT_DIR)" ]]; then \
		print -- '"$(ROOT_DIR)" is not loaded'; \
		exit 78; \
	fi

$(TMPDIR) $(INPUT_DIR) $(LOG_DIR):
	mkdir -p "$@"

$(BIN_DIR)/%: src/%.zsh $(CONFIGS) | $(BIN_DIR)/.dirstamp
	@print -- "Installing '$<' to '$(@D)'"
	@sed $(SED_REPLACE) "$<" >! "$@"
	@chmod 755 "$@"
	@zcompile -U "$@"

$(FUNC_DIR).zwc: $(FUNC_SRCS) $(CONFIGS) | $(FUNC_DIR)/.dirstamp
	@print -- "Installing functions in '$(<D)' to '$(@D)'"
	@for f in $(FUNC_SRCS); do $(INSTALL) "$$f" "$(FUNC_DIR)/$${f:t:r}"; done
	@zcompile -U "$@" $(FUNC_SRCS)

%/.dirstamp:
	@if [[ -e "$(@D)" && ! -d "$(@D)" ]]; then rm "$(@D)"; fi
	@mkdir -p "$(@D)" && touch "$@"

$(PLIST_PATH): $(PLIST_TEMPLATE) $(CONFIGS)
	@print -- "Installing '$<' to '$(@D)'"
	@content="$$(<$<)"; print -r -- "$${(e)content}" >| "$@"

$(UNINSTALLER): $(CONFIGS) | $(BIN_DIR)/.dirstamp
	@print -l -- \
		'#!/usr/bin/env sh' \
		'launchctl bootout gui/$(shell id -u) "$(PLIST_PATH)"' \
		'rm -f "$(PLIST_PATH)"' \
		'rm -rf "$(BIN_DIR)"' \
		'defaults delete $(SCREENCAPTURE_PREF)' \
		'killall SystemUIServer' > "$@"
	@chmod 755 "$@"

install: check-ram-disk $(BIN_DIR)/$(AGENT_NAME) $(FUNC_DIR).zwc \
	$(UNINSTALLER) | $(TMPDIR) $(INPUT_DIR) $(LOG_DIR)

start: $(PLIST_PATH) install
	@-launchctl bootout gui/$(shell id -u) "$(PLIST_PATH)" 2>/dev/null || true
	launchctl bootstrap gui/$(shell id -u) "$<"
	defaults write $(SCREENCAPTURE_PREF) -string "$(INPUT_DIR)"
	@killall SystemUIServer

stop:
	-launchctl bootout gui/$(shell id -u) "$(PLIST_PATH)" 2>/dev/null
	-defaults delete $(SCREENCAPTURE_PREF) 2>/dev/null
	@killall SystemUIServer

uninstall: stop
	-rm -f "$(PLIST_PATH)"
	-rm -rf "$(BIN_DIR)"

clean:
	-rm -f "$(BIN_DIR)"/*.zwc
	-rm -f "$(FUNC_DIR).zwc"
	-rm -rf "$(TMPDIR)"/*

status:
	@launchctl list | grep "$(RDNN)" || print -- "'$(SERVICE_NAME)' is not running."

log:
	@tail -n 1 "$(SYSTEM_LOG)"

open-log:
	@open "$(SYSTEM_LOG)"

clean-log:
	@print -- >| "$(SYSTEM_LOG)"
