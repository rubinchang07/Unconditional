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
}

/// The brush shapes PencilKit offers. Each has its own feel and size range.
enum Brush: String, CaseIterable, Identifiable {
    case pen, pencil, marker, fountain, watercolor, crayon, monoline

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fountain: "Fountain pen"
        default: rawValue.capitalized
        }
    }

    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .pencil: "pencil"
        case .marker: "highlighter"
        case .fountain: "signature"
        case .watercolor: "paintbrush"
        case .crayon: "paintbrush.pointed"
        case .monoline: "line.diagonal"
        }
    }

    var inkType: PKInkingTool.InkType {
        switch self {
        case .pen: .pen
        case .pencil: .pencil
        case .marker: .marker
        case .fountain: .fountainPen
        case .watercolor: .watercolor
        case .crayon: .crayon
        case .monoline: .monoline
        }
    }

    /// Thinnest and thickest stroke for this brush, in points.
    var widthRange: ClosedRange<CGFloat> {
        switch self {
        case .marker, .crayon: 6...30
        case .watercolor: 10...40
        default: 2...14
        }
    }
}

/// Everything the canvas needs to know about the current tool.
struct DrawingTool: Equatable {
    var ink: InkChoice = .ink
    var brush: Brush = .pen
    /// 0 = thinnest, 1 = thickest. A slider, because size is a spectrum too.
    var size: Double = 0.3

    var pkTool: PKTool {
        if ink == .eraser { return PKEraserTool(.vector) } // removes whole strokes
        let range = brush.widthRange
        let width = range.lowerBound + (range.upperBound - range.lowerBound) * size
        return PKInkingTool(brush.inkType, color: ink.uiColor, width: width)
    }
}

/// PencilKit is a UIKit framework, so we wrap `PKCanvasView` in a
/// `UIViewRepresentable` to use it from SwiftUI.
struct DrawingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var tool = DrawingTool()
    var isEditable = true

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput // finger works too, not only Apple Pencil
        canvas.tool = tool.pkTool
        canvas.backgroundColor = Paper.cardUIColor
        canvas.isUserInteractionEnabled = isEditable
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Only push changes in from SwiftUI (e.g. "Clear"), to avoid a feedback loop.
        if canvas.drawing != drawing { canvas.drawing = drawing }
        canvas.tool = tool.pkTool
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

/// Brush picker plus a size slider.
struct BrushBar: View {
    @Binding var tool: DrawingTool

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Brush.allCases) { brush in
                        let isSelected = tool.brush == brush && tool.ink != .eraser
                        Button {
                            tool.brush = brush
                            if tool.ink == .eraser { tool.ink = .ink }
                        } label: {
                            Image(systemName: brush.symbol)
                                .font(.system(size: 17))
                                .frame(width: 40, height: 36)
                                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(brush.name)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 10) {
                Circle().frame(width: 5, height: 5)
                Slider(value: $tool.size, in: 0...1)
                    .accessibilityLabel("Brush size")
                Circle().frame(width: 16, height: 16)
            }
            .foregroundStyle(.secondary)
        }
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
