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
