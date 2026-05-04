#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct FetalMovementActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var count: Int
        var startDate: Date
        var endDate: Date?
    }

    var sessionID: String
}

@MainActor
final class FetalMovementLiveActivityManager {
    static let shared = FetalMovementLiveActivityManager()

    private init() {}

    func activateIfNeeded(for session: FetalMovementSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let sessionID = session.resolvedSessionID
        let content = activityContent(for: session)

        Task {
            if let existingActivity = activity(forSessionID: sessionID) {
                await existingActivity.update(content)
                return
            }

            do {
                _ = try Activity.request(
                    attributes: FetalMovementActivityAttributes(sessionID: sessionID),
                    content: content,
                    pushType: nil
                )
            } catch {
                print("Live Activity request failed: \(error)")
            }
        }
    }

    func updateIfActive(for session: FetalMovementSession) {
        let sessionID = session.resolvedSessionID
        guard let existingActivity = activity(forSessionID: sessionID) else { return }
        let content = activityContent(for: session)

        Task {
            await existingActivity.update(content)
        }
    }

    func endIfActive(for session: FetalMovementSession, discard: Bool) {
        let sessionID = session.resolvedSessionID
        guard let existingActivity = activity(forSessionID: sessionID) else { return }

        var finalSession = session
        if discard {
            finalSession.endDate = Date()
        }
        let content = activityContent(for: finalSession)

        Task {
            await existingActivity.end(content, dismissalPolicy: .immediate)
        }
    }

    func endAllExcept(sessionID: String?) {
        let activitiesToEnd = Activity<FetalMovementActivityAttributes>.activities.filter { activity in
            activity.attributes.sessionID != sessionID
        }

        for activity in activitiesToEnd {
            let finalContent = ActivityContent(
                state: FetalMovementActivityAttributes.ContentState(
                    count: activity.content.state.count,
                    startDate: activity.content.state.startDate,
                    endDate: Date()
                ),
                staleDate: nil
            )

            Task {
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
        }
    }

    private func activity(forSessionID sessionID: String) -> Activity<FetalMovementActivityAttributes>? {
        Activity<FetalMovementActivityAttributes>.activities.first { activity in
            activity.attributes.sessionID == sessionID
        }
    }

    private func activityContent(for session: FetalMovementSession) -> ActivityContent<FetalMovementActivityAttributes.ContentState> {
        ActivityContent(
            state: FetalMovementActivityAttributes.ContentState(
                count: session.count,
                startDate: session.startDate,
                endDate: session.endDate
            ),
            staleDate: nil
        )
    }
}
#endif
