# sst (Screenshot Tagger)

A high-performance automation suite optimized for Apple Silicon. It leverages a RAM-disk–to–SSD pipeline, injects professional photography metadata to screenshots, and archives the originals using Apple Archive.

## Motivation

This project was originally born from a desire for image cataloging tools such as **Lightroom Classic** and **Capture One** to treat screenshots of video calls with my girlfriend as legitimate photos taken with a camera.

Eventually, this also evolved into deep-dive study into Unix systems programming, AArch64 assembly, and modern C++.

## Architecture & Performance

Designed specifically for my M2 Max MacBook Pro with 96 GB RAM, the suite utilizes:

- **Kernel Interfacing**: Implements `openat(2)`, `fdopendir(3)`, and `fcntl(2)` with `F_NOCACHE` to bypass macOS page cache and interact directly with my 16 GiB RAM disk.
- **AArch64**: A handwritten assembly core (`Signatures.s`) that performs magic-byte validation directly in CPU registers.
- **C++ 26**: Uses the latest C++ standards (`std::expected` and `std::string_view`) and strict memory alignment (`alignas(16)`) to ensure atomic data transfers between the system and hardware.

- **Transient Layer**: A 16 GiB RAM disk (`/Volumes/Workbench`) handling all I/O to eliminate SSD wear.
- **Logic Layer**: A hybrid C++/Assembly scanner that identifies images.
- **Automation Layer**: A `launchd` agent monitoring `$INPUT_DIR`, dispatching `exiftool` and `aa` (Apple Archive) as background parallel processes.

- **Strict Execution**: Zsh code compiled to `.zwc` (Zsh Word Code) and executed with `ERR_EXIT` and `NO_UNSET` for industrial reliability.
- **Atomic Execution**: Uses `zsystem flock` to prevent race conditions when mutiple screenshots are taken in succession.
- **Apple Archive (`.aar`)**: Utilizes native Apple Silicon compression (`lz4`) to archive original files after processing.

## Features

- **Photography Metadata**: Injects `Model`, `Software`, `DateTime`, and `OffsetTime` tags via `ExifTool`.
- **Professional Naming**: Standardizes filenames to `YYMMDD_HHMMSS` based on internal capture timestamp.
- **Background Parallelism**: Dispatches `exiftool` and `aa` as background processes to minimize blocking time of the main daemon loop.
- **Native Notifications**: Real-time status updates via macOS Notifications Center.

## Project Structure

- `Makefile`: The build system. "Bakes" configuration constants directly into scripts to satisfy strict shell parameters.
- `sstd.zsh`: The core daemon. Handles the lifecycle of the screenshot processing.
- `src/functions/`: Autoloaded Zsh functions for modular logging, error-handling, and cleanup.
- `src/native/`: C++/Assembly scanner that identifies images.
- `sst.plist.template`: Generates the launch agent that monitors `$INPUT_DIR`.

## Installation

The suite is installed to the RAM disk, and registered as a user-level Launch Agent.

1. **Configure**: Update the paths in the `Makefile` (defaults to `/Volumes/Workbench/sst`).
2. **Build & Install**:

```zsh
make install  # Compiles scripts and moves them into `$(BIN_DIR)`
```

3. **Start the Agent**:

```zsh
make start  # Generates the `.plist` and launches the agent
```

## Requirements

- **ExifTool**: Required for professional metadata injection.
- **macOS**: Optimized for Apple Silicon.
