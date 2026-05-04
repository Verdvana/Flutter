import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60)))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

// MARK: - 复杂表盘视图渲染
struct FetalMovementWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                Text("胎动监测")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .containerBackground(Color.black.gradient, for: .widget)
        case .accessoryInline:
            Label("胎动监测", systemImage: "heart.fill")
        case .accessoryCorner:
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .widgetLabel {
                    Text("胎动")
                }
        default:
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(.white)
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
        .configurationDisplayName("胎动监测")
        .description("在表盘上快速启动胎动记录。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

// 颜色扩展已在 ContentView.swift 中定义，此处移除
