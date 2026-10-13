# Operational Requirements

## Startup

1. Prepare configurations to pass to `ExifTool` and `FSEventStream`
2. Spawn `ExifTool` as a persistent background process
3. Manually process `$INPUT_DIR` to clean up leftover files
4. Prepare `FSEventStreamContext`
5. Prepare signal handlers for teardown
6. Attach the `FSeventStream` to the `dispatch_queue`
7. Run the main loop

## Main Loop

1. `FSEventStream` monitors `$INPUT_DIR`
2. `FSEvents` lists the paths of new files added to `$INPUT_DIR`
3. Filter regular files:
    1. Filename does not start with '\_' (files still being written) nor '.'
    2. Check for magic bytes
4. Add the paths of valid files into a list
5. Send paths to `ExifTool` for metadata injection and renaming
6. `ExifTool` writes the processed files to `$OUTPUT_DIR`
7. Add originals to a monthly archive
8. `UNUserNotificationCenter` announces that $N$ screenshots were successfully processed

## Teardown

1. Capture interrupts
2. Stop and release `FSEventStream`
3. Close `ExifTool` and clean up resources

## Abstractions

1. `ExifTool` handler (piping, spawning)
2. `FSEventStream` handler (creation, release)
3. `dispatch_queue` (attaching, detaching)
4. Signal handler (capturing interrupts)
5. Orchestrator (callback)
6. Filter (checking name & magic bytes)
7. Archiver (archive originals)
8. `UNUserNotificationCenter` handler (banner)

## Component Specification

1. ExifTool arguments
    - input_dir : string / fd
    - executable_path: string
    - output_dir : string
    - arg_file_path : string
    - -stay_open argv: string list

2. `ExifTool` handler
    - formatted_arg : string list
    - is_running : bool
    - IPC_file_descriptors : integer pair
    - max_retries : integer

3. `FSEventStreamContext` handler
    - callback_function : Orchestrator callback
    - queue_handle : queue ptr
    - stream_handle : stream ptr
    - latency : float

4. `dispatch_queue`
    - queue_handle : queue

5. Signal handler
    - signals : integer list
    - queue_handle : queue
    - runtime_context : struct

6. Orchestrator (`FSEventStream` callback) function
    - input_dir : string
    - input_dir_fd : int
    - file_paths : string list
    - output_dir : string
    - max_retries : integer

7. Filter function
    - file_paths : string list
    - event_flags : integer
    - prefixes_to_ignore : string list | hardcoded checks
    - magic_bytes : bytes
    - max_retries : integer

8. Archiver function
   - file_paths : string list
   - output_dir : string

9. `UNUserNotificationCenter` handler
    - number_of_processed_originals : integer
