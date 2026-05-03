import Foundation
import SwiftData
import SwiftUI

@Model
final class FetalMovementSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var isDiscarded: Bool
    
    @Relationship(deleteRule: .cascade)
    var records: [FetalMovementRecord] = []
    
    init(startDate: Date = .now) {
        self.id = UUID()
        self.startDate = startDate
        self.isDiscarded = false
        self.records = []
    }
    
    var count: Int {
        records.filter { $0.isValidated }.count
    }
    
    var rawCount: Int {
        records.count
    }
    
    var duration: TimeInterval {
        let end = endDate ?? .now
        return end.timeIntervalSince(startDate)
    }
    
    var isDurationValid: Bool {
        duration >= 20 * 60
    }
}

@Model
final class FetalMovementRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var isValidated: Bool
    
    init(timestamp: Date = .now, isValidated: Bool = true) {
        self.id = UUID()
        self.timestamp = timestamp
        self.isValidated = isValidated
    }
}

enum AppMode: String, Codable, CaseIterable {
    case prenatal = "孕期模式"
    case postpartum = "产后模式"
}

@Model
final class AppSettings {
    var modeRawValue: String
    
    init(mode: AppMode = .prenatal) {
        self.modeRawValue = mode.rawValue
    }
    
    var mode: AppMode {
        get { AppMode(rawValue: modeRawValue) ?? .prenatal }
        set { modeRawValue = newValue.rawValue }
    }
}

extension Color {
    static let neonGreen = Color(red: 0.66, green: 1.0, blue: 0.0)
}
