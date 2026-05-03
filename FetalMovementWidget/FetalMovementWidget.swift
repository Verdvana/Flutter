import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    // 获取 SwiftData 容器（需要与主 App 保持一致）
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([FetalMovementSession.self, FetalMovementRecord.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), count: fetchTodayCount())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date(), count: fetchTodayCount())
        // 每 15 分钟尝试刷新一次，或者在 App 内数据变化时手动触发刷新
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
        completion(timeline)
    }

    // ✨ 核心逻辑：从 SwiftData 中查询今天的总数
    private func fetchTodayCount() -> Int {
        let context = ModelContext(Provider.sharedModelContainer)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        let descriptor = FetchDescriptor<FetalMovementSession>(
            predicate: #Predicate<FetalMovementSession> { 
                $0.startDate >= startOfDay && !$0.isDiscarded 
            }
        )
        
        do {
            let sessions = try context.fetch(descriptor)
            return sessions.reduce(0) { $1.records.filter { $0.isValidated }.count + $0 }
        } catch {
            return 0
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let count: Int
}

// MARK: - 复杂表盘视图渲染
struct FetalMovementWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            if family == .accessoryCircular {
                // 圆形表盘（如计时器边角）
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: -2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.fitnessGreen)
                        Text("\(entry.count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                    }
                }
            } else {
                // 矩形或较大表盘
                VStack(alignment: .leading) {
                    Label("今日胎动", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.fitnessGreen)
                    Text("\(entry.count) 次")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                }
                .containerBackground(Color.black.gradient, for: .widget)
            }
        }
    }
}

// MARK: - Widget 定义
struct FetalMovementWidget: Widget {
    let kind: String = "FetalMovementWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FetalMovementWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("胎动统计")
        .description("在表盘显示今日胎动总数。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}


