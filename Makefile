SHELL               := zsh
SCRIPT_NAME         := screenshot-tagger
BIN_DIR             := $(HOME)/.local/bin/$(SCRIPT_NAME)

SRC_ENGINE          := metadata-engine
SRC_WATCHER         := screenshot-watcher
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

	@$(INSTALL) -m 755 $(SRC_ENGINE).zsh      $(BIN_DIR)/$(SRC_ENGINE)
	@$(INSTALL) -m 644 $(SRC_ENGINE).zsh.zwc  $(BIN_DIR)/$(SRC_ENGINE).zwc

	@$(INSTALL) -m 755 $(SRC_WATCHER).zsh     $(BIN_DIR)/$(SRC_WATCHER)
	@$(INSTALL) -m 644 $(SRC_WATCHER).zsh.zwc $(BIN_DIR)/$(SRC_WATCHER).zwc

compile: $(SRC_ENGINE).zwc $(SRC_WATCHER).zwc

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
	rm -f *.zwc $(PLIST_NAME)

%.zwc: %.zsh
	zcompile $<
