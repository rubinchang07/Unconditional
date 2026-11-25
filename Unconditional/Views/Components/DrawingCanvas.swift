import SwiftUI
import PencilKit

/// PencilKit is a UIKit framework, so we wrap `PKCanvasView` in a
/// `UIViewRepresentable` to use it from SwiftUI.
struct DrawingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var isEditable = true

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput // finger works too, not only Apple Pencil
        canvas.tool = PKInkingTool(.pen, color: .label, width: 4)
        canvas.backgroundColor = .secondarySystemBackground
        canvas.isUserInteractionEnabled = isEditable
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Only push changes in from SwiftUI (e.g. "Clear"), to avoid a feedback loop.
        if canvas.drawing != drawing { canvas.drawing = drawing }
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
