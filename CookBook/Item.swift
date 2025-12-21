//
//  Item.swift
//  CookBook
//
//  Created by Caleb Stanberry on 12/20/25.
//

import Foundation
import SwiftData

@Model
class Item {
    var url: String
    var title: String?
    var siteName: String?
    var imagePath: String?
    var iconPath: String?
    var timestamp: Date

    init(url: String) {
        self.url = url
        self.timestamp = Date()
    }
}
