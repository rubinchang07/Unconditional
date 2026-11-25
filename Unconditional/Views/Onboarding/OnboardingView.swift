import SwiftUI

/// The welcome tour: one idea per screen, so nothing arrives all at once.
/// Shown on first launch, and again any time from Settings.
struct OnboardingView: View {
    @AppStorage(OrbPalette.storageKey) private var palette: OrbPalette = .emberSage
    let onFinish: () -> Void

    private struct Page {
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(title: "unconditional.",
             body: "A quiet place to work through hard thoughts, one day at a time. Your worth isn't something you have to earn here."),
        Page(title: "Get it out",
             body: "Write, speak, or draw whatever's on your mind. Messy is fine. There's no right way to do this."),
        Page(title: "Name the pattern",
             body: "Notice which loop a thought belongs to. Naming it makes it a little smaller, and over time you'll see how it shifts."),
        Page(title: "Look again, gently",
             body: "Reframe a thought, or just be kind to yourself about it. Not every thought needs to be analyzed. Some can simply be let be."),
        Page(title: "When it's a lot",
             body: "\"I'm spiraling\" is always one tap away. Pick the thought that's closest, read another angle, and take a breath."),
        Page(title: "Your anchors",
             body: "Keep the values you care about, the reminders you want to hear, and small wins, including the ones that were only effort."),
        Page(title: "Yours alone",
             body: "Everything stays on this phone. You can lock it with Face ID, and support lines are in Settings if you ever need them."),
    ]

    @State private var index = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if index < pages.count - 1 {
                    Button("skip", action: onFinish)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 24)

            // The orb stays put while the words change around it,
            // so moving between screens feels continuous.
            OrbView(palette: palette, speed: 0.8, interactive: true)
                .frame(width: 280, height: 280)
                .scaleEffect(index == 0 ? 1 : 0.85)
                .animation(.easeInOut(duration: 0.8), value: index)

            TabView(selection: $index) {
                ForEach(pages.indices, id: \.self) { i in
                    VStack(spacing: 16) {
                        Text(pages[i].title)
                            .font(.system(.largeTitle, design: .serif).weight(.semibold))
                            .softCase()
                            .multilineTextAlignment(.center)
                        Text(pages[i].body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 24)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Color.primary.opacity(0.7) : Color.primary.opacity(0.15))
                        .frame(width: i == index ? 20 : 7, height: 7)
                }
            }
            .animation(.easeInOut, value: index)
            .padding(.bottom, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(index + 1) of \(pages.count)")

            Button(index == pages.count - 1 ? "Begin" : "Next") {
                if index == pages.count - 1 {
                    onFinish()
                } else {
                    withAnimation(.easeInOut) { index += 1 }
                }
            }
            .buttonStyle(.paper)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }
}
