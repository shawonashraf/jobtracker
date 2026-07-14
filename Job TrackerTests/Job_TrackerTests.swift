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
