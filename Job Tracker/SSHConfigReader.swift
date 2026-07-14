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
