import SwiftUI
import SwiftData

@main
struct UnconditionalApp: App {
    /// The SwiftData container: one on-device database holding every model type.
    /// Nothing leaves the phone (no iCloud) unless we add that later.
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Loop.self, Entry.self, Reframe.self, Win.self, PersonalValue.self)
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
    }()

    init() {
        Paper.applySerifNavigationTitles()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { LoopSeeder.seedIfNeeded(container.mainContext) }
        }
        // Puts a ModelContext in the environment, so views can use @Query and @Environment(\.modelContext).
        .modelContainer(container)
    }
}
