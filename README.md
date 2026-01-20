# Screenshot Tagger

A Zsh-based automation suite for macOS that monitors a screenshot directory, renames files based on capture timestamps, and injects professional photography metadata.

## Motivation

This project was originally intended to treat screenshots of video calls with friends as photos taken with a camera. By injecting specific EXIF metadata—such as hardware models and software versions—these files behave like standard digital photos when imported into professional cataloging tools like **Lightroom Classic** and **Capture One**.

## Features

- **Automated Monitoring**: Uses macOS `launchd` to watch a screenshot directory for new files.
- **Photography Workflow**: Injects `Model`, `Software`, and `DateTime` tags so screenshots are treated as camera imports.
- **Smart Renaming**: Standardizes filenames to `YYMMDD_HHMMSS` based on the original capture time.
- **Auto-Archiving**: Compresses original files into a `.aar` archive after processing to maintain a clean workspace.
- **Lock Protection**: Prevents race conditions when multiple screenshots are taken simultaneously.

## Requirements

- `ExifTool`: Required for metadata manipulation.
- `envsubst`: Used during installation to configure the `.plist` file.

## Project Struture

- `tagger-engine.zsh`: The core logic for renaming, tagging, and archiving.
- `screenshot-watcher.zsh`: A wrapper script that manages execution locks and calls the engine.
- `screenshot_tagger.plist.template`: A launch agent template to automate the script via macOS `WatchPaths`.

## Installation

The project includes a `Makefile` for streamlined setup:

1. Compile and Install:

```zsh
make install
```

This compiles the scripts to Zsh Word Code (`.zwc`) for faster execution and moves them to `~/.local/bin/screenshot-tagger/`.

2. Start the Automation:

```zsh
make start
```

This generates the final `.plist` with your user information and loads it into `launchctl`.
