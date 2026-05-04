import ActivityKit
import WidgetKit
import SwiftUI

struct FetalMovementActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var count: Int
        var startDate: Date
        var endDate: Date?
    }

    var sessionID: String
}

private extension Color {
    static let fitnessGreen = Color(red: 0.66, green: 1.0, blue: 0.0)
    static let fitnessLightGray = Color(red: 0.55, green: 0.55, blue: 0.57)
}

struct FetalMovementLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FetalMovementActivityAttributes.self) { context in
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("胎动记录中", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Color.fitnessGreen)

                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(context.state.count)")
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.fitnessGreen)
                            Text("次")
                                .font(.headline)
                                .foregroundStyle(Color.fitnessGreen)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("记录时间")
                            .font(.caption2)
                            .foregroundStyle(Color.fitnessLightGray)
                        Text(timerInterval: context.state.startDate...(context.state.endDate ?? .now), countsDown: false)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(Color.fitnessGreen)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("胎动", systemImage: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.fitnessGreen)
                        Text("\(context.state.count) 次")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.fitnessGreen)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("记录时间")
                            .font(.caption2)
                            .foregroundStyle(Color.fitnessLightGray)
                        Text(timerInterval: context.state.startDate...(context.state.endDate ?? .now), countsDown: false)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.yellow)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.fitnessGreen.opacity(0.2))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.fitnessGreen)
                            }
                        Text("持续记录中，返回 App 可结束本次监测")
                            .font(.caption)
                            .foregroundStyle(Color.fitnessLightGray)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.fitnessGreen)
            } compactTrailing: {
                Text("\(context.state.count)")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.fitnessGreen)
            } minimal: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.fitnessGreen)
            }
            .keylineTint(Color.fitnessGreen)
        }
    }
}
