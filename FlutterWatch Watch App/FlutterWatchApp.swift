import SwiftUI
import SwiftData

@main
struct FlutterWatch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [FetalMovementSession.self, FetalMovementRecord.self, AppSettings.self])
    }
}

