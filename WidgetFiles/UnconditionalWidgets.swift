import WidgetKit
import SwiftUI
import AppIntents

// "I'm spiraling", one tap from outside the app: a lock screen widget and a
// Control Center button. Both open unconditional://reset, which the app answers
// by opening a thought reset right away.
//
// The words on the lock screen are deliberately neutral ("take a breath"),
// since anyone glancing at your phone can see them.

private let resetURL = URL(string: "unconditional://reset")!

struct BreathEntry: TimelineEntry {
    let date: Date
}

/// Nothing changes over time, so there's one entry and no refreshes.
struct BreathProvider: TimelineProvider {
    func placeholder(in context: Context) -> BreathEntry { BreathEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (BreathEntry) -> Void) {
        completion(BreathEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BreathEntry>) -> Void) {
        completion(Timeline(entries: [BreathEntry(date: .now)], policy: .never))
    }
}

struct BreathWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "wind")
                        .font(.title3)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label("take a breath", systemImage: "wind")
                        .font(.headline)
                    Text("one tap to slow down")
                        .font(.caption)
                }
            case .accessoryInline:
                Label("take a breath", systemImage: "wind")
            default:
                VStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.title)
                    Text("take a breath")
                        .font(.headline)
                }
            }
        }
        .widgetURL(resetURL)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct BreathWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BreathWidget", provider: BreathProvider()) { _ in
            BreathWidgetView()
        }
        .configurationDisplayName("Take a breath")
        .description("One tap to a thought reset when things feel like a lot.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

/// A Control Center (and Action button) control that opens a thought reset.
struct BreathControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rubinchang.Unconditional.breath") {
            ControlWidgetButton(action: OpenURLIntent(resetURL)) {
                Label("Take a breath", systemImage: "wind")
            }
        }
        .displayName("Take a breath")
        .description("Opens a thought reset in Unconditional.")
    }
}

@main
struct UnconditionalWidgets: WidgetBundle {
    var body: some Widget {
        BreathWidget()
        BreathControl()
    }
}
