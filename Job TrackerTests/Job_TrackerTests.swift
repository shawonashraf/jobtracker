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

    @Test func shellQuotedWrapsPlainValueInSingleQuotes() async throws {
        #expect(SlurmJobFetcher.shellQuoted("sashraf1") == "'sashraf1'")
    }

    @Test func shellQuotedPreservesShellMetacharactersAsLiteralText() async throws {
        #expect(SlurmJobFetcher.shellQuoted("sashraf1; whoami") == "'sashraf1; whoami'")
        #expect(SlurmJobFetcher.shellQuoted("%i|%P|%j") == "'%i|%P|%j'")
    }

    @Test func shellQuotedEscapesEmbeddedSingleQuotes() async throws {
        #expect(SlurmJobFetcher.shellQuoted("a'b") == "'a'\\''b'")
    }

}
