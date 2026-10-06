# sst (Screenshot Tagger)

## Operational Requirements

### Startup

1. Prepare configurations to pass to `ExifTool` and `FSEventStream`
2. Spawn `ExifTool` as a persistent background process
3. Manually process `$INPUT_DIR` to clean up leftover files
4. Prepare `FSEventStreamContext`
5. Prepare signal handlers for teardown
6. Attach the `FSeventStream` to the `dispatch_queue`
7. Run the main loop

### Main Loop

1. `FSEventStream` monitors `$INPUT_DIR`
2. `FSEvents` lists the paths of new files added to `$INPUT_DIR`
3. Filter regular files:
   1. Filename does not start with '\_' (files still being written) nor '.'
   2. Check for magic bytes
4. Add the paths of valid files into a list
5. Sort the paths using natural sort
6. Send sorted paths to `ExifTool` for metadata injection and renaming
7. `ExifTool` writes the processed files to `$OUTPUT_DIR`
8.  Store originals of successfully processed files in a monthly archive
9.  `UNUserNotificationCenter` announces that $N$ screenshots were successfully processed

### Teardown

1. Capture interrupts
2. Stop and release `FSEventStream`
3. Manually process `$INPUT_DIR` to clean up leftover files
4. Close `ExifTool` and clean up resources

## Abstractions

1. `ExifTool` handler (piping, spawning)
2. `FSEventStream` handler (context creation, releaser)
3. `dispatch_queue` (enqueueing, dequeueing)
4. Signal handler (capturing interrupts)
5. Orchestrator callback function
6. Filter (checking name & magic bytes)
7. Sorter (natural sort)
8. Archiver (monthly archive)
9. `UNUserNotificationCenter` handler (banner)

## Component Specification

1. Photo metadata
   - input_dir : string
   - output_dir : string
   - arg_files_dir : string
   - artist : string
   - copyright : string
   - filename_regex : string
   - timezone : string
   - hardware_make : string
   - hardware_model : string
   - macOS_version : string

2. `ExifTool` handler
   - executable_path : string
   - is_running : bool
   - formatted_arg : string list
   - IPC_file_descriptors : integer pair
   - max_retries : integer

3. `FSEventStreamContext` handler
   - callback_function : Orchestrator callback
   - input_dir : string
   - input_dir_fd : integer
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

7. Filter function
   - file_paths : string list
   - event_flags : integer
   - prefixes_to_ignore : string list | hardcoded checks
   - magic_bytes : bytes
   - max_retries : integer

8. Sorter function
   - file_paths : string list

9. Archiver function
   - file_paths : string list
   - archiver : executable / header
   - current_date : datetime / string
   - output_dir : string
   - max_retries : integer

10. `UNUserNotificationCenter` handler
    - number_of_processed_originals : integer

## State Diagram

```mermaid
stateDiagram-v2
  [*] --> Startup : Daemon Invoked

  state is_initialized <<choice>>
  Startup --> is_initialized : Set-Up ExifTool & FSEventStream
  is_initialized --> [*] : [Failure] Throw
  is_initialized --> Loop : [Success] Queue Dispatch

  state "Main Loop" as Loop {
    [*] --> Idle : Run Dispatch
    Processing --> Idle : No Valid Files
    Idle --> Processing : FSEvent Received

    Processing --> Async : Write Processed Files to Disk
    Async --> Idle : Async Process Dispatched

    state "Background Queue" as Async {
      [*] --> Archiving : Original Paths Received
      Archiving --> [*] : Display Notification Banner
    }
  }

  Loop --> Teardown : SIGINT / SIGTERM
  Teardown --> [*] : EXIT NONZERO
  Teardown --> [*] : EXIT OK
```

## Flowcharts

### Startup
```mermaid
flowchart
  IN([Daemon Invoked]) --> Parse{{Parse CLI Arguments / plist Config}}
  Parse --> ExifTool

  subgraph ExifTool [Spawn ExifTool Subprocess]
      direction TB
    Args{{Format ExifTool Common Arguments}} --> Pipe[[Open Pipe]]
    Pipe --> |Failure| Throw1([Throw])
    Pipe --> |Success| Spawn[[Spawn Subprocess]]
    Spawn --> |Failure| Throw1
    Spawn --> |Success| Run(ExifTool Running)
  end

  ExifTool --> FDOpen[[Open $INPUT_DIR File Descriptor]]
  FDOpen --> |Failure| Throw2([Throw])
  FDOpen --> |Success| Cleanup((Cleanup $INPUT_DIR))

  Cleanup --> Dispatch[[Get Dispatch Queue]]
  Dispatch --> Signals{{Set-Up Signal Handlers}}
  Signals --> FSEvent[[Create FSEventStreamContext]]
  FSEvent --> Attach[[Attach to Dispatch]]
  Attach --> Start[[Main Loop]]
```
### Teardown

```mermaid
flowchart
  Main[[Main Loop]] --> Signals[/SIGINT / SIGTERM/]
  Signals --> Stop[[Stop & Invalidate FSEventStream]]
  Stop --> Clean((Cleanup $INPUT_DIR))
  Clean --> Close[[Close Pipe]]
  Close --> |Failure| Closed?{Max Attempts Exhausted?}
  Closed? --> |No| Close
  Closed? --> |Yes: EXIT NONZERO| Reap[[Wait for Child PID]]
  Close --> |Success: EXIT OK| Reap
  Reap --> Exit([EXIT])
```

### Cleanup $INPUT_DIR
```mermaid
flowchart
  OpenDir[[Open $INPUT_DIR Stream]] --> |Failure| EXIT([EXIT NONZERO])
  OpenDir --> |Failure| OpenDir?{Max Attempts Exhausted?}
  OpenDir? --> |Yes| EXIT
  OpenDir? --> |No| OpenDir
  OpenDir --> |Success| Orchestrator((Orchestrator))

  Orchestrator --> |Check for Skip| Orchestrator?{Skipped?}
  Orchestrator? --> |Yes| EXIT
  Orchestrator? --> |No| CloseDir[[Close $INPUT_DIR Stream]]
  CloseDir --> |Failure| EXIT
  CloseDir --> |Success| ClosedDir[/$INPUT_DIR Stream Closed/]
```
### Orchestrator
```mermaid
flowchart
  subgraph Filter
    direction TB
    Loop[Iterate $INPUT_DIR] --> File{Is Regular File?}
    File --> |No| Loop
    File --> |Yes| Filename{Has Valid Filename?}
    Filename --> |No| Loop
    Filename --> |Yes| Open[[Open File]]
    Open --> |Failure| Max1{Max Attempts Exhausted?}
    Max1 --> |No| Open
    Max1 --> |Yes| Loop
    Open --> |Success| Magic{Has Magic Bytes?}
    Magic --> |No| Close[[Close File]]
    Close --> |Failure| Closed?{Max Attempts Exhausted?}
    Closed? --> |No| Close
    Closed? --> |Yes| Loop
    Close --> |Success| Loop
    Magic --> |Yes| Add[/Add Filename to List/]
    Add --> Close[[Close File]]
  end

  Filter --> Sorter{{Sort Filenames}}
  Sorter --> Processor

  subgraph Processor
    Args{{Construct ExifTool Args List}} --> Pipe[[Write to Pipe]]
    Pipe --> |Failure| Pipe?{Max Attempts Exhausted?}
    Pipe? --> |No| Pipe
    Pipe? --> |Yes| Skip
    Pipe --> |Success| ExifTool(ExifTool Process)
    ExifTool --> Write[/Write to $OUTPUT_DIR/]
  end

  Processor --> Success{{Gather Originals of Successfully Processed Files}}
  Success --> Async[[Background Queue]]
```

## Sequence Diagram

```mermaid
---
title: Main Loop
---
sequenceDiagram
autonumber

actor User

box rgb(30, 30, 40) Main Thread
  participant FS@{ type: boundary } as FSEvents / Kernel
  participant O as Orchestrator Callback
  participant F as Filter
  participant S as Sorter
  participant P as Processor
end

box rgb(40, 30, 30) Subprocess
  participant ET@{ type: boundary } as ExifTool
end

box rgb(30, 40, 30) Background Queue
  participant BG@{ type: boundary } as Background Queue Listener
  participant A as Archiver
  participant N@{ type: boundary } as UNUserNotificationCenter
end

User ->> FS : Save Screenshots to $INPUT_DIR
FS ->> O : Deliver Event Paths

activate O
  O ->> F : Filter Images
    activate F
      loop for each file path
        F ->> F : Is Regular File?
        F ->> F : Has Valid Filename?
        F ->> F : Has Magic Bytes?
      end
      F -->> O : Valid Filenames
    deactivate F

  O ->> S : Sort Filenames
  activate S
    S -->> O : Sorted List
  deactivate S

  O ->> P : Construct ExifTool Args List
  activate P
    P ->> ET : Write Filenames to Pipe
    activate ET
      ET -->> P : Write Files to $OUTPUT_DIR
    deactivate ET
    P -->> O : Ready
  deactivate P

  Note over O,BG: Async Process
  O --) BG : Send Paths of Originals of Processed Files
  activate BG
    O -->> FS : Done

deactivate O

    BG ->> A : Add Originals to Monthly Archive
    activate A
    A -->> BG : Done
    deactivate A

    BG ->> N : Request Banner Notification (N Screenshots Tagged)

    activate N
      N -->> User : Display macOS Banner
    deactivate N
  deactivate BG
```
