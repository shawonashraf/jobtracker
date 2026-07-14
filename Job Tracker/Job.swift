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
