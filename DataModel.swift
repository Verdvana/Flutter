import Foundation
import SwiftData

@Model
final class FetalMovementSession {
    var sessionID: String?
    var startDate: Date
    var endDate: Date?
    var isDiscarded: Bool = false
    @Relationship(deleteRule: .cascade) var records: [FetalMovementRecord] = []
    
    init(sessionID: String? = UUID().uuidString, startDate: Date = .now) {
        self.sessionID = sessionID
        self.startDate = startDate
    }
}

@Model
final class FetalMovementRecord {
    var recordID: String?
    var timestamp: Date
    var isValidated: Bool
    
    init(recordID: String? = UUID().uuidString, timestamp: Date, isValidated: Bool) {
        self.recordID = recordID
        self.timestamp = timestamp
        self.isValidated = isValidated
    }
}

@Model
final class AppSettings {
    var modeRawValue: String
    init(modeRawValue: String = "孕期模式") { self.modeRawValue = modeRawValue }
}

extension FetalMovementSession {
    var resolvedSessionID: String {
        if let sessionID, !sessionID.isEmpty { return sessionID }
        let newID = UUID().uuidString
        self.sessionID = newID
        return newID
    }

    @discardableResult
    func ensureIdentifiers() -> Bool {
        var didChange = false

        if sessionID == nil || sessionID?.isEmpty == true {
            sessionID = UUID().uuidString
            didChange = true
        }

        for record in records {
            if record.recordID == nil || record.recordID?.isEmpty == true {
                record.recordID = UUID().uuidString
                didChange = true
            }
        }

        return didChange
    }
}

extension FetalMovementRecord {
    var resolvedRecordID: String {
        if let recordID, !recordID.isEmpty { return recordID }
        let newID = UUID().uuidString
        self.recordID = newID
        return newID
    }
}
