# AGENTS.md

Guidance for AI coding agents working on this repository.

## Project

**Job Tracker** is a native macOS SwiftUI menu/table app that shows your Slurm
job queue (`squeue`) for a remote cluster without keeping a terminal open. It
reads host aliases from `~/.ssh/config`, then shells out to `/usr/bin/ssh` to run
`squeue` on the selected host and renders the parsed rows in a SwiftUI table.

- Language: Swift 5 (Xcode 26.6), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
  `SWIFT_APPROCHABLE_CONCURRENCY = YES`.
- Target: macOS 26.5+ (arm64/x86_64). Bundle id `org.shawonashraf.Job-Tracker`.
- App Sandbox is **off** (required so `Process` can launch `/usr/bin/ssh`);
  Hardened Runtime is on. Code-signed with the `VF3Y7UU4D6` dev team.

## Commands

The project name contains a space — **always quote** `"Job Tracker"` in shell
commands. There is no separate lint/typecheck step; Swift compilation during
build/test is the typecheck.

```bash
# Run the unit tests (Swift Testing suite in Job TrackerTests/)
xcodebuild test \
  -project "Job Tracker.xcodeproj" \
  -scheme "Job Tracker" \
  -destination 'platform=macOS'

# Release build of the .app + zip into ./build/
./build.sh

# Same build, then tag v<MARKETING_VERSION> and create a GitHub release with the zip
./build.sh release     # needs `gh` authed with the `workflow` scope

# Install the latest release locally (download + copy + quarantine strip)
./install.sh
```

Run tests/build from the repo root. After non-trivial Swift changes, run the
`xcodebuild test` command above before claiming work is complete.

## Source map

| File | Role |
|------|------|
| `Job Tracker/Job_TrackerApp.swift` | `@main` SwiftUI entry, `WindowGroup` → `ContentView`. |
| `Job Tracker/ContentView.swift` | UI: host picker, fetch trigger, SwiftUI table of jobs. |
| `Job Tracker/Job.swift` | `Job` value type (10 `squeue` fields). |
| `Job Tracker/SSHConfigReader.swift` | Parses `~/.ssh/config` for a `Host` alias → `hostname`/`user`. |
| `Job Tracker/SlurmJobFetcher.swift` | `parse(squeueOutput:)`, `fetchJobs(...)`, `shellQuoted(_:)`, `isSnellius(_:)`. |
| `Job TrackerTests/Job_TrackerTests.swift` | Swift Testing (`@Test`, `#expect`) — covers parsing, ssh-config parsing, shell quoting, Snellius host detection. |
| `build.sh` / `install.sh` | Release build/zip/`gh release`; download-and-install with Gatekeeper handling. |

## Conventions

- **Testing framework is Swift Testing** (`import Testing`, `@Test`, `#expect`),
  not XCTest. Add new tests in the same style next to the existing ones.
- **Shell-injection safety is load-bearing.** Any value interpolated into the
  remote `ssh` command must pass through `SlurmJobFetcher.shellQuoted(_:)`
  (single-quote wrapping with `'\\''` escaping). Keep `username` and
  `squeueFormat` quoted in `fetchJobs`. Don't drop this when refactoring.
- **Drain ssh stdout and stderr concurrently** in `fetchJobs` — a blocking
  sequential read can deadlock once stderr fills the OS pipe buffer. The current
  `DispatchGroup` approach exists for this reason; preserve it.
- **Snellius handling:** `isSnellius(_:)` matches `snellius.surf.nl` and its
  `*.snellius.surf.nl` subdomains, in which case `fetchJobs` targets the
  `Snellius-Large` alias with `-o HostName=`. Don't hardcode other cluster
  aliases.
- **Tests must not contain personal hostnames/usernames.** Use generic fixtures
  (e.g. `snellius` / `snellius_user`).

## Release / distribution

Distribution is **dev-signed + quarantine-strip**, not notarized. `build.sh`
builds Release, verifies the code signature, and `ditto`s the `.app` into
`Job-Tracker-<MARKETING_VERSION>.zip`. `install.sh` downloads the latest GitHub
release asset, copies to `/Applications/`, and runs `xattr -cr` to clear
Gatekeeper's quarantine flag (sufficient for local/team distribution).

Bump the version by editing `MARKETING_VERSION` in
`Job Tracker.xcodeproj/project.pbxproj` — both scripts read it from there.

## Repo notes

- Default branch: `main`. GitHub repo is `shawonashraf/jobtracker` (the
  `rashomon-gh/jobtracker` remote is a redirect — works, but prefer the
  canonical name in URLs/scripts).
- Don't commit `build/` or `*.zip` (gitignored).
