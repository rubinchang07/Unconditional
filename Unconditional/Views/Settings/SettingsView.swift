import SwiftUI

/// Theme previews, daily reminder, and Face ID lock. Opens from the gear on Today.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Theme.storageKey) private var theme: Theme = .white
    @AppStorage(ReminderScheduler.enabledKey) private var reminderEnabled = false
    @AppStorage(ReminderScheduler.timeKey) private var reminderMinutes = ReminderScheduler.defaultMinutes
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = true
    @AppStorage("eveningWarmth") private var eveningWarmth = true
    @AppStorage(CareerReflection.enabledKey) private var careerEnabled = false

    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        LoopsManagerView()
                    } label: {
                        Label("Your loops", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Toggle(isOn: $careerEnabled) {
                        Label("Career check-ins", systemImage: "briefcase")
                    }
                } header: {
                    Text("Your journal")
                } footer: {
                    Text("Career check-ins add a short reflection after studying, applying, or interviewing. Turn them on if that's part of what you're working through.")
                }

                Section("Theme") {
                    HStack(spacing: 12) {
                        ForEach(Theme.allCases) { option in
                            ThemePreview(theme: option, isSelected: option == theme)
                                .onTapGesture {
                                    withAnimation(.easeInOut) { theme = option }
                                }
                        }
                    }
                    .padding(.vertical, 6)
                    Text(theme.mood)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    HStack(spacing: 16) {
                        ForEach(OrbPalette.allCases) { option in
                            Button {
                                withAnimation { orbPalette = option }
                            } label: {
                                VStack(spacing: 8) {
                                    OrbView(palette: option, speed: 0.6)
                                        .frame(width: 110, height: 110)
                                    Label(option.name, systemImage: option == orbPalette ? "checkmark.circle.fill" : "circle")
                                        .font(.footnote.weight(option == orbPalette ? .semibold : .regular))
                                        .foregroundStyle(option == orbPalette ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(option.name) orb")
                            .accessibilityAddTraits(option == orbPalette ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.vertical, 6)
                    Toggle("Evening warmth after 9 PM", isOn: $eveningWarmth)
                    Button("Replay the welcome tour") {
                        dismiss()
                        hasSeenWelcome = false
                    }
                } header: {
                    Text("Orb")
                }

                Section {
                    Toggle("Daily reminder", isOn: reminderBinding)
                    if reminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    if notificationsDenied {
                        Text("Notifications are turned off for Unconditional. You can allow them in the Settings app.")
                    } else {
                        Text("A gentle nudge, once a day. Skipping a day is fine.")
                    }
                }

                Section {
                    NavigationLink {
                        SupportView()
                    } label: {
                        Label("Support and crisis lines", systemImage: "lifepreserver")
                    }
                } footer: {
                    Text("If things feel like too much, you don't have to handle it alone.")
                }

                Section {
                    Toggle("Require Face ID", isOn: lockBinding)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Locks the journal whenever you leave the app. Falls back to your passcode if Face ID fails.")
                }
            }
            .navigationTitle("settings")
            .themedBackground()
            .paperList()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Bindings
    // A custom Binding runs our own code when a toggle changes,
    // e.g. asking for permission before turning something on.

    private var reminderBinding: Binding<Bool> {
        Binding {
            reminderEnabled
        } set: { isOn in
            if isOn {
                Task {
                    if await ReminderScheduler.requestPermission() {
                        notificationsDenied = false
                        reminderEnabled = true
                        ReminderScheduler.schedule(minutes: reminderMinutes)
                    } else {
                        notificationsDenied = true
                    }
                }
            } else {
                reminderEnabled = false
                ReminderScheduler.cancel()
            }
        }
    }

    /// Converts between the stored minutes-after-midnight and the Date a DatePicker needs.
    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
            ReminderScheduler.schedule(minutes: reminderMinutes)
        }
    }

    private var lockBinding: Binding<Bool> {
        Binding {
            lockEnabled
        } set: { isOn in
            if isOn {
                // Check Face ID works before turning the lock on.
                Task {
                    if await AppLock.authenticate(reason: "Turn on Face ID lock") {
                        lockEnabled = true
                    }
                }
            } else {
                lockEnabled = false
            }
        }
    }
}

/// A tiny mock screen drawn in a theme's colors, so you can compare before choosing.
private struct ThemePreview: View {
    let theme: Theme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.background)
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(.primary.opacity(0.7)).frame(width: 36, height: 6)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .frame(height: 26)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .frame(height: 18)
                    Capsule().fill(theme.accent).frame(height: 14)
                }
                .padding(10)
            }
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? theme.accent : Color.secondary.opacity(0.25), lineWidth: isSelected ? 3 : 1)
            )

            Label(theme.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.footnote.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? theme.accent : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
