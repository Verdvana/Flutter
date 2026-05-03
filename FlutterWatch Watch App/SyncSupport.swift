import Foundation
import SwiftData
import WatchConnectivity

enum SyncEventType: String {
    case sessionStarted
    case movementLogged
    case sessionFinalized
}

enum SyncPayloadKey {
    static let eventType = "eventType"
    static let sessionID = "sessionID"
    static let startDate = "startDate"
    static let recordID = "recordID"
    static let timestamp = "timestamp"
    static let isValidated = "isValidated"
    static let endDate = "endDate"
    static let discard = "discard"
    static let validCount = "validCount"
    static let rawCount = "rawCount"
    static let updatedAt = "updatedAt"
}

enum SyncNotification {
    static let didApplyRemoteChange = Notification.Name("FetalMovementSync.didApplyRemoteChange")
}

@MainActor
final class WatchConnectivitySyncCoordinator: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivitySyncCoordinator()

    private var modelContext: ModelContext?
    private var hasActivatedSession = false

    private override init() {
        super.init()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        if session.delegate !== self {
            session.delegate = self
        }

        if !hasActivatedSession {
            session.activate()
            hasActivatedSession = true
        }
    }

    func sendSessionStarted(_ session: FetalMovementSession) {
        sendGuaranteedUserInfo([
            SyncPayloadKey.eventType: SyncEventType.sessionStarted.rawValue,
            SyncPayloadKey.sessionID: session.sessionID,
            SyncPayloadKey.startDate: session.startDate.timeIntervalSince1970,
        ])
        updateApplicationContext(for: session)
    }

    func sendMovementLogged(session: FetalMovementSession, record: FetalMovementRecord) {
        sendGuaranteedUserInfo([
            SyncPayloadKey.eventType: SyncEventType.movementLogged.rawValue,
            SyncPayloadKey.sessionID: session.sessionID,
            SyncPayloadKey.startDate: session.startDate.timeIntervalSince1970,
            SyncPayloadKey.recordID: record.recordID,
            SyncPayloadKey.timestamp: record.timestamp.timeIntervalSince1970,
            SyncPayloadKey.isValidated: record.isValidated,
        ])
        updateApplicationContext(for: session)
    }

    func sendSessionFinalized(_ session: FetalMovementSession, discard: Bool) {
        sendGuaranteedUserInfo([
            SyncPayloadKey.eventType: SyncEventType.sessionFinalized.rawValue,
            SyncPayloadKey.sessionID: session.sessionID,
            SyncPayloadKey.startDate: session.startDate.timeIntervalSince1970,
            SyncPayloadKey.endDate: (session.endDate ?? Date()).timeIntervalSince1970,
            SyncPayloadKey.discard: discard,
        ])

        if discard {
            clearApplicationContext()
        } else {
            updateApplicationContext(for: session)
        }
    }

    private func sendGuaranteedUserInfo(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else { return }

        session.transferUserInfo(payload)
    }

    private func updateApplicationContext(for session: FetalMovementSession) {
        guard WCSession.isSupported() else { return }

        let context: [String: Any] = [
            SyncPayloadKey.sessionID: session.sessionID,
            SyncPayloadKey.startDate: session.startDate.timeIntervalSince1970,
            SyncPayloadKey.validCount: session.count,
            SyncPayloadKey.rawCount: session.rawCount,
            SyncPayloadKey.updatedAt: Date().timeIntervalSince1970,
            SyncPayloadKey.endDate: session.endDate?.timeIntervalSince1970 as Any,
        ]

        try? WCSession.default.updateApplicationContext(context)
    }

    private func clearApplicationContext() {
        guard WCSession.isSupported() else { return }
        try? WCSession.default.updateApplicationContext([:])
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.applyUserInfo(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.applyApplicationContext(applicationContext)
        }
    }

    private func applyUserInfo(_ userInfo: [String: Any]) {
        guard let rawType = userInfo[SyncPayloadKey.eventType] as? String,
              let eventType = SyncEventType(rawValue: rawType),
              let modelContext else {
            return
        }

        switch eventType {
        case .sessionStarted:
            applySessionStarted(userInfo, modelContext: modelContext)
        case .movementLogged:
            applyMovementLogged(userInfo, modelContext: modelContext)
        case .sessionFinalized:
            applySessionFinalized(userInfo, modelContext: modelContext)
        }
    }

    private func applyApplicationContext(_ applicationContext: [String: Any]) {
        guard let modelContext else { return }
        guard let sessionID = applicationContext[SyncPayloadKey.sessionID] as? String else { return }
        guard let startTimestamp = applicationContext[SyncPayloadKey.startDate] as? TimeInterval else { return }

        let session = findSession(withID: sessionID, modelContext: modelContext)
            ?? createSession(id: sessionID, startDate: Date(timeIntervalSince1970: startTimestamp), modelContext: modelContext)

        if let endTimestamp = applicationContext[SyncPayloadKey.endDate] as? TimeInterval {
            session.endDate = Date(timeIntervalSince1970: endTimestamp)
        }

        saveAndNotify(modelContext)
    }

    private func applySessionStarted(_ payload: [String: Any], modelContext: ModelContext) {
        guard let sessionID = payload[SyncPayloadKey.sessionID] as? String,
              let startTimestamp = payload[SyncPayloadKey.startDate] as? TimeInterval else {
            return
        }

        if findSession(withID: sessionID, modelContext: modelContext) == nil {
            _ = createSession(id: sessionID, startDate: Date(timeIntervalSince1970: startTimestamp), modelContext: modelContext)
            saveAndNotify(modelContext)
        }
    }

    private func applyMovementLogged(_ payload: [String: Any], modelContext: ModelContext) {
        guard let sessionID = payload[SyncPayloadKey.sessionID] as? String,
              let startTimestamp = payload[SyncPayloadKey.startDate] as? TimeInterval,
              let recordID = payload[SyncPayloadKey.recordID] as? String,
              let timestamp = payload[SyncPayloadKey.timestamp] as? TimeInterval,
              let isValidated = payload[SyncPayloadKey.isValidated] as? Bool else {
            return
        }

        let session = findSession(withID: sessionID, modelContext: modelContext)
            ?? createSession(id: sessionID, startDate: Date(timeIntervalSince1970: startTimestamp), modelContext: modelContext)

        guard !session.records.contains(where: { $0.recordID == recordID }) else { return }

        let record = FetalMovementRecord(
            recordID: recordID,
            timestamp: Date(timeIntervalSince1970: timestamp),
            isValidated: isValidated
        )
        session.records.append(record)
        saveAndNotify(modelContext)
    }

    private func applySessionFinalized(_ payload: [String: Any], modelContext: ModelContext) {
        guard let sessionID = payload[SyncPayloadKey.sessionID] as? String,
              let startTimestamp = payload[SyncPayloadKey.startDate] as? TimeInterval else {
            return
        }

        let discard = payload[SyncPayloadKey.discard] as? Bool ?? false
        let session = findSession(withID: sessionID, modelContext: modelContext)
            ?? createSession(id: sessionID, startDate: Date(timeIntervalSince1970: startTimestamp), modelContext: modelContext)

        if discard {
            modelContext.delete(session)
        } else if let endTimestamp = payload[SyncPayloadKey.endDate] as? TimeInterval {
            session.endDate = Date(timeIntervalSince1970: endTimestamp)
        }

        saveAndNotify(modelContext)
    }

    private func findSession(withID sessionID: String, modelContext: ModelContext) -> FetalMovementSession? {
        let descriptor = FetchDescriptor<FetalMovementSession>(
            predicate: #Predicate<FetalMovementSession> { session in
                session.sessionID == sessionID
            }
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func createSession(id: String, startDate: Date, modelContext: ModelContext) -> FetalMovementSession {
        let session = FetalMovementSession(sessionID: id, startDate: startDate)
        modelContext.insert(session)
        return session
    }

    private func saveAndNotify(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: SyncNotification.didApplyRemoteChange, object: nil)
        } catch {
            print("Sync save failed: \(error)")
        }
    }
}
