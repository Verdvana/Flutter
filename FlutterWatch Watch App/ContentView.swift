import SwiftUI
import SwiftData
import Observation
import WidgetKit

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
@Observable
final class FetalMovementManager {
    private var modelContext: ModelContext
    var activeSession: FetalMovementSession?; var showValidityAlert: Bool = false; var clickTrigger: Bool = false; var rawClickCount: Int = 0; var refreshID: UUID = UUID()
    init(modelContext: ModelContext) { self.modelContext = modelContext }
    func startNewSession(at date: Date = .now) { let session = FetalMovementSession(startDate: date); modelContext.insert(session); activeSession = session; rawClickCount = 0; saveContext() }
    func logMovement() {
        let now = Date(); clickTrigger.toggle(); if activeSession == nil { startNewSession(at: now) }
        guard let session = activeSession else { return }
        let validatedRecords = session.records.filter { $0.isValidated }.sorted(by: { $0.timestamp < $1.timestamp })
        var isValid = true; if let lastValidRecord = validatedRecords.last { if now.timeIntervalSince(lastValidRecord.timestamp) < 5 * 60 { isValid = false } }
        let record = FetalMovementRecord(timestamp: now, isValidated: isValid); session.records.append(record)
        if isValid { triggerHapticFeedback(.success) } else { rawClickCount += 1; triggerHapticFeedback(.directionDown) }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func tryEndSession() { if let session = activeSession { if !session.isDurationValid { showValidityAlert = true } else { finalizeSession(discard: false) } } }
    func finalizeSession(discard: Bool) {
        guard let session = activeSession else { return }
        if !discard { session.endDate = Date() }
        activeSession = nil; showValidityAlert = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.saveContext(); self.rawClickCount = 0; self.refreshID = UUID() }
    }
    private func saveContext() { try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines() }
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
