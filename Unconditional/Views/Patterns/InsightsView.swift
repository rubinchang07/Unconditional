import SwiftUI

/// One place for looking back: how things shift over time, and how they connect.
/// The weekly review and career reflections live at the bottom of Patterns.
struct InsightsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case patterns, map
        var id: String { rawValue }
        var label: String { self == .patterns ? "patterns" : "your map" }
    }
    @State private var tab: Tab = .patterns

    var body: some View {
        Group {
            switch tab {
            case .patterns: PatternsView()
            case .map: MapView()
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("Insights", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}
