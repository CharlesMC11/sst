include .env

SHELL               := zsh
SCRIPT_NAME         := screenshot-tagger
export BIN_DIR      := $(HOME)/.local/bin/$(SCRIPT_NAME)

ENGINE_NAME         := tagger-engine
export WATCHER_NAME := screenshot-watcher

PLIST_NAME_BASE     := screenshot_tagger.plist
PLIST_NAME_TEMPLATE := $(PLIST_NAME_BASE).template
PLIST_NAME          := $(USER).$(PLIST_NAME_BASE)

INSTALL             := install -vl h

.PHONY: all install compile start stop uninstall clean

all: compile install start

install: compile
	@echo "Installing to '$(BIN_DIR)'"
	@if [[ -e $(BIN_DIR) && ! -d $(BIN_DIR) ]]; then\
		rm $(BIN_DIR);\
	fi
	@mkdir -p $(BIN_DIR)

	@$(INSTALL) -m 755 $(ENGINE_NAME).zsh      $(BIN_DIR)/$(ENGINE_NAME)
	@$(INSTALL) -m 644 $(ENGINE_NAME).zsh.zwc  $(BIN_DIR)/$(ENGINE_NAME).zwc

	@$(INSTALL) -m 755 $(WATCHER_NAME).zsh     $(BIN_DIR)/$(WATCHER_NAME)
	@$(INSTALL) -m 644 $(WATCHER_NAME).zsh.zwc $(BIN_DIR)/$(WATCHER_NAME).zwc

	@$(INSTALL) -m 644 .env                    $(BIN_DIR)/

compile: $(ENGINE_NAME).zwc $(WATCHER_NAME).zwc

start: $(PLIST_NAME)
	@$(INSTALL) -m 644 $(PLIST_NAME) ~/Library/LaunchAgents/
	launchctl bootstrap gui/$(shell id -u) $(PLIST_NAME)

$(PLIST_NAME): $(PLIST_NAME_TEMPLATE)
	envsubst < $< > $@

stop: $(PLIST_NAME)
	launchctl bootout gui/$(shell id -u) $(PLIST_NAME)
	rm -f ~/Library/LaunchAgents/$(PLIST_NAME)

uninstall: stop
	@echo "Uninstalling '$(BIN_DIR)'..."
	rm -rf $(BIN_DIR)

clean:
	rm -f *.zwc *.plist

%.zwc: %.zsh
	zcompile $<
