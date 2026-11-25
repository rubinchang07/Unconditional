import SwiftUI

/// Three tabs. Reframe isn't a tab: it opens as a step after saving an entry on Today.
struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            WinsView()
                .tabItem { Label("Wins", systemImage: "star") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
        }
    }
}
