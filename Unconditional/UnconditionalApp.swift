import SwiftUI
import SwiftData

@main
struct UnconditionalApp: App {
    /// The SwiftData container: one on-device database holding every model type.
    /// Nothing leaves the phone (no iCloud) unless we add that later.
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Schema(AppSchema.models))
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

/// Every model type the app stores. The app and the tests share this list,
/// so a new model can't be forgotten in one of them.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Loop.self, Entry.self, Reframe.self, Win.self, PersonalValue.self, ResetThought.self,
        SavedReminder.self, ParkedThought.self, TinyStep.self, CareerReflection.self, MapLink.self,
    ]

    /// A throwaway database that lives only in memory. Used by the tests.
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema(models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
