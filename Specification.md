# sst (Screenshot Tagger)

## Functional Spec

### Startup

1. Prepare configurations to pass to `ExifTool` and `FSEventStream`: e.g.: directory paths, image metadata
2. Spawn `ExifTool` as a persistent background process
3. Manually process `$INPUT_DIR` to clean up leftover files
4. Prepare the context needed by the callback function passed to `FSEventStream`
5. Attach the `FSeventStream` to the `dispatch_queue`
6. Prepare signal handlers for teardown
7. Run the main loop

### Main Loop

1. `FSEventStream` monitors `$INPUT_DIR`
2. `FSEvents` lists the paths of new files added to `$INPUT_DIR`
3. Filter regular files that do not start with '\_' (files still being written) nor '.'
4. Check files for magic bytes
5. Add the paths of valid files into a list
6. Sort the paths using natural sort
7. Send sorted paths to `ExifTool` for metadata injection and renaming
8. `ExifTool` sends the processed files to `$OUTPUT_DIR`
9. Archive the originals of successfully processed files; store in a monthly archive
10. `UNUserNotificationCenter` announces that $N$ screenshots were successfully processed

### Teardown

1. Capture interrupts
2. Stop and release `FSEventStream`
3. Manually process `$INPUT_DIR` to clean up leftover files
4. Close `ExifTool` and its spawned process

## Abstractions

1. `ExifTool` handler (spawning, piping, cleanup)
2. `FSEventStream` handler (context creation, releaser)
3. `dispatch_queue` (enqueueing, dequeueing)
4. Signal handler (capturing interrupts)
5. Orchestrator callback function
6. Filter (checking name & magic bytes)
7. Sorter (natural sort)
8. Archiver (add to monthly archive)
9. `UNUserNotificationCenter` handler (banner)

## Attributes

1. Photo metadata
   - output_dir : string
   - arg_files_dir : string
   - artist : string
   - copyright : string
   - filename_regex : string
   - datetime : string
   - timezone : string
   - hardware_name : string
   - macOS_version : string

2. `ExifTool` handler
   - executable_path : string
   - is_running : bool
   - formatted_arguments : string list
   - IPC_file_descriptors : integer pair
   - max_retries : integer

3. `FSEventStreamContext` handler
   - input_dir : string
   - input_dir_fd : integer
   - stream_handle : stream ptr
   - queue_handle : queue ptr
   - files_buffer : string list
   - callback_function : Orchestrator callback
   - latency : float

4. `dispatch_queue`
   - queue_handle : queue

5. Signal handler
   - signals : integer list
   - queue_handle : queue
   - runtime_context :

6. Orchestrator (`FSEventStream` callback) function
   - input_dir : string
   - input_dir_fd : int
   - file_paths : string list
   - output_dir : string

7. Filter function
   - file_paths : string list
   - event_flags : integer
   - prefixes_to_ignore : string list | hardcoded checks
   - magic_bytes : bytes
   - max_retries : integer

8. Sorter function
   - file_paths : string list
   - locale : string

9. Archiver function
   - file_paths : string list
   - archiver : executable / header
   - current_date : datetime / string
   - output_dir : string
   - max_retries : integer

10. `UNUserNotificationCenter` handler (function)
    - number_of_processed_originals : integer

## State Diagram

```mermaid
stateDiagram-v2
  [*] --> Uninitialized

  state Startup {
    Uninitialized --> Configured : process image metadata and `ExifTool` args
    Configured --> Spawned : spawn persistent `ExifTool`
    Spawned --> Opened : open file descriptor for $INPUT_DIR
    Opened --> Sweeping: clean up leftover files
  }

  Sweeping --> Idle : attach `FSEventStream` to `dispatch_queue` & start

  state "Screenshot Loop" as MainLoop {
    Idle --> EventReceived : detected changes in $INPUT_DIR

    state "Critical Path" as CriticalPath {
    EventReceived --> Filtering : invoke callback

    Filtering --> Sorting : magic bytes are valid
    Filtering --> Idle : no valid files found / max retries attempted
    Filtering --> Filtering : retry (max N attempts)

    Sorting --> Processing : by name

    Processing --> AsyncDispatch : files tagged & moved
    Processing --> Processing : retry (max N attempts)
    Processing --> Idle : max retries attempted
    }

    AsyncDispatch --> Idle : dispatch to background
  }

  state "Background Queue" as BGQueue {
    [*] --> Archiving : received paths
    Archiving --> Notifying : originals archived or max retries attempted
    Archiving --> Archiving : retry (max N attempts)
    Notifying --> Complete : banner posted
    Complete --> [*]
  }

  AsyncDispatch --> BGQueue : archive originals

  Idle --> Stopped : catch SIGINT / SIGTERM

  state Teardown {
    Stopped --> Flushing : clean up leftover files
    Flushing --> Closed : close ExifTool and pipes
    Closed --> Reaped : wait for child PID
  }

  Reaped --> [*] : EX_OK
```

## Sequence Diagram

```mermaid
---
title: Screenshot Loop
---
sequenceDiagram
autonumber

actor User
participant FS@{ type: boundary } as FSEvents
participant O as Orchestrator Callback
participant F as Filter
participant S as Sorter
participant P as Processor
participant ET@{ type: boundary } as ExifTool
participant BG as Background Worker Queue
participant A@{ type: boundary } as Archiver
participant N@{ type: boundary } as UNUserNotificationCenter

User ->> FS : save new screenshot to $INPUT_DIR
FS ->> O : deliver event paths

activate O
  O ->> F : filter valid images

  activate F
    F -->> O : valid paths
  deactivate F

  O ->> S : natural sort

  activate S
    S -->> O : sorted paths
  deactivate S

  O ->> P : send sorted paths

  activate P
    P ->> ET : write filenames to pipe

    activate ET
      ET -->> P : write files to $OUTPUT_DIR
    deactivate ET

    P -->> O : done
  deactivate P

  Note over O,BG: Async Process
  O --) BG : send paths of originals of processed files
  O -->> FS : done
deactivate O

activate BG
  BG ->> A : archive originals

  activate A
    A -->> BG : add to monthly archive in $OUTPUT_DIR
  deactivate A

  BG ->> N : notification request

  activate N
    N -->> User : display banner
  deactivate N
deactivate BG
```
