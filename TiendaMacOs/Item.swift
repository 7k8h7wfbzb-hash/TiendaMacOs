//
//  Item.swift
//  TiendaMacOs
//
//  Created by kleber oswaldo muy landi on 25/3/26.
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
