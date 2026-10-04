# sst (Screenshot Tagger)

A high-performance automation suite optimized for Apple Silicon. It leverages a RAM-disk–to–SSD pipeline, injects professional photography metadata to screenshots, and archives the originals using Apple Archive.

## Motivation

This project was originally born from a desire for image cataloging tools such as **Lightroom Classic** and **Capture One** to treat screenshots of video calls with my girlfriend as legitimate photos taken with a camera.

Eventually, this also evolved into deep-dive study into Unix systems programming, AArch64 assembly, and modern C++.

## Architecture & Performance

Designed specifically for my M2 Max MacBook Pro with 96 GB RAM, the suite utilizes:

- **Kernel Interfacing**: Implements `openat(2)`, `fdopendir(3)` to bypass macOS page cache and interact directly with my 16 GiB RAM disk.
- **AArch64**: A handwritten assembly core (`signatures.s`) that performs magic-byte validation directly in CPU registers.
- **C++26**: Uses the latest C++ standards (`std::string_view`) and strict memory alignment (`alignas(16)`) to ensure atomic data transfers between the system and hardware.

- **Transient Layer**: A 16 GiB RAM disk (`/Volumes/Workbench`) handling all I/O to eliminate SSD wear.
- **Logic Layer**: A hybrid C++/Assembly scanner that identifies images.
- **Automation Layer**: A `launchd` agent monitoring `$INPUT_DIR`, dispatching `exiftool` and `aa` (Apple Archive) as background parallel processes.
- **Apple Archive (`.aar`)**: Utilizes native Apple Silicon compression (`lz4`) to archive original files after processing.

## Features

- **Photography Metadata**: Injects `Model`, `Software`, `DateTime`, and `OffsetTime` tags via `ExifTool`.
- **Professional Naming**: Standardizes filenames to `YYYYMMDD-HHMMSS` based on internal capture timestamp.
- **Background Parallelism**: Dispatches `exiftool` and `aa` as background processes to minimize blocking time of the main daemon loop.
- **Native Notifications**: Real-time status updates via macOS Notifications Center.

## Requirements

- **ExifTool**: Required for professional metadata injection.
- **macOS**: Optimized for Apple Silicon.
