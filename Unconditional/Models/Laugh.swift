import Foundation
import SwiftData
import UIKit

/// Something that made you laugh: a joke, a meme, a thing someone said.
/// Kept in Anchors near the surface, and offered after a thought reset
/// when you'd like something lighter.
@Model
final class Laugh {
    var text: String = ""
    /// A screenshot or photo, if you added one. Kept outside the main database file.
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date.now

    init(text: String, imageData: Data? = nil, createdAt: Date = .now) {
        self.text = text
        self.imageData = imageData
        self.createdAt = createdAt
    }

    /// A screenshot can be huge. Keep it at most 1200 points on its longest side, as a JPEG.
    static func shrink(_ data: Data, maxSide: CGFloat = 1200) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
