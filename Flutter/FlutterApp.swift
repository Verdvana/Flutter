import SwiftUI
import SwiftData

@main
struct FlutterApp: App {
    init() {
        WatchConnectivitySyncCoordinator.shared.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [FetalMovementSession.self, FetalMovementRecord.self, AppSettings.self])
    }
}
