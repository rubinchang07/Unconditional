import SwiftUI
import SwiftData

/// Any one of the things you keep in Anchors: something that made you laugh,
/// a photo, a win, a value, or words to come back to.
enum AnyAnchor: Identifiable {
    case laugh(Laugh)
    case photo(GroundingPhoto)
    case win(Win)
    case value(PersonalValue)
    case words(SavedReminder)

    var id: PersistentIdentifier {
        switch self {
        case .laugh(let x): x.persistentModelID
        case .photo(let x): x.persistentModelID
        case .win(let x): x.persistentModelID
        case .value(let x): x.persistentModelID
        case .words(let x): x.persistentModelID
        }
    }

    /// One at random from everything you've kept, or nil if Anchors is empty.
    /// Each kind gets an equal chance first, so a long list of wins doesn't
    /// crowd out the one photo.
    static func random(laughs: [Laugh], photos: [GroundingPhoto], wins: [Win],
                       values: [PersonalValue], words: [SavedReminder]) -> AnyAnchor? {
        let kinds: [[AnyAnchor]] = [laughs.map(AnyAnchor.laugh), photos.map(AnyAnchor.photo), wins.map(AnyAnchor.win),
                                    values.map(AnyAnchor.value), words.map(AnyAnchor.words)].filter { !$0.isEmpty }
        return kinds.randomElement()?.randomElement()
    }
}

/// One anchor, shown on its own: the picture or the words, nothing else.
struct AnchorCard: View {
    let anchor: AnyAnchor
    @AppStorage(OrbPalette.storageKey) private var orbPalette: OrbPalette = .emberSage

    var body: some View {
        switch anchor {
        case .laugh(let laugh):
            LaughCard(laugh: laugh)
        case .photo(let photo):
            VStack(spacing: 10) {
                PhotoSticker(photo: photo, glow: orbPalette.colors[2])
                    .frame(maxHeight: 200)
                if !photo.caption.isEmpty {
                    Text(photo.caption).font(.system(.body, design: .serif))
                }
            }
        case .win(let win):
            Label(win.text, systemImage: "sparkle")
                .font(.system(.body, design: .serif))
        case .value(let value):
            VStack(spacing: 6) {
                MiniOrb(color: orbPalette.colors[0], seed: Double(value.name.count))
                    .frame(width: 44, height: 44)
                Text(value.name).font(.system(.headline, design: .serif))
                if !value.meaning.isEmpty {
                    Text(value.meaning).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
        case .words(let words):
            Text("“\(words.text)”")
                .font(.system(.body, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
        }
    }
}
