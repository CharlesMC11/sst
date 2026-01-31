.DELETE_ON_ERROR:

# System Environment
export SHELL			:= $(shell which zsh)
.SHELLFLAGS				:= -fc
export HOMEBREW_PREFIX	:= $(shell brew --prefix)
CONFIGS					:= Makefile

# Identity
AUTHOR					:= charlesmc
export SERVICE_NAME		:= sst
RDNN					:= me.$(AUTHOR).$(SERVICE_NAME)

# Primary Paths
ROOT_DIR				:= /Volumes/Workbench
export BIN_DIR			:= $(ROOT_DIR)/$(SERVICE_NAME)
export INPUT_DIR		:= $(ROOT_DIR)/Screenshots
export OUTPUT_DIR		:= $(HOME)/MyFiles/Pictures/Screenshots

# Transient Paths
export TMPDIR			:= $(BIN_DIR)/tmp
export TMPPREFIX		:= $(TMPDIR)/zsh-$(SERVICE_NAME)-
export LOCK_PATH		:= $(TMPDIR)/$(SERVICE_NAME).lock
export ARG_FILES_DIR	:= $(HOME)/.local/share/exiftool
export LOG_FILE			:= $(HOME)/Library/Logs/$(RDNN).log

# Tool Configuration
export MAIN_NAME		:= $(SERVICE_NAME)
export AGENT_NAME		:= $(MAIN_NAME)d
PLIST_TEMPLATE			:= $(SERVICE_NAME).plist.template
export PLIST_NAME		:= $(RDNN).plist
PLIST_PATH				:= $(HOME)/Library/LaunchAgents/$(PLIST_NAME)

# Preferences & System Info
SCREENCAPTURE_PREF		:= com.apple.screencapture location
export HW_MODEL			:= $(shell system_profiler SPHardwareDataType | \
							sed -En 's/^.*Model Name: //p')
export OS_VER			:= $(sw_vers --productVersion)
export EXECUTION_DELAY	:=0.2
export THROTTLE_INTERVAL:=3

# Commands
INSTALL					:= install -pv -m 755
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

$(BIN_DIR)/.dirstamp:
	@if [[ -e "$(BIN_DIR)" && ! -d "$(BIN_DIR)" ]]; then \
		rm "$(BIN_DIR)"; \
	fi
	@mkdir -p "$(BIN_DIR)" && touch "$@"

$(BIN_DIR)/%: %.zsh $(CONFIGS) | $(BIN_DIR)/.dirstamp
	@$(INSTALL) "$<" "$@"
	@zcompile -U "$@"

$(PLIST_PATH): $(PLIST_TEMPLATE) $(CONFIGS)
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

install: check-ram-disk $(BIN_DIR)/$(AGENT_NAME) \
	$(UNINSTALLER) | $(TMPDIR) $(INPUT_DIR) $(LOG_DIR)

start: $(PLIST_PATH) install
	@launchctl bootout gui/$(shell id -u) "$(PLIST_PATH)" 2>/dev/null || true
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
	-rm -f "$(TMPDIR)"/*

status:
	@launchctl list | grep "$(RDNN)" || print -- "'$(SERVICE_NAME)' is not running."

log:
	@tail -n 1 "$(LOG_FILE)"

open-log:
	@open "$(LOG_FILE)"

clean-log:
	@print -- >| "$(LOG_FILE)"
