import SwiftUI
import SwiftData
import Charts
import Observation
import WidgetKit

// MARK: - 主视图 (iOS)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FetalMovementSession.startDate, order: .reverse) 
    private var allSessions: [FetalMovementSession]
    
    @State private var manager: FetalMovementManager?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    if let manager = manager {
                        Section {
                            if let active = manager.activeSession {
                                activeSessionView(active: active, manager: manager)
                            } else {
                                StartRecordButton(manager: manager)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    
                    HistorySectionView(sessions: allSessions)
                        .id(manager?.refreshID) 
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("摘要")
            .navigationBarTitleDisplayMode(.large)
            .alert("记录时长不足", isPresented: Binding(
                get: { manager?.showValidityAlert ?? false },
                set: { manager?.showValidityAlert = $0 }
            )) {
                Button("保存", role: .none) { manager?.finalizeSession(discard: false) }
                Button("放弃记录", role: .destructive) { manager?.finalizeSession(discard: true) }
                Button("继续", role: .cancel) { manager?.showValidityAlert = false }
            } message: {
                Text("本次监测不足 20 分钟，建议继续记录。")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if manager == nil { manager = FetalMovementManager(modelContext: modelContext) }
        }
    }
    
    @ViewBuilder
    private func activeSessionView(active: FetalMovementSession, manager: FetalMovementManager) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前记录")
                        .font(.headline)
                        .foregroundStyle(Color.fitnessLightGray)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(active.count)")
                            .font(.system(size: 72, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.fitnessGreen)
                        Text("次")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.fitnessGreen)
                            .padding(.bottom, 10)
                    }
                }
                Spacer()
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fitnessGreen)
            }
            
            Divider().background(Color.white.opacity(0.15))
            
            HStack(spacing: 30) {
                TimelineView(.periodic(from: active.startDate, by: 1)) { context in
                    workoutMetric(label: "已用时间", value: formatDuration(context.date.timeIntervalSince(active.startDate)), color: .yellow, isTime: true)
                }
                workoutMetric(label: "累计点击", value: "\(active.count + manager.rawClickCount)", color: .orange, isTime: false)
            }
            
            HStack(spacing: 16) {
                Button(action: { manager.tryEndSession() }) {
                    Image(systemName: "xmark")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                
                Button(action: { manager.logMovement() }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                        Text("记一次")
                            .font(.title3.bold())
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.fitnessGreen)
                    .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(20)
        .background(Color.fitnessDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func workoutMetric(label: String, value: String, color: Color, isTime: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.fitnessLightGray)
            Text(value)
                .font(.system(size: isTime ? 34 : 28, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(max(0, duration)) / 60; let secs = Int(max(0, duration)) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct HistorySectionView: View {
    let sessions: [FetalMovementSession]
    @Environment(\.modelContext) private var modelContext
    var history: [FetalMovementSession] { sessions.filter { !$0.isDiscarded && $0.endDate != nil } }
    
    var body: some View {
        Section {
            if history.isEmpty {
                Text("暂无数据")
                    .foregroundStyle(Color.fitnessLightGray)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(history) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        historyRow(session: session)
                    }
                    .listRowBackground(Color.fitnessDarkGray)
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
            Text("历史记录")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 0))
        }
    }
    
    @ViewBuilder
    private func historyRow(session: FetalMovementSession) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.fitnessGreen.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(Color.fitnessGreen)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("胎动监测")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(session.startDate.formatted(.dateTime.month().day().weekday())) · \(Int(session.duration / 60))分钟")
                    .font(.subheadline)
                    .foregroundStyle(Color.fitnessLightGray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.count)")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.fitnessGreen)
                Text("次")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.fitnessLightGray)
            }
        }
        .padding(.vertical, 8)
    }
}

struct SessionDetailView: View {
    let session: FetalMovementSession
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.fitnessLightGray)
                        .textCase(.uppercase)
                    
                    Text("监测摘要")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    detailMetricCard(label: "有效胎动", value: "\(session.count)", unit: "次", color: Color.fitnessGreen)
                    detailMetricCard(label: "监测时长", value: "\(Int(session.duration / 60))", unit: "分钟", color: .yellow)
                    detailMetricCard(label: "累计点击", value: "\(session.rawCount)", unit: "次", color: .orange)
                    detailMetricCard(label: "平均间隔", value: avgIntervalStr(), unit: "分钟", color: .cyan)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("活动分布")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Chart {
                            ForEach(session.records.sorted(by: { $0.timestamp < $1.timestamp })) { record in
                                if record.isValidated {
                                    BarMark(
                                        x: .value("时间", record.timestamp),
                                        yStart: .value("状态", 0),
                                        yEnd: .value("状态", 1),
                                        width: .fixed(8)
                                    )
                                    .foregroundStyle(Color.fitnessGreen.gradient)
                                    .cornerRadius(4)
                                } else {
                                    PointMark(
                                        x: .value("时间", record.timestamp),
                                        y: .value("状态", 0.5)
                                    )
                                    .foregroundStyle(Color.orange.opacity(0.6))
                                    .symbolSize(40)
                                }
                            }
                        }
                        .frame(height: 120)
                        .padding(.vertical, 8)
                        .chartXAxis {
                            AxisMarks(values: [session.startDate, session.endDate ?? .now]) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(.white.opacity(0.1))
                                AxisValueLabel(anchor: value.as(Date.self) == session.startDate ? .leading : .trailing) {
                                    if let date = value.as(Date.self) {
                                        Text(date.formatted(.dateTime.hour().minute()))
                                            .font(.caption2)
                                            .foregroundStyle(Color.fitnessLightGray)
                                    }
                                }
                            }
                        }
                        .chartYAxis(.hidden)
                        .chartYScale(domain: 0...1.2)
                        
                        HStack(spacing: 24) {
                            Label("有效记录", systemImage: "rectangle.portrait.fill").foregroundStyle(Color.fitnessGreen)
                            Label("被拦截的点击", systemImage: "circle.fill").foregroundStyle(Color.orange.opacity(0.6))
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(Color.fitnessDarkGray)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("详细记录")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        let sortedRecords = session.records.sorted(by: { $0.timestamp > $1.timestamp })
                        ForEach(sortedRecords) { record in
                            HStack {
                                Image(systemName: record.isValidated ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(record.isValidated ? Color.fitnessGreen : Color.orange)
                                
                                Text(record.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundStyle(record.isValidated ? .white : Color.fitnessLightGray)
                                
                                Spacer()
                                
                                if !record.isValidated {
                                    Text("频繁点击")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundStyle(Color.orange)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            
                            if record != sortedRecords.last {
                                Divider()
                                    .background(Color.white.opacity(0.15))
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color.fitnessDarkGray)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("摘要")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func avgIntervalStr() -> String {
        let validRecords = session.records.filter { $0.isValidated }.sorted(by: { $0.timestamp < $1.timestamp })
        guard validRecords.count > 1 else { return "--" }
        let totalInterval = validRecords.last!.timestamp.timeIntervalSince(validRecords.first!.timestamp)
        let avg = totalInterval / Double(validRecords.count - 1)
        return String(format: "%.1f", avg / 60)
    }
    
    private func detailMetricCard(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.fitnessLightGray)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.fitnessLightGray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.fitnessDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StartRecordButton: View {
    let manager: FetalMovementManager
    var body: some View {
        Button(action: { withAnimation(.spring()) { manager.startNewSession() } }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开始胎动监测")
                        .font(.title3.bold())
                        .foregroundStyle(.black)
                    Text("建议每天固定时间记录")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.7))
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.black)
            }
            .padding(20)
            .background(Color.fitnessGreen)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

@Observable
final class FetalMovementManager {
    private var modelContext: ModelContext
    var activeSession: FetalMovementSession?; var showValidityAlert: Bool = false; var clickTrigger: Bool = false; var rawClickCount: Int = 0; var refreshID: UUID = UUID()
    init(modelContext: ModelContext) { self.modelContext = modelContext }
    func startNewSession(at date: Date = .now) { let session = FetalMovementSession(startDate: date); modelContext.insert(session); activeSession = session; rawClickCount = 0; saveContext() }
    func logMovement() {
        let now = Date(); clickTrigger.toggle()
        if activeSession == nil { startNewSession(at: now) }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.saveContext(); self.rawClickCount = 0; self.refreshID = UUID() }
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
    static let neonGreen = Color(red: 0.66, green: 1.0, blue: 0.0) 
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
