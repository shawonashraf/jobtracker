# Snellius Job Tracker — Design

## Purpose

A small macOS SwiftUI app that shows the current user's SLURM jobs on the
Snellius cluster (host alias `Snellius-Large` in `~/.ssh/config`) in a table,
via a manual-refresh SSH call to `squeue`.

## Defaults

`~/.ssh/config` has:

```
Host Snellius-Large
  HostName snellius.surf.nl
  User sashraf1
  ...
```

Hostname and username fields in the UI default to these values but are
editable.

## Architecture

Three pieces, no persistence:

1. **`SSHConfigReader`** — parses `~/.ssh/config` at launch, finds the
   `Host Snellius-Large` block, extracts `HostName` and `User`.
2. **`SlurmJobFetcher`** — builds and runs, via `Process`:
   ```
   ssh -o HostName=<host> -o User=<user> Snellius-Large \
       squeue -u <user> -o "%i|%P|%j|%T|%M|%D|%R|%l|%C|%m"
   ```
   Using the `Snellius-Large` alias (rather than `user@host` directly) means
   the call still matches the `Host Snellius-Large` block in
   `~/.ssh/config`, inheriting `ControlMaster`/`ControlPersist` — so if a
   control-socket session is already warm (e.g. from a terminal), no
   re-authentication happens. `-o HostName=`/`-o User=` override the
   editable fields without needing a second alias.
   Parses stdout (pipe-delimited, one job per line) into `[Job]`.
3. **`ContentView`** — replaces the default SwiftData template entirely:
   hostname field, username field, Refresh button, `Table` of jobs, error
   banner.

No SwiftData, no `Item` model, no timers/polling — confirmed verbally: manual
refresh only.

## Data flow

Click Refresh → run `squeue` over SSH → split stdout into lines → split each
line on `|` → build `[Job]` → `@State private var jobs: [Job]` updates →
`Table` re-renders.

## Job model

Confirmed live against the cluster (see verification below):

```swift
struct Job: Identifiable {
    let id: String          // JOBID
    let partition: String   // PARTITION
    let name: String        // NAME (untruncated, unlike default squeue's 8-char column)
    let state: String       // STATE (e.g. RUNNING, PENDING)
    let time: String        // TIME (elapsed)
    let nodes: String       // NODES (count)
    let reason: String      // NODELIST(REASON)
    let timeLimit: String   // TIME_LIMIT
    let cpus: String        // CPUS
    let minMemory: String   // MIN_MEMORY
}
```

squeue format string: `%i|%P|%j|%T|%M|%D|%R|%l|%C|%m`

### Verification

Ran directly against Snellius-Large:

```
$ ssh -o BatchMode=yes -o ConnectTimeout=10 Snellius-Large \
    'squeue -u $(whoami) -o "%i|%P|%j|%T|%M|%D|%R|%l|%C|%m"'

JOBID|PARTITION|NAME|STATE|TIME|NODES|NODELIST(REASON)|TIME_LIMIT|CPUS|MIN_MEMORY
24611463|gpu_h100|lms-gemma4-train|RUNNING|3:03:26|1|gcn159|5-00:00:00|64|180G
24611653|gpu_h100|lms-gemma4-test|RUNNING|2:53:46|1|gcn84|5-00:00:00|64|180G
```

Key-based auth succeeded with `BatchMode=yes` (no interactive 2FA prompt
needed — agent already had the key loaded). Confirms the `-o` format
produces clean, parseable, pipe-delimited output with full (untruncated)
job names.

## Job scope

`squeue -u <user>` with no state filter shows both RUNNING and PENDING jobs
(and any other active state) — the `state` column disambiguates. Confirmed
as the desired scope (not filtered to `-t RUNNING`).

## Error handling

If the `Process` exits non-zero or stderr is non-empty: show the raw stderr
in a banner, plus a static hint:

> "Open a terminal and run `ssh Snellius-Large` once to establish a
> session, then retry."

No `BatchMode`/`ConnectTimeout` flags added to the app's own SSH call, no
retry loop — this was an explicit choice over adding a fast-timeout
fallback.

## Sandbox change required

The project currently has `ENABLE_APP_SANDBOX = YES` (Debug and Release).
This must be flipped to `NO` — `Process` cannot exec `/usr/bin/ssh` under
App Sandbox, and this app is a personal local tool, not App Store-bound.

## Existing template cleanup

The default Xcode template's SwiftData scaffold (`Item.swift`,
`ModelContainer` in `Job_TrackerApp.swift`, the `NavigationSplitView` list in
`ContentView.swift`) is unrelated to this feature and will be deleted, not
adapted.

## Testing

One test: given a sample multi-line pipe-delimited `squeue -o` output
string, assert the parser produces the expected `[Job]` array (covers
multiple jobs, field order, and the untruncated-name case). No test for the
live `Process`/SSH call (requires a real cluster) or for the SwiftUI view
(trivial rendering, no branching logic).
