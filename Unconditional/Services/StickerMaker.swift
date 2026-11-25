import UIKit
import Vision
import CoreImage

/// Turns a photo into a sticker, the way Photos does when you lift a subject:
/// Apple's Vision framework finds the person, pet, or thing in front and cuts
/// it out, all on the phone. If there's no clear subject (a landscape, say),
/// the whole photo is kept and shown as a rounded sticker instead.
enum StickerMaker {
    struct Result: Sendable {
        /// PNG for a cutout (it needs transparency), JPEG for a whole photo.
        let png: Data
        let isCutout: Bool
    }

    /// Photos are shrunk to this many pixels on the long side, so they stay small on disk.
    nonisolated static let maxSide: CGFloat = 1400

    /// Runs off the main thread, since finding the subject takes a moment.
    nonisolated static func make(from data: Data) async -> Result? {
        await Task.detached(priority: .userInitiated) {
            guard let original = UIImage(data: data), let image = downscaled(original),
                  let cgImage = image.cgImage else { return nil }
            if let cutout = liftSubject(from: cgImage), let png = UIImage(cgImage: cutout).pngData() {
                return Result(png: png, isCutout: true)
            }
            // No transparency needed for a whole photo, so JPEG keeps it much smaller.
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }
            return Result(png: jpeg, isCutout: false)
        }.value
    }

    /// Smaller, and with the orientation baked in so the cutout isn't sideways.
    nonisolated private static func downscaled(_ image: UIImage) -> UIImage? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// The subject on a transparent background, cropped to fit it, or nil if none was found.
    nonisolated private static func liftSubject(from cgImage: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances,
                                                            from: handler, croppedToInstancesExtent: true)
            let ciImage = CIImage(cvPixelBuffer: buffer)
            return CIContext().createCGImage(ciImage, from: ciImage.extent)
        } catch {
            return nil
        }
    }
}
