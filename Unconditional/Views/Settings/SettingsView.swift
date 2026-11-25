import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @AppStorage(OrbMotion.storageKey) private var orbMotion: OrbMotion = .always
    @AppStorage(CareerReflection.enabledKey) private var careerEnabled = false

    @Environment(\.modelContext) private var context
    @State private var notificationsDenied = false
    @State private var exportDocument: ExportDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var dataMessage: String?

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
                    // Two per row, so four orbs each get room to breathe.
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 20) {
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
                    Picker("Orb moves", selection: $orbMotion) {
                        ForEach(OrbMotion.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Evening warmth after 9 PM", isOn: $eveningWarmth)
                    Button("Replay the welcome tour") {
                        dismiss()
                        hasSeenWelcome = false
                    }
                } header: {
                    Text("Orb")
                } footer: {
                    Text("Some people like the orb moving during exercises but prefer stillness while writing.")
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
                    Button {
                        do {
                            exportDocument = ExportDocument(data: try DataTransfer.encode(DataTransfer.snapshot(from: context)))
                            showingExporter = true
                        } catch {
                            dataMessage = "Couldn't make the export. Nothing was changed."
                        }
                    } label: {
                        Label("Export everything", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Restore from a file", systemImage: "square.and.arrow.down")
                    }
                    if let dataMessage {
                        Text(dataMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Your journal lives only on this phone. Export saves all of it to one file you control. Restoring adds what's in a file and skips anything you already have, so nothing is overwritten.")
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
            .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json,
                          defaultFilename: "Unconditional-\(Date.now.formatted(.iso8601.year().month().day()))") { result in
                if case .success = result { dataMessage = "Exported. Keep the file somewhere private." }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                restore(result)
            }
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        // Files picked from outside the app need permission to be read.
        let allowed = url.startAccessingSecurityScopedResource()
        defer { if allowed { url.stopAccessingSecurityScopedResource() } }
        do {
            let snapshot = try DataTransfer.decode(Data(contentsOf: url))
            let summary = DataTransfer.restore(snapshot, into: context)
            dataMessage = summary.added == 0
                ? "Everything in that file is already here."
                : "Restored \(summary.added) \(summary.added == 1 ? "item" : "items"). \(summary.skipped) were already here."
        } catch {
            dataMessage = "That file couldn't be read. It may not be an Unconditional export."
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

/// Wraps the export so the system "Save to Files" sheet can write it.
/// `nonisolated` because the system reads and writes files off the main thread.
nonisolated struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
