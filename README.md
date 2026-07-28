# Job Tracker

A macOS menu app that shows your Slurm job queue (`squeue`) for a remote cluster, without needing a terminal open.

## How it works

- Reads host entries from `~/.ssh/config` (`SSHConfigReader.swift`)
- Shells out to `ssh` to run `squeue` on the selected host (`SlurmJobFetcher.swift`)
- Parses the output into `Job` rows and displays them in a SwiftUI table (`ContentView.swift`)

## Requirements

- macOS, Xcode
- SSH access to a Slurm cluster, configured in `~/.ssh/config`

## Install

One line — downloads the latest release, copies the app to `/Applications`, and strips the macOS quarantine flag so it clears Gatekeeper:

```bash
curl -fsSL https://raw.githubusercontent.com/shawonashraf/jobtracker/main/install.sh | bash
```

## Running

Open `Job Tracker.xcodeproj` in Xcode and run.
