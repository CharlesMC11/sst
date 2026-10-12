# sst (Screenshot Tagger)

An automation daemon optimized for Apple Silicon. It leverages a RAM-disk-to-SSD pipeline for injecting professional photography metadata to screenshots in realtime.

## Motivation

This project was born from a desire for image cataloging tools such as **Lightroom Classic** and **Capture One** to treat screenshots of video calls with my girlfriend as legitimate photos taken with a camera.

Originally written in Zsh for Folder Actions, this evolved into a deep‐dive study into Unix systems programming, launchd, AArch64 assembly, C++23, and Objective‑C++.

## Specification

The project architecture can be read in [Documentation/](Documentation/).

## Performance

Designed specifically for my M2 Max MacBook Pro with 96 GB Unified Memory, it utilizes:

- **ExifTool**: Spawned as a subprocess via `posix_spawn` for the daemon’s lifespan
- **Kernel-Level API**: POSIX file descriptors and Libsystem functions such as `open`, `openat`, `pipe`, `read`, and `writev` for minimal overhead.
- **Retries**: Partial writes and kernel interrupts are handled with retry attempts.
- **FSEvents**: For native kernel-level event monitoring.
- **Assembly**: A magic-bytes checker in the main loop, handwritten in Arm64 assembly.
- **RAII Wrapper**: A custom smart pointer deleter for Objective-C pointers such as `CFStringRef` and `FSEventStreamRef`
- **RAM Disk**: A 16 GiB RAM disk landing directory for high-frequency data to reduce SSD wear.

## Photography Metadata

With the exception of `Software`, the metadata arguments are stored in a `-@ argfile`:

- **Date & Time**: Extracted from macOS’s screenshot filename using Perl regex.
- **OffsetTime**: Taken from the file’s filesystem creation date.
- **Make & Model**: Manually configured to “Apple” and “MacBook Pro.”
- **LensMake & Lens**: Manually configured to “Apple” and “FaceTime HD.”
- **Software**: Dynamically determined at startup using `sw_vers` in the `.ExifTool_config` file.

## TODOs

- Implement `UNUserNotificationCenter` banner
- Switch from `std::fprintf` to `os_log`
- Handwrite the C-string path slicer and filter in assembly
