# sst (Screenshot Tagger)

A Zsh-based automation suite for macOS on Apple Silicon. It monitors a screenshot directory, renames files based on capture timestamps, and injects photography metadata.

## Motivation

This project was originally inspired by finding a way for image cataloging tools such as **Lightroom Classic** and **Capture One** to treat screenshots of video calls with my girlfriend as photos taken with a camera. Eventually, this also evolved into a project for me to learn how to better use resources available on Apple Silicon and Zsh.

## Performance Architecture

- **Native Efficiency**: Compiled to `Zsh Word Code` (`.zwc`) and scheduled with `Interactive` priority.
- **Atomic Execution**: Uses `zsystem flock` to safely handle mutiple screenshots taken in succession.
- **Automatic Archiving**: Uses Apple Archive (`.aar`) with `lz4` compression to archive original files after processing.

## Features

- **Photography Workflow**: Injects `Model`, `Software`, and `DateTime` tags so screenshots are treated as camera imports.
- **Smart Renaming**: Standardizes filenames to `YYMMDD_HHMMSS` based on the original capture time.
- **Native Notifications**: Real-time updates through macOS Notifications Center using `osascript`.

## Requirements

- `ExifTool`: Required for metadata manipulation.

## Project Structure

- `Makefile`: For compiling the scripts and building the `.plist`, using Environment Variables as configurations.
- `sst.zsh`: The core logic for tagging, renaming, and archiving.
- `sstd.zsh`: A wrapper script called by `launchd` that manages execution locks and calls the engine.
- `sst.plist.template`: A launch agent template to automate the script via macOS `WatchPaths`.

## Installation

The project includes a `Makefile` for streamlined setup:

```zsh
make install  # Compiles scripts and moves them into `$(BIN_DIR)$`
make start    # Generates the `.plist` and launches the agent
```
