//
//  Item.swift
//  Job Tracker
//
//  Created by Shawon Ashraf on 14/07/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
