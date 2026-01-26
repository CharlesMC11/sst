SHELL                   := zsh
SCRIPT_NAME             := screenshot-tagger
export BIN_DIR          := $(HOME)/.local/bin/$(SCRIPT_NAME)
export ARG_FILES_DIR    := $(HOME)/.local/share/exiftool

ENGINE_NAME             := tagger-engine
export WATCHER_NAME     := screenshot-watcher

PLIST_NAME_BASE         := screenshot_tagger.plist
PLIST_NAME_TEMPLATE     := $(PLIST_NAME_BASE).template
PLIST_NAME              := me.$(USER).$(PLIST_NAME_BASE)
PLIST_PATH              := $(HOME)/Library/LaunchAgents/$(PLIST_NAME)

export LOG_FILE         := $(HOME)/Library/Logs/me.$(USER).$(WATCHER_NAME).log
export TMPDIR           := /Volumes/Workbench/
export TMPPREFIX        := $(TMPDIR)zsh
export INPUT_DIR        := $(TMPDIR)$(SCRIPT_NAME)
export OUTPUT_DIR       := $(HOME)/MyFiles/Pictures/Screenshots

export HW_MODEL         := $(shell system_profiler SPHardwareDataType | sed -En 's/^.*Model Name: //p')

export EXECUTION_DELAY  :=0.5
export THROTTLE_INTERVAL:=2

export LOCK_PATH        := $(TMPDIR)$(WATCHER_NAME).lock

INSTALL                 := install -pv

.PHONY: all install start stop uninstall clean

all: install start

restart: stop start

install:
	@{ [[ -e $(BIN_DIR) && ! -d $(BIN_DIR) ]] && rm $(BIN_DIR) } || true
	@mkdir -p $(BIN_DIR)
	@mkdir -p ~/Library/Logs

	@$(INSTALL) -m 755 $(ENGINE_NAME).zsh  $(BIN_DIR)/$(ENGINE_NAME)
	@zcompile -U $(BIN_DIR)/$(ENGINE_NAME)

	@$(INSTALL) -m 755 $(WATCHER_NAME).zsh $(BIN_DIR)/$(WATCHER_NAME)
	@zcompile -U $(BIN_DIR)/$(WATCHER_NAME)

start: $(PLIST_NAME_TEMPLATE)
	@content=$$(<$<); print -r -- "$${(e)content}" > $(PLIST_NAME)
	@mv $(PLIST_NAME) $(PLIST_PATH)
	launchctl bootstrap gui/$(shell id -u) $(PLIST_PATH)

stop:
	-launchctl bootout gui/$(shell id -u) $(PLIST_PATH)
	-rm -f $(PLIST_PATH)

uninstall: stop
	rm -rf $(BIN_DIR)

status:
	launchctl print gui/$(shell id -u) $(PLIST_PATH) | grep $(USER)

log:
	open $(LOG_FILE)

delete-log:
	rm $(LOG_FILE)
