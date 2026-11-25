import SwiftUI
import PencilKit

/// The colors you can draw with, plus an eraser.
/// Soft tones on purpose: nothing harsh or alarming.
enum InkChoice: String, CaseIterable, Identifiable {
    case ink, sage, lavender, sky, peach, rose, eraser

    var id: String { rawValue }

    var uiColor: UIColor {
        switch self {
        case .ink, .eraser: .label // black in light mode, white in dark mode
        case .sage: UIColor(hex: 0x7FA383)
        case .lavender: UIColor(hex: 0x9B86C4)
        case .sky: UIColor(hex: 0x6FA3CC)
        case .peach: UIColor(hex: 0xE8A07E)
        case .rose: UIColor(hex: 0xD98A9B)
        }
    }

    var name: String { rawValue.capitalized }

    var tool: PKTool {
        self == .eraser
            ? PKEraserTool(.vector) // removes whole strokes
            : PKInkingTool(.pen, color: uiColor, width: 4)
    }
}

/// PencilKit is a UIKit framework, so we wrap `PKCanvasView` in a
/// `UIViewRepresentable` to use it from SwiftUI.
struct DrawingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var ink: InkChoice = .ink
    var isEditable = true

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput // finger works too, not only Apple Pencil
        canvas.tool = ink.tool
        canvas.backgroundColor = .secondarySystemBackground
        canvas.isUserInteractionEnabled = isEditable
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Only push changes in from SwiftUI (e.g. "Clear"), to avoid a feedback loop.
        if canvas.drawing != drawing { canvas.drawing = drawing }
        canvas.tool = ink.tool
    }

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    /// The coordinator receives UIKit delegate callbacks and writes back to the binding.
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        init(drawing: Binding<PKDrawing>) { self.drawing = drawing }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

/// A row of color dots plus an eraser.
struct InkPalette: View {
    @Binding var selection: InkChoice

    var body: some View {
        HStack(spacing: 14) {
            ForEach(InkChoice.allCases) { choice in
                Button {
                    selection = choice
                } label: {
                    ZStack {
                        if choice == .eraser {
                            Image(systemName: "eraser")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        } else {
                            Circle().fill(Color(uiColor: choice.uiColor))
                                .padding(4)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().strokeBorder(selection == choice ? Color.primary.opacity(0.6) : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.name)
                .accessibilityAddTraits(selection == choice ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Renders saved drawing data as a static image (for History).
struct DrawingThumbnail: View {
    let data: Data?

    var body: some View {
        if let data, let drawing = try? PKDrawing(data: data), !drawing.bounds.isEmpty {
            Image(uiImage: drawing.image(from: drawing.bounds.insetBy(dx: -12, dy: -12), scale: 2))
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "scribble")
                .foregroundStyle(.secondary)
        }
    }
}
