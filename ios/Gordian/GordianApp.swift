import SwiftUI
import SwiftData

@main
struct GordianApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: DecisionLog.self)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()

    init() {
        FollowUpManager.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
