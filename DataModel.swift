import Foundation
import SwiftData

@Model
final class FetalMovementSession {
    var startDate: Date
    var endDate: Date?
    var isDiscarded: Bool = false
    @Relationship(deleteRule: .cascade) var records: [FetalMovementRecord] = []
    
    init(startDate: Date = .now) {
        self.startDate = startDate
    }
}

@Model
final class FetalMovementRecord {
    var timestamp: Date
    var isValidated: Bool
    
    init(timestamp: Date, isValidated: Bool) {
        self.timestamp = timestamp
        self.isValidated = isValidated
    }
}

@Model
final class AppSettings {
    var modeRawValue: String
    init(modeRawValue: String = "孕期模式") { self.modeRawValue = modeRawValue }
}
