//
//  Item.swift
//  Ai助理Mac
//
//  Created by Akun on 2026/2/22.
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
