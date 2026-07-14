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
