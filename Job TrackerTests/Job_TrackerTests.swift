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

    @Test func parsesHostnameAndUserForNamedAlias() async throws {
        let sample = """
        Host snellius
          HostName snellius.surf.nl
          User snellius_user
          ForwardX11 yes
          ControlMaster auto
          ControlPath ~/.ssh/sockets/%r@%h-%p
          ControlPersist 4h
        """

        let defaults = SSHConfigReader.parse(sample, alias: "snellius")

        #expect(defaults.hostname == "snellius.surf.nl")
        #expect(defaults.username == "snellius_user")
    }

    @Test func returnsEmptyDefaultsForUnknownAlias() async throws {
        let sample = """
        Host Snellius-Small
          HostName snellius.surf.nl
          User snellius_user
        """

        let defaults = SSHConfigReader.parse(sample, alias: "snellius")

        #expect(defaults.hostname == "")
        #expect(defaults.username == "")
    }

    @Test func shellQuotedWrapsPlainValueInSingleQuotes() async throws {
        #expect(SlurmJobFetcher.shellQuoted("snellius_user") == "'snellius_user'")
    }

    @Test func shellQuotedPreservesShellMetacharactersAsLiteralText() async throws {
        #expect(SlurmJobFetcher.shellQuoted("snellius_user; whoami") == "'snellius_user; whoami'")
        #expect(SlurmJobFetcher.shellQuoted("%i|%P|%j") == "'%i|%P|%j'")
    }

    @Test func shellQuotedEscapesEmbeddedSingleQuotes() async throws {
        #expect(SlurmJobFetcher.shellQuoted("a'b") == "'a'\\''b'")
    }

    @Test func isSnelliusMatchesExactAndSubdomainHostnames() async throws {
        #expect(SlurmJobFetcher.isSnellius("snellius.surf.nl"))
        #expect(SlurmJobFetcher.isSnellius("SNELLIUS.SURF.NL"))
        #expect(SlurmJobFetcher.isSnellius("login1.snellius.surf.nl"))
        #expect(!SlurmJobFetcher.isSnellius("notsnellius.surf.nl"))
    }

}
