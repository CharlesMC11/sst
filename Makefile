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
TEMP_DIR				:= $(BIN_DIR)/tmp
LOCK_PATH				:= $(TEMP_DIR)/$(SERVICE_NAME).lock
ARG_FILES_DIR			:= $(HOME)/.local/share/exiftool
PENDING_LIST			:= $(TEMP_DIR)/pending.fifo
PROCESSED_LIST			:= $(TEMP_DIR)/processed.txt
LOG_FILE				:= $(TEMP_DIR)/$(SERVICE_NAME).log
AA_LOG					:= $(TEMP_DIR)/aa.log
EXIFTOOL_LOG			:= $(TEMP_DIR)/exiftool.log
export SYSTEM_LOG		:= $(HOME)/Library/Logs/$(RDNN).log

# Tool Configuration
export AGENT_NAME		:= $(SERVICE_NAME)d
PLIST_TEMPLATE			:= $(SERVICE_NAME).plist.template
export PLIST_NAME		:= $(RDNN).plist
PLIST_PATH				:= $(HOME)/Library/LaunchAgents/$(PLIST_NAME)

# Preferences & System Info
SCREENCAPTURE_PREF		:= com.apple.screencapture location

DATE_RE					:= (\\d{4})\\D(\\d{2})\\D(\\d{2})
TIME_RE					:= (\\d{2})\\D(\\d{2})\\D(\\d{2})
DATETIME_RE				:= ^.+?$(DATE_RE)\\D+?$(TIME_RE).+$$
DATETIME_REPLACEMENT_RE	:= $$1:$$2:$$3 $$4:$$5:$$6
FILENAME_REPLACEMENT_RE	:= $$1$$2$$3-$$4$$5$$6
REPLACEMENT_PATTERN		:= Filename;s/$(DATETIME_RE)

HW_MODEL				:= $(shell system_profiler SPHardwareDataType | \
							sed -En 's/^.*Model Name: //p')
PERFORMANCE_CORE_COUNT	:= $(shell sysctl -n hw.perflevel0.physicalcpu)
OS_VER					:= $(shell sw_vers --productVersion)
EXECUTION_DELAY			:=0.2
export THROTTLE_INTERVAL:=3

# Source Files
BUILD_DIR				:= ./build
SRC_DIR					:= ./src
FUNC_SRC_DIR			:= ./lib
FUNC_SRCS				:= $(wildcard $(FUNC_SRC_DIR)/*.zsh)

# Commands
INSTALL					:= install -pv -m 755
SED_DELETE_WHITESPACE	:= -e '/^[[:space:]]*\#[^!]/d' -e '/^[[:space:]]*$$/d'
SED_REPLACE_KEYS		:= ZSH AA EXIFTOOL OSASCRIPT SERVICE_NAME FUNC_DIR \
							TEMP_DIR INPUT_DIR OUTPUT_DIR LOCK_PATH \
							ARG_FILES_DIR PENDING_LIST PROCESSED_LIST LOG_FILE \
							AA_LOG EXIFTOOL_LOG SYSTEM_LOG REPLACEMENT_PATTERN \
							DATETIME_REPLACEMENT_RE FILENAME_REPLACEMENT_RE \
							HW_MODEL PERFORMANCE_CORE_COUNT OS_VER EXECUTION_DELAY
SED_REPLACE				:= $(foreach k,$(SED_REPLACE_KEYS),\
							-e 's|@@$(k)@@|$($(k))|g')
UNINSTALLER				:= $(BIN_DIR)/uninstall

.PHONY: all install build start stop uninstall clean status open-log clean-log \
		check-ram-disk

all: start

check-ram-disk:
# return 78: BSD EX_CONFIG
	@if [[ ! -d "$(ROOT_DIR)" ]]; then \
		print -- '"$(ROOT_DIR)" is not loaded'; \
		exit 78; \
	fi

# Build

build: $(BUILD_DIR)/$(AGENT_NAME) \
		$(BUILD_DIR)/functions.zwc $(BUILD_DIR)/$(PLIST_NAME) \
		$(BUILD_DIR)/uninstall

$(BUILD_DIR)/$(AGENT_NAME): $(SRC_DIR)/$(AGENT_NAME).zsh $(CONFIGS)
	@print -- "Installing '$<' to '$(@D)'"
	@sed $(SED_REPLACE) "$<" >! "$@"
	@chmod 755 "$@"
	@zcompile -U "$@"

$(BUILD_DIR)/functions.zwc: $(FUNC_SRCS)
	@print -- "Installing functions in '$(<D)' to '$(@D)'"
	@zcompile -U $@ $^

$(BUILD_DIR)/$(PLIST_NAME): $(PLIST_TEMPLATE) $(CONFIGS)
	@print -- "Installing '$<' to '$(@D)'"
	@content="$$(<$<)"; print -r -- "$${(e)content}" >| "$@"

$(BUILD_DIR)/uninstall: $(CONFIGS)
	@print -l -- \
		'#!/bin/sh' \
		'launchctl bootout gui/$(shell id -u) "$(PLIST_PATH)"' \
		'rm -f "$(PLIST_PATH)"' \
		'rm -rf "$(BIN_DIR)"' \
		'defaults delete $(SCREENCAPTURE_PREF)' \
		'killall SystemUIServer' > "$@"
	@chmod 755 "$@"

$(BUILD_DIR) $(TEMP_DIR) $(INPUT_DIR) $(LOG_DIR):
	mkdir -p "$@"

# Lifecycle

install: check-ram-disk build | $(BIN_DIR)/.dirstamp $(FUNC_DIR)/.dirstamp $(TEMP_DIR) $(INPUT_DIR) $(LOG_DIR)
	@$(INSTALL) $(BUILD_DIR)/$(AGENT_NAME) $(BIN_DIR)/
	@$(INSTALL) $(BUILD_DIR)/functions.zwc $(BIN_DIR)/
	@for f in $(FUNC_SRCS); do $(INSTALL) "$$f" "$(FUNC_DIR)/$${f:t:r}"; done
	@$(INSTALL) $(BUILD_DIR)/$(PLIST_NAME) $(PLIST_PATH)
	@$(INSTALL) $(BUILD_DIR)/uninstall $(BIN_DIR)/

%/.dirstamp:
	@if [[ -e "$(@D)" && ! -d "$(@D)" ]]; then rm "$(@D)"; fi
	@mkdir -p "$(@D)" && touch "$@"

start: install
	@-launchctl bootout gui/$(shell id -u) "$(PLIST_PATH)" 2>/dev/null || true
	launchctl bootstrap gui/$(shell id -u) "$(PLIST_PATH)"
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
	-rm -fr "$(BUILD_DIR)"/*
	-rm -f "$(BIN_DIR)"/*.zwc
	-rm -f "$(FUNC_DIR).zwc"
	-rm -rf "$(TEMP_DIR)"/*

status:
	@launchctl list | grep "$(RDNN)" || print -- "'$(SERVICE_NAME)' is not running."

log:
	@tail -n 1 "$(SYSTEM_LOG)"

open-log:
	@open "$(SYSTEM_LOG)"

clean-log:
	@print -- >| "$(SYSTEM_LOG)"
