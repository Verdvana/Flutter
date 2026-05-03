import SwiftUI
import SwiftData
import Observation
import WidgetKit
import WatchConnectivity

// MARK: - 主视图 (watchOS)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FetalMovementSession.startDate, order: .reverse) 
    private var allSessions: [FetalMovementSession]
    
    @State private var manager: FetalMovementManager?
    
    var body: some View {
        NavigationStack {
            Group {
                if let manager = manager {
                    if let _ = manager.activeSession {
                        MainRecordingView().environment(manager)
                    } else {
                        HomeListView(manager: manager, sessions: allSessions)
                            .id(manager.refreshID)
                    }
                } else {
                    ProgressView().tint(Color.fitnessGreen)
                }
            }
        }
        .onAppear { if manager == nil { manager = FetalMovementManager(modelContext: modelContext) } }
    }
}

struct HomeListView: View {
    @Environment(\.modelContext) private var modelContext
    let manager: FetalMovementManager
    let sessions: [FetalMovementSession]
    var history: [FetalMovementSession] { sessions.filter { !$0.isDiscarded && $0.endDate != nil } }
    
    var body: some View {
        List {
            Section {
                Button(action: { manager.startNewSession() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.fitnessGreen)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("开始记录")
                                .font(.headline)
                                .foregroundStyle(Color.fitnessGreen)
                            Text("监测今日胎动")
                                .font(.caption2)
                                .foregroundStyle(Color.fitnessLightGray)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listRowBackground(Color.fitnessGreen.opacity(0.15).clipShape(RoundedRectangle(cornerRadius: 16)))
            
            Section {
                if history.isEmpty {
                    Text("暂无记录")
                        .font(.caption2)
                        .foregroundStyle(Color.fitnessLightGray)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(history.prefix(5)) { session in 
                        HistoryRowView(session: session)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(session)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                Text("最近记录")
                    .foregroundStyle(Color.fitnessLightGray)
            }
        }
        .navigationTitle("摘要")
    }
}

struct HistoryRowView: View {
    let session: FetalMovementSession
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.body)
                .foregroundStyle(Color.fitnessGreen)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startDate.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundStyle(Color.fitnessLightGray)
                Text(session.startDate.formatted(.dateTime.hour().minute()))
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(session.count)")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(Color.fitnessGreen)
                Text("次")
                    .font(.system(size: 10, design: .rounded).bold())
                    .foregroundStyle(Color.fitnessGreen)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.fitnessDarkGray.clipShape(RoundedRectangle(cornerRadius: 12)))
    }
}

struct MainRecordingView: View {
    @Environment(FetalMovementManager.self) private var manager
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            if let session = manager.activeSession {
                Spacer(minLength: 4)
                
                // Big Metric
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(session.count)")
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fitnessGreen)
                        .scaleEffect(pulseScale)
                        .onChange(of: manager.clickTrigger) { 
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { pulseScale = 1.2 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { 
                                withAnimation { pulseScale = 1.0 } 
                            } 
                        }
                    Text("次")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(Color.fitnessGreen)
                }
                
                // Secondary Metrics
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("时长")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.fitnessLightGray)
                        TimelineView(.periodic(from: session.startDate, by: 1)) { context in 
                            let displayDate = session.endDate ?? context.date
                            Text(formatDuration(displayDate.timeIntervalSince(session.startDate)))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("点击")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.fitnessLightGray)
                        Text("\(session.count + manager.rawClickCount)")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.bottom, 12)
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: { manager.tryEndSession() }) {
                        Image(systemName: "xmark")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { manager.logMovement() }) {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.black)
                            .frame(width: 72, height: 48)
                            .background(Color.fitnessGreen)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .alert("时长不足", isPresented: Binding(get: { manager.showValidityAlert }, set: { manager.showValidityAlert = $0 })) {
            Button("保存", role: .none) { manager.finalizeSession(discard: false) }
            Button("放弃", role: .destructive) { manager.finalizeSession(discard: true) }
            Button("继续", role: .cancel) { manager.showValidityAlert = false }
        } message: { Text("本次记录不足 20 分钟。") }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(max(0, duration)) / 60; let secs = Int(max(0, duration)) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - ⚙️ Logic Manager
@MainActor
@Observable
final class FetalMovementManager {
    private var modelContext: ModelContext
    private let staleSessionThreshold: TimeInterval = 12 * 60 * 60
    var activeSession: FetalMovementSession?; var showValidityAlert: Bool = false; var clickTrigger: Bool = false; var rawClickCount: Int = 0; var refreshID: UUID = UUID()
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        WatchAppSyncCoordinator.shared.configure(modelContext: modelContext)
        backfillMissingIdentifiers()
        reloadFromStore()
        NotificationCenter.default.addObserver(
            forName: WatchAppSyncNotification.didApplyRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromStore()
        }
    }
    func startNewSession(at date: Date = .now) {
        let session = FetalMovementSession(startDate: date)
        modelContext.insert(session)
        activeSession = session
        rawClickCount = 0
        saveContext()
        WatchAppSyncCoordinator.shared.sendSessionStarted(session)
    }
    func logMovement() {
        let now = Date(); clickTrigger.toggle(); if activeSession == nil { startNewSession(at: now) }
        guard let session = activeSession else { return }
        let validatedRecords = session.records.filter { $0.isValidated }.sorted(by: { $0.timestamp < $1.timestamp })
        var isValid = true; if let lastValidRecord = validatedRecords.last { if now.timeIntervalSince(lastValidRecord.timestamp) < 5 * 60 { isValid = false } }
        let record = FetalMovementRecord(timestamp: now, isValidated: isValid); session.records.append(record)
        if isValid { triggerHapticFeedback(.success) } else { rawClickCount += 1; triggerHapticFeedback(.directionDown) }
        saveContext()
        WatchAppSyncCoordinator.shared.sendMovementLogged(session: session, record: record)
        WidgetCenter.shared.reloadAllTimelines()
    }
    func tryEndSession() { if let session = activeSession { if !session.isDurationValid { showValidityAlert = true } else { finalizeSession(discard: false) } } }
    func finalizeSession(discard: Bool) {
        guard let session = activeSession else { return }
        if !discard { session.endDate = Date() }
        activeSession = nil; showValidityAlert = false
        saveContext()
        WatchAppSyncCoordinator.shared.sendSessionFinalized(session, discard: discard)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.rawClickCount = 0; self.refreshID = UUID() }
    }
    private func saveContext() { try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines() }
    private func backfillMissingIdentifiers() {
        let descriptor = FetchDescriptor<FetalMovementSession>()
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        var didChange = false
        for session in sessions {
            didChange = session.ensureIdentifiers() || didChange
        }

        if didChange {
            saveContext()
        }
    }
    private func reloadFromStore() {
        let descriptor = FetchDescriptor<FetalMovementSession>(
            predicate: #Predicate<FetalMovementSession> { session in
                session.endDate == nil && !session.isDiscarded
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let openSessions = (try? modelContext.fetch(descriptor)) ?? []
        activeSession = normalizeOpenSessions(openSessions)
        rawClickCount = max(0, (activeSession?.rawCount ?? 0) - (activeSession?.count ?? 0))
        refreshID = UUID()
        WidgetCenter.shared.reloadAllTimelines()
    }
    private func normalizeOpenSessions(_ openSessions: [FetalMovementSession]) -> FetalMovementSession? {
        guard !openSessions.isEmpty else { return nil }

        var sessions = openSessions.sorted { $0.startDate > $1.startDate }
        let newestSession = sessions.removeFirst()
        var didChange = false

        if newestSession.duration > staleSessionThreshold {
            newestSession.isDiscarded = true
            didChange = true
        }

        for staleSession in sessions {
            staleSession.isDiscarded = true
            didChange = true
        }

        if didChange {
            saveContext()
        }

        return newestSession.isDiscarded ? nil : newestSession
    }
    private func triggerHapticFeedback(_ type: HapticType = .success) {
        #if os(watchOS)
        WKInterfaceDevice.current().play((type == .success) ? .success : .directionDown)
        #else
        UIImpactFeedbackGenerator(style: (type == .success) ? .medium : .light).impactOccurred()
        #endif
    }
    enum HapticType { case success, debounced, directionDown }
}

enum ClickStatus { case none, success, debounced }

extension Color { 
    static let fitnessGreen = Color(red: 0.66, green: 1.0, blue: 0.0) 
    static let fitnessDarkGray = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let fitnessLightGray = Color(red: 0.55, green: 0.55, blue: 0.57)
}

extension FetalMovementSession {
    var count: Int { records.filter { $0.isValidated }.count }
    var rawCount: Int { records.count }
    var duration: TimeInterval { (endDate ?? .now).timeIntervalSince(startDate) }
    var isDurationValid: Bool { duration >= 20 * 60 }
}

enum WatchAppSyncEventType: String {
    case sessionStarted
    case movementLogged
    case sessionFinalized
}

enum WatchAppSyncPayloadKey {
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

enum WatchAppSyncNotification {
    static let didApplyRemoteChange = Notification.Name("FetalMovementSync.didApplyRemoteChange.watch")
}

@MainActor
final class WatchAppSyncCoordinator: NSObject, WCSessionDelegate {
    static let shared = WatchAppSyncCoordinator()

    private var modelContext: ModelContext?
    private var hasActivatedSession = false
    private var pendingUserInfoPayloads: [[String: Any]] = []
    private var pendingApplicationContext: [String: Any]?
    private var pendingIncomingUserInfos: [[String: Any]] = []
    private var pendingIncomingApplicationContext: [String: Any]?

    func bootstrap() {
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

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        bootstrap()
        backfillMissingIdentifiersIfNeeded()
        flushPendingIncomingData()
        flushOutgoingQueueIfNeeded()
    }

    func sendSessionStarted(_ session: FetalMovementSession) {
        sendGuaranteedUserInfo([
            WatchAppSyncPayloadKey.eventType: WatchAppSyncEventType.sessionStarted.rawValue,
            WatchAppSyncPayloadKey.sessionID: session.resolvedSessionID,
            WatchAppSyncPayloadKey.startDate: session.startDate.timeIntervalSince1970,
        ])
        updateApplicationContext(for: session)
    }

    func sendMovementLogged(session: FetalMovementSession, record: FetalMovementRecord) {
        sendGuaranteedUserInfo([
            WatchAppSyncPayloadKey.eventType: WatchAppSyncEventType.movementLogged.rawValue,
            WatchAppSyncPayloadKey.sessionID: session.resolvedSessionID,
            WatchAppSyncPayloadKey.startDate: session.startDate.timeIntervalSince1970,
            WatchAppSyncPayloadKey.recordID: record.resolvedRecordID,
            WatchAppSyncPayloadKey.timestamp: record.timestamp.timeIntervalSince1970,
            WatchAppSyncPayloadKey.isValidated: record.isValidated,
        ])
        updateApplicationContext(for: session)
    }

    func sendSessionFinalized(_ session: FetalMovementSession, discard: Bool) {
        sendGuaranteedUserInfo([
            WatchAppSyncPayloadKey.eventType: WatchAppSyncEventType.sessionFinalized.rawValue,
            WatchAppSyncPayloadKey.sessionID: session.resolvedSessionID,
            WatchAppSyncPayloadKey.startDate: session.startDate.timeIntervalSince1970,
            WatchAppSyncPayloadKey.endDate: (session.endDate ?? Date()).timeIntervalSince1970,
            WatchAppSyncPayloadKey.discard: discard,
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
        guard session.activationState == .activated else {
            pendingUserInfoPayloads.append(payload)
            return
        }
        session.transferUserInfo(payload)
    }

    private func updateApplicationContext(for session: FetalMovementSession) {
        guard WCSession.isSupported() else { return }

        var context: [String: Any] = [
            WatchAppSyncPayloadKey.sessionID: session.resolvedSessionID,
            WatchAppSyncPayloadKey.startDate: session.startDate.timeIntervalSince1970,
            WatchAppSyncPayloadKey.validCount: session.count,
            WatchAppSyncPayloadKey.rawCount: session.rawCount,
            WatchAppSyncPayloadKey.updatedAt: Date().timeIntervalSince1970,
        ]

        if let endDate = session.endDate {
            context[WatchAppSyncPayloadKey.endDate] = endDate.timeIntervalSince1970
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            pendingApplicationContext = context
            return
        }

        try? session.updateApplicationContext(context)
    }

    private func clearApplicationContext() {
        guard WCSession.isSupported() else { return }
        pendingApplicationContext = [:]
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext([:])
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.flushOutgoingQueueIfNeeded()
            self.flushPendingIncomingData()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            guard self.modelContext != nil else {
                self.pendingIncomingUserInfos.append(userInfo)
                return
            }
            self.applyUserInfo(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            guard self.modelContext != nil else {
                self.pendingIncomingApplicationContext = applicationContext
                return
            }
            self.applyApplicationContext(applicationContext)
        }
    }

    private func flushOutgoingQueueIfNeeded() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let queuedPayloads = pendingUserInfoPayloads
        pendingUserInfoPayloads.removeAll()
        for payload in queuedPayloads {
            session.transferUserInfo(payload)
        }

        if let context = pendingApplicationContext {
            pendingApplicationContext = nil
            try? session.updateApplicationContext(context)
        }
    }

    private func flushPendingIncomingData() {
        guard modelContext != nil else { return }

        if let context = pendingIncomingApplicationContext {
            pendingIncomingApplicationContext = nil
            applyApplicationContext(context)
        }

        let queuedUserInfos = pendingIncomingUserInfos
        pendingIncomingUserInfos.removeAll()
        for userInfo in queuedUserInfos {
            applyUserInfo(userInfo)
        }
    }

    private func applyUserInfo(_ userInfo: [String: Any]) {
        guard let rawType = userInfo[WatchAppSyncPayloadKey.eventType] as? String,
              let eventType = WatchAppSyncEventType(rawValue: rawType),
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
        guard let sessionID = applicationContext[WatchAppSyncPayloadKey.sessionID] as? String else { return }
        guard let startTimestamp = applicationContext[WatchAppSyncPayloadKey.startDate] as? TimeInterval else { return }

        let session = findSession(withID: sessionID, modelContext: modelContext)
            ?? createSession(id: sessionID, startDate: Date(timeIntervalSince1970: startTimestamp), modelContext: modelContext)

        if let endTimestamp = applicationContext[WatchAppSyncPayloadKey.endDate] as? TimeInterval {
            session.endDate = Date(timeIntervalSince1970: endTimestamp)
        }

        saveAndNotify(modelContext)
    }

    private func applySessionStarted(_ payload: [String: Any], modelContext: ModelContext) {
        guard let sessionID = payload[WatchAppSyncPayloadKey.sessionID] as? String,
              let startTimestamp = payload[WatchAppSyncPayloadKey.startDate] as? TimeInterval else {
            return
        }

        if findSession(withID: sessionID, modelContext: modelContext) == nil {
            _ = createSession(id: sessionID, startDate: Date(timeIntervalSince1970: startTimestamp), modelContext: modelContext)
            saveAndNotify(modelContext)
        }
    }

    private func applyMovementLogged(_ payload: [String: Any], modelContext: ModelContext) {
        guard let sessionID = payload[WatchAppSyncPayloadKey.sessionID] as? String,
              let startTimestamp = payload[WatchAppSyncPayloadKey.startDate] as? TimeInterval,
              let recordID = payload[WatchAppSyncPayloadKey.recordID] as? String,
              let timestamp = payload[WatchAppSyncPayloadKey.timestamp] as? TimeInterval,
              let isValidated = payload[WatchAppSyncPayloadKey.isValidated] as? Bool else {
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
        guard let sessionID = payload[WatchAppSyncPayloadKey.sessionID] as? String,
              let startTimestamp = payload[WatchAppSyncPayloadKey.startDate] as? TimeInterval else {
            return
        }

        let discard = payload[WatchAppSyncPayloadKey.discard] as? Bool ?? false
        let session = findSession(withID: sessionID, modelContext: modelContext)
            ?? createSession(id: sessionID, startDate: Date(timeIntervalSince1970: startTimestamp), modelContext: modelContext)

        if discard {
            modelContext.delete(session)
        } else if let endTimestamp = payload[WatchAppSyncPayloadKey.endDate] as? TimeInterval {
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
            NotificationCenter.default.post(name: WatchAppSyncNotification.didApplyRemoteChange, object: nil)
        } catch {
            print("Sync save failed: \(error)")
        }
    }

    private func backfillMissingIdentifiersIfNeeded() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<FetalMovementSession>()
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        var didChange = false
        for session in sessions {
            didChange = session.ensureIdentifiers() || didChange
        }

        if didChange {
            do {
                try modelContext.save()
            } catch {
                print("Identifier backfill failed: \(error)")
            }
        }
    }
}
