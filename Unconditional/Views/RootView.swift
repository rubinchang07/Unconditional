import SwiftUI

/// Four tabs. Reframe isn't a tab: it opens as a step after saving an entry on Today.
/// Also applies the chosen theme and the optional Face ID lock.
struct RootView: View {
    @AppStorage(Theme.storageKey) private var theme: Theme = .white
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        ZStack {
            TabView {
                TodayView()
                    .tabItem { Label("Today", systemImage: "sun.max") }
                WinsView()
                    .tabItem { Label("Anchors", systemImage: "star") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }

            if !hasSeenWelcome {
                OnboardingView { withAnimation(.easeInOut(duration: 0.6)) { hasSeenWelcome = true } }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if lockEnabled && !isUnlocked {
                LockScreen(theme: theme, unlock: unlock)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        // `.tint` colors every button, toggle, and link below it.
        .tint(theme.accent)
        .task { if lockEnabled { await unlock() } }
        .onChange(of: scenePhase) { _, phase in
            guard lockEnabled else { return }
            if phase == .background { isUnlocked = false }
            if phase == .active && !isUnlocked { Task { await unlock() } }
        }
        .onChange(of: lockEnabled) { _, isOn in
            // You just proved it's you in Settings, so don't lock immediately.
            if isOn { isUnlocked = true }
        }
    }

    private func unlock() async {
        // Avoid stacking two Face ID prompts (launch and returning to the app can overlap).
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await AppLock.authenticate() {
            withAnimation { isUnlocked = true }
        }
    }
}

private struct LockScreen: View {
    let theme: Theme
    let unlock: () async -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(theme.accent)
            Text("Unconditional")
                .font(.title.bold())
            Button("Unlock") { Task { await unlock() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
    }
}
