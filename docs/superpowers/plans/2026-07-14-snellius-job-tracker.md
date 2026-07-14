# Snellius Job Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS SwiftUI app showing the current user's SLURM jobs on Snellius (host alias `Snellius-Large`) in a table, refreshed manually via SSH.

**Architecture:** Three new Swift files (`Job`, `SlurmJobFetcher`, `SSHConfigReader`) plus a rewritten `ContentView`/`Job_TrackerApp`. `SlurmJobFetcher` shells out to `/usr/bin/ssh` via `Process` to run `squeue`, using the `Snellius-Large` alias with `-o HostName=`/`-o User=` overrides so it still inherits `ControlMaster` from `~/.ssh/config`. No persistence, no polling.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing (`import Testing`, `@Test`, `#expect`), Xcode 26 file-system-synchronized project (no manual `project.pbxproj` file-reference edits needed — files are picked up automatically from the `Job Tracker/` and `Job TrackerTests/` folders).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-snellius-job-tracker-design.md`
- squeue format string, exact: `%i|%P|%j|%T|%M|%D|%R|%l|%C|%m` (add `--noheader` to avoid a header-skipping branch in the parser — a simplification not contradicted by the spec, which only pins the fields/order)
- No SwiftData, no timers/polling, no retry loop, no `BatchMode`/`ConnectTimeout` flags on the app's own ssh call — all explicitly decided during brainstorming.
- Module name is `Job_Tracker` (underscore) even though the target/folder names have a space (`Job Tracker`) — see existing `@testable import Job_Tracker` in `Job TrackerTests/Job_TrackerTests.swift`.
- Build/test command: `xcodebuild test -scheme "Job Tracker" -destination 'platform=macOS' -only-testing:"Job TrackerTests"` (fast, skips UI tests, ~7s). Full suite (includes UI tests, ~26s): same command without `-only-testing`.

---

### Task 1: Job model + squeue output parser

**Files:**
- Create: `Job Tracker/Job.swift`
- Create: `Job Tracker/SlurmJobFetcher.swift`
- Modify (rewrite): `Job TrackerTests/Job_TrackerTests.swift`

**Interfaces:**
- Produces: `struct Job: Identifiable` with fields `id, partition, name, state, time, nodes, reason, timeLimit, cpus, minMemory: String`
- Produces: `enum SlurmJobFetcher` with `static let squeueFormat: String` and `static func parse(squeueOutput: String) -> [Job]`

- [ ] **Step 1: Write the failing test**

Replace the entire contents of `Job TrackerTests/Job_TrackerTests.swift` with:

```swift
//
//  Job_TrackerTests.swift
//  Job TrackerTests
//
//  Created by Shawon Ashraf on 14/07/2026.
//

import Testing
@testable import Job_Tracker

struct Job_TrackerTests {

    @Test func parsesSqueueOutputIntoJobs() async throws {
        let sample = """
        24611463|gpu_h100|lms-gemma4-train|RUNNING|3:03:26|1|gcn159|5-00:00:00|64|180G
        24611653|gpu_h100|lms-gemma4-test|RUNNING|2:53:46|1|gcn84|5-00:00:00|64|180G
        """

        let jobs = SlurmJobFetcher.parse(squeueOutput: sample)

        #expect(jobs.count == 2)

        #expect(jobs[0].id == "24611463")
        #expect(jobs[0].partition == "gpu_h100")
        #expect(jobs[0].name == "lms-gemma4-train")
        #expect(jobs[0].state == "RUNNING")
        #expect(jobs[0].time == "3:03:26")
        #expect(jobs[0].nodes == "1")
        #expect(jobs[0].reason == "gcn159")
        #expect(jobs[0].timeLimit == "5-00:00:00")
        #expect(jobs[0].cpus == "64")
        #expect(jobs[0].minMemory == "180G")

        #expect(jobs[1].id == "24611653")
        #expect(jobs[1].name == "lms-gemma4-test")
    }

    @Test func ignoresMalformedLines() async throws {
        let sample = "too|few|fields\n24611463|gpu_h100|lms-gemma4-train|RUNNING|3:03:26|1|gcn159|5-00:00:00|64|180G"

        let jobs = SlurmJobFetcher.parse(squeueOutput: sample)

        #expect(jobs.count == 1)
        #expect(jobs[0].id == "24611463")
    }

}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "Job Tracker" -destination 'platform=macOS' -only-testing:"Job TrackerTests" 2>&1 | tail -30`
Expected: FAIL to build — `Job.swift`/`SlurmJobFetcher.swift` don't exist yet, so `Job` and `SlurmJobFetcher` are undefined symbols.

- [ ] **Step 3: Write minimal implementation**

Create `Job Tracker/Job.swift`:

```swift
//
//  Job.swift
//  Job Tracker
//

import Foundation

struct Job: Identifiable {
    let id: String
    let partition: String
    let name: String
    let state: String
    let time: String
    let nodes: String
    let reason: String
    let timeLimit: String
    let cpus: String
    let minMemory: String
}
```

Create `Job Tracker/SlurmJobFetcher.swift`:

```swift
//
//  SlurmJobFetcher.swift
//  Job Tracker
//

import Foundation

enum SlurmJobFetcher {

    static let squeueFormat = "%i|%P|%j|%T|%M|%D|%R|%l|%C|%m"

    static func parse(squeueOutput: String) -> [Job] {
        squeueOutput
            .split(separator: "\n")
            .compactMap { line -> Job? in
                let fields = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                guard fields.count == 10 else { return nil }
                return Job(
                    id: fields[0],
                    partition: fields[1],
                    name: fields[2],
                    state: fields[3],
                    time: fields[4],
                    nodes: fields[5],
                    reason: fields[6],
                    timeLimit: fields[7],
                    cpus: fields[8],
                    minMemory: fields[9]
                )
            }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme "Job Tracker" -destination 'platform=macOS' -only-testing:"Job TrackerTests" 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`, both `parsesSqueueOutputIntoJobs` and `ignoresMalformedLines` pass.

- [ ] **Step 5: Commit**

```bash
git add "Job Tracker/Job.swift" "Job Tracker/SlurmJobFetcher.swift" "Job TrackerTests/Job_TrackerTests.swift"
git commit -m "Add Job model and squeue output parser"
```

---

### Task 2: SSHConfigReader — parse ~/.ssh/config for host defaults

**Files:**
- Create: `Job Tracker/SSHConfigReader.swift`
- Modify: `Job TrackerTests/Job_TrackerTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1
- Produces: `enum SSHConfigReader` with `struct Defaults { let hostname: String; let username: String }`, `static func parse(_ contents: String, alias: String) -> Defaults`, and `static func defaults(forAlias alias: String = "Snellius-Large", configPath: String = NSHomeDirectory() + "/.ssh/config") -> Defaults`

- [ ] **Step 1: Write the failing test**

Add this test to `Job TrackerTests/Job_TrackerTests.swift` (inside the existing `Job_TrackerTests` struct, after the Task 1 tests):

```swift
    @Test func parsesHostnameAndUserForNamedAlias() async throws {
        let sample = """
        Host lambda01.win.tue.nl
          HostName lambda01.win.tue.nl
          User shawon

        Host Snellius-Large
          HostName snellius.surf.nl
          User sashraf1
          ForwardX11 yes
          ControlMaster auto
          ControlPath ~/.ssh/sockets/%r@%h-%p
          ControlPersist 4h

        Host Snellius-Small
          HostName snellius.surf.nl
          User sashraf
        """

        let defaults = SSHConfigReader.parse(sample, alias: "Snellius-Large")

        #expect(defaults.hostname == "snellius.surf.nl")
        #expect(defaults.username == "sashraf1")
    }

    @Test func returnsEmptyDefaultsForUnknownAlias() async throws {
        let sample = """
        Host Snellius-Small
          HostName snellius.surf.nl
          User sashraf
        """

        let defaults = SSHConfigReader.parse(sample, alias: "Snellius-Large")

        #expect(defaults.hostname == "")
        #expect(defaults.username == "")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "Job Tracker" -destination 'platform=macOS' -only-testing:"Job TrackerTests" 2>&1 | tail -30`
Expected: FAIL to build — `SSHConfigReader` is undefined.

- [ ] **Step 3: Write minimal implementation**

Create `Job Tracker/SSHConfigReader.swift`:

```swift
//
//  SSHConfigReader.swift
//  Job Tracker
//

import Foundation

enum SSHConfigReader {

    struct Defaults {
        let hostname: String
        let username: String
    }

    static func parse(_ contents: String, alias: String) -> Defaults {
        var hostname = ""
        var username = ""
        var insideMatchingBlock = false

        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let key = parts[0].lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            if key == "host" {
                insideMatchingBlock = (value == alias)
                continue
            }

            guard insideMatchingBlock else { continue }

            if key == "hostname" {
                hostname = value
            } else if key == "user" {
                username = value
            }
        }

        return Defaults(hostname: hostname, username: username)
    }

    static func defaults(forAlias alias: String = "Snellius-Large", configPath: String = NSHomeDirectory() + "/.ssh/config") -> Defaults {
        guard let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return Defaults(hostname: "", username: "")
        }
        return parse(contents, alias: alias)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme "Job Tracker" -destination 'platform=macOS' -only-testing:"Job TrackerTests" 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`, all four tests (Task 1 + Task 2) pass.

- [ ] **Step 5: Commit**

```bash
git add "Job Tracker/SSHConfigReader.swift" "Job TrackerTests/Job_TrackerTests.swift"
git commit -m "Add SSHConfigReader for Snellius-Large host defaults"
```

---

### Task 3: SlurmJobFetcher.fetchJobs — live SSH call via Process

**Files:**
- Modify: `Job Tracker/SlurmJobFetcher.swift`

**Interfaces:**
- Consumes: `Job` (Task 1), `SlurmJobFetcher.parse` (Task 1)
- Produces: `SlurmJobFetcher.FetchError: Error { let message: String }`, `static func fetchJobs(hostname: String, username: String) throws -> [Job]`

This task has no unit test — per the spec, the live `Process`/SSH call requires a real cluster and isn't unit-tested. Its testable deliverable is a manual run against the real Snellius-Large cluster (Step 3 below).

- [ ] **Step 1: Add the error type and fetch function**

Append to `Job Tracker/SlurmJobFetcher.swift` (inside the `enum SlurmJobFetcher { ... }` body, after `parse`):

```swift

    struct FetchError: Error {
        let message: String
    }

    static func fetchJobs(hostname: String, username: String) throws -> [Job] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "HostName=\(hostname)",
            "-o", "User=\(username)",
            "Snellius-Large",
            "squeue", "--noheader", "-u", username, "-o", squeueFormat
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw FetchError(message: message.isEmpty ? "ssh exited with status \(process.terminationStatus)" : message)
        }

        return parse(squeueOutput: stdout)
    }
```

- [ ] **Step 2: Confirm the project still builds**

Run: `xcodebuild build -scheme "Job Tracker" -destination 'platform=macOS' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manually verify against the real cluster**

Run: `ssh -o BatchMode=yes -o ConnectTimeout=10 Snellius-Large 'squeue --noheader -u $(whoami) -o "%i|%P|%j|%T|%M|%D|%R|%l|%C|%m"'`
Expected: pipe-delimited lines matching the format `fetchJobs` expects (this exact command was already verified live in the design phase — this step just re-confirms the `--noheader` flag doesn't change anything else about the output).

- [ ] **Step 4: Commit**

```bash
git add "Job Tracker/SlurmJobFetcher.swift"
git commit -m "Add live squeue fetch over SSH to SlurmJobFetcher"
```

---

### Task 4: ContentView + Job_TrackerApp — wire up the UI

**Files:**
- Modify (rewrite): `Job Tracker/ContentView.swift`
- Modify (rewrite): `Job Tracker/Job_TrackerApp.swift`
- Delete: `Job Tracker/Item.swift`

**Interfaces:**
- Consumes: `Job` (Task 1), `SlurmJobFetcher.fetchJobs(hostname:username:)` (Task 3), `SlurmJobFetcher.FetchError` (Task 3), `SSHConfigReader.defaults(forAlias:configPath:)` (Task 2)
- Produces: `ContentView: View` (no public API consumed by later tasks)

No unit test for this task — it's SwiftUI view code with no branching logic beyond what's already tested in `SlurmJobFetcher`/`SSHConfigReader`. Verified manually via build + running the app (Step 4).

- [ ] **Step 1: Delete the unused SwiftData model**

```bash
rm "Job Tracker/Item.swift"
```

- [ ] **Step 2: Rewrite Job_TrackerApp.swift**

Replace the entire contents of `Job Tracker/Job_TrackerApp.swift` with:

```swift
//
//  Job_TrackerApp.swift
//  Job Tracker
//
//  Created by Shawon Ashraf on 14/07/2026.
//

import SwiftUI

@main
struct Job_TrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 3: Rewrite ContentView.swift**

Replace the entire contents of `Job Tracker/ContentView.swift` with:

```swift
//
//  ContentView.swift
//  Job Tracker
//
//  Created by Shawon Ashraf on 14/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var hostname: String
    @State private var username: String
    @State private var jobs: [Job] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    init() {
        let defaults = SSHConfigReader.defaults()
        _hostname = State(initialValue: defaults.hostname)
        _username = State(initialValue: defaults.username)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Hostname", text: $hostname)
                TextField("Username", text: $username)
                Button(action: refresh) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)
            }
            .padding([.horizontal, .top])

            if let errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                    Text("Open a terminal and run `ssh Snellius-Large` once to establish a session, then retry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Table(jobs) {
                TableColumn("Job ID", value: \.id)
                TableColumn("Partition", value: \.partition)
                TableColumn("Name", value: \.name)
                TableColumn("State", value: \.state)
                TableColumn("Time", value: \.time)
                TableColumn("Nodes", value: \.nodes)
                TableColumn("Reason", value: \.reason)
                TableColumn("Time Limit", value: \.timeLimit)
                TableColumn("CPUs", value: \.cpus)
                TableColumn("Min Memory", value: \.minMemory)
            }
        }
        .frame(minWidth: 900, minHeight: 400)
    }

    private func refresh() {
        errorMessage = nil
        isLoading = true
        let host = hostname
        let user = username

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fetched = try SlurmJobFetcher.fetchJobs(hostname: host, username: user)
                DispatchQueue.main.async {
                    jobs = fetched
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = (error as? SlurmJobFetcher.FetchError)?.message ?? error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 4: Build and manually run**

Run: `xcodebuild build -scheme "Job Tracker" -destination 'platform=macOS' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

Then open the project in Xcode (`open "Job Tracker.xcodeproj"`) and run it (Cmd+R). Expected: window opens with Hostname/Username fields pre-filled (`snellius.surf.nl` / `sashraf1`), an empty table, and a Refresh button. This will fail with a sandbox violation until Task 5 disables `ENABLE_APP_SANDBOX` — that's expected at this point; don't debug it here.

- [ ] **Step 5: Commit**

```bash
git add "Job Tracker/ContentView.swift" "Job Tracker/Job_TrackerApp.swift"
git rm "Job Tracker/Item.swift"
git commit -m "Wire up job table UI in ContentView, drop SwiftData scaffold"
```

---

### Task 5: Disable App Sandbox and verify end-to-end

**Files:**
- Modify: `Job Tracker.xcodeproj/project.pbxproj:401`
- Modify: `Job Tracker.xcodeproj/project.pbxproj:433`

**Interfaces:**
- Consumes: everything from Tasks 1-4
- Produces: nothing (final integration task)

- [ ] **Step 1: Flip ENABLE_APP_SANDBOX to NO in both build configurations**

Both lines currently read `ENABLE_APP_SANDBOX = YES;` (one under the Debug config, one under Release). Change both to:

```
ENABLE_APP_SANDBOX = NO;
```

- [ ] **Step 2: Confirm full test suite still passes**

Run: `xcodebuild test -scheme "Job Tracker" -destination 'platform=macOS' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: Manually run the app against the real cluster**

Run: `open "Job Tracker.xcodeproj"`, then Cmd+R in Xcode. Click Refresh with the pre-filled defaults (`snellius.surf.nl` / `sashraf1`).

Expected: table populates with the current jobs on Snellius-Large (or is empty with no error if there are none queued) — no sandbox violation, no error banner.

- [ ] **Step 4: Commit**

```bash
git add "Job Tracker.xcodeproj/project.pbxproj"
git commit -m "Disable App Sandbox so ssh can be shelled out to via Process"
```
