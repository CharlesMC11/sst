# System Environment
ZSH						:= $(shell which zsh)
SHELL					:= $(ZSH)
.SHELLFLAGS				:= -fc
.DELETE_ON_ERROR:

export HOMEBREW_PREFIX	:= $(shell brew --prefix)
AA						:= $(shell which aa)
export EXIFTOOL			:= $(shell which exiftool)
CONFIGS					:= Makefile

# Identity
SERVICE_NAME			:= sst
AUTHOR					:= charlesmc
RDNN					:= me.$(AUTHOR).$(SERVICE_NAME)

# Toolchain
CC						:= xcrun clang
CXX						:= xcrun clang++

CPP_FLAGS				:= -D_FORTIFY_SOURCE=2
ARCH_FLAGS				:= -arch arm64 -march=native -falign-functions=16
SEC_FLAGS				:= -fPIE -mbranch-protection=standard
OPT_FLAGS				:= -fcolor-diagnostics -flto=thin -fomit-frame-pointer \
							-fstrict-aliasing
WARN_FLAGS				:= -Wall -Wextra -Wpedantic
DEP_FLAGS				:= -MMD -MP

ASFLAGS					:= $(ARCH_FLAGS) $(SEC_FLAGS) -Rpass=asm-processor -x assembler-with-cpp
LDFLAGS					:= -framework CoreFoundation -framework CoreServices \
							-framework Foundation -Wl,-dead_strip \
							-Wl,-no_warn_duplicate_libraries -Wl,-pie

DEBUG					?= 0
ifeq ($(DEBUG), 1)
	OPT_FLAGS += -g -O0 -DDEBUG_MODE
	ASFLAGS += -g
else
	OPT_FLAGS += -O2 -Oz -DNDEBUG
	LDFLAGS += -Wl,-S
endif

COMMON_FLAGS			:= $(CPP_FLAGS) $(ARCH_FLAGS) $(OPT_FLAGS) $(SEC_FLAGS)
CFLAGS					:= -std=c23 $(WARN_FLAGS) $(COMMON_FLAGS) $(DEP_FLAGS)
CXXFLAGS				:= -std=c++26 $(WARN_FLAGS) $(COMMON_FLAGS) \
							$(DEP_FLAGS) -fno-rtti -fno-exceptions

# Primary Paths
BUILD_DIR				:= ./build
OBJ_DIR					:= ./obj
SRC_DIR					:= ./src

WORKBENCH				:= /Volumes/Workbench
export BIN_DIR			:= $(WORKBENCH)/$(SERVICE_NAME)
export INPUT_DIR		:= $(WORKBENCH)/Screenshots
export OUTPUT_DIR		:= $(HOME)/MyFiles/Pictures/Screenshots

# Transient Paths
TEMP_DIR				:= $(BIN_DIR)/tmp
LOCK_PATH				:= $(TEMP_DIR)/$(SERVICE_NAME).lock
export ARG_FILES_DIR	:= $(HOME)/.local/share/exiftool
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

# Metadata
PREFIX_RE				:= (?:Screenshot)
DATE_RE					:= (\\d{2})(\\d{2})-(\\d{2})-(\\d{2})
TIME_RE					:= (\\d{2})\\.(\\d{2})\\.(\\d{2})
DATETIME_RE				:= ^$(PREFIX_RE) $(DATE_RE) at $(TIME_RE).+$$
DATETIME_REPLACEMENT_RE	:= $$1$$2:$$3:$$4 $$5:$$6:$$7
FILENAME_REPLACEMENT_RE	:= $$2$$3$$4_$$5$$6$$7
REPLACEMENT_PATTERN		:= Filename;s/$(DATETIME_RE)

# System Info
SCREENCAPTURE_PREF		:= com.apple.screencapture location
export HW_MODEL			:= $(shell system_profiler SPHardwareDataType | \
							sed -En 's/^.*Model Name: //p')

# Preferences
EXECUTION_DELAY			:=0.2
export THROTTLE_INTERVAL:=3

# Source Files

OBJS					:= $(OBJ_DIR)/$(AGENT_NAME).o $(OBJ_DIR)/fs_monitor.o \
							$(OBJ_DIR)/inspector.o $(OBJ_DIR)/processor.o \
							$(OBJ_DIR)/signal_handler.o $(OBJ_DIR)/signatures.o \
							$(OBJ_DIR)/sorter.o

# Commands
INSTALL					:= install -pv -m 755
UNINSTALLER				:= $(BIN_DIR)/uninstall

.PHONY: all install build start stop uninstall clean status open-log clean-log check-ram-disk

all: start

check-ram-disk:
# return 78: BSD EX_CONFIG
	@if [[ ! -d "$(WORKBENCH)" ]]; then \
		print -- '"$(WORKBENCH)" is not loaded'; \
		exit 78; \
	fi

# Build

-include $(OBJS:.o=.d)

build: $(BUILD_DIR)/$(AGENT_NAME) $(BUILD_DIR)/$(PLIST_NAME) $(BUILD_DIR)/uninstall

$(BUILD_DIR)/$(AGENT_NAME): $(OBJS) | $(BUILD_DIR)/.dirstamp
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $^ -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.mm | $(OBJ_DIR)/.dirstamp
	$(CXX) $(CXXFLAGS) -x objective-c++ -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cc | $(OBJ_DIR)/.dirstamp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.s | $(OBJ_DIR)/.dirstamp
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/$(PLIST_NAME): $(PLIST_TEMPLATE) $(CONFIGS) | $(BUILD_DIR)/.dirstamp
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

# Lifecycle

install: check-ram-disk build | $(BIN_DIR)/.dirstamp $(TEMP_DIR)/.dirstamp \
		$(INPUT_DIR)/.dirstamp
	@$(INSTALL) $(BUILD_DIR)/$(AGENT_NAME) $(BIN_DIR)/
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
	-rm -fr "$(BUILD_DIR)" "$(OBJ_DIR)" "$(TEMP_DIR)"

status:
	@launchctl list | grep "$(RDNN)" || print -- "'$(SERVICE_NAME)' is not running."

log:
	@tail -n 1 "$(SYSTEM_LOG)"

open-log:
	@open "$(SYSTEM_LOG)"

clean-log:
	@print -- >| "$(SYSTEM_LOG)"
