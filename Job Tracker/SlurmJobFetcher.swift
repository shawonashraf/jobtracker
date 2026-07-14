//
//  SlurmJobFetcher.swift
//  Job Tracker
//

import Foundation

enum SlurmJobFetcher {

    static let squeueFormat = "%i|%P|%j|%T|%M|%D|%R|%l|%C|%m"

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

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
            "squeue", "--noheader", "-u", shellQuoted(username), "-o", shellQuoted(squeueFormat)
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Drain stdout and stderr concurrently to avoid deadlock:
        // if child writes enough to stderr to fill the OS buffer before stdout is drained,
        // it blocks on stderr write, creating a deadlock (process can't exit, waitUntilExit hangs).
        let group = DispatchGroup()

        class Box<T> {
            var value: T
            init(_ value: T) { self.value = value }
        }

        let stdoutBox = Box<Data>(Data())
        let stderrBox = Box<Data>(Data())

        group.enter()
        DispatchQueue.global().async {
            stdoutBox.value = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            stderrBox.value = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.wait()
        process.waitUntilExit()

        let stdout = String(data: stdoutBox.value, encoding: .utf8) ?? ""
        let stderr = String(data: stderrBox.value, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw FetchError(message: message.isEmpty ? "ssh exited with status \(process.terminationStatus)" : message)
        }

        return parse(squeueOutput: stdout)
    }
}
