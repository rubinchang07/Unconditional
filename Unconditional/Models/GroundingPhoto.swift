import Foundation
import SwiftData

/// A photo that keeps you grounded: a place, a person, a pet, a thing.
/// Shown in Anchors as a sticker, lifted out of the photo when possible.
@Model
final class GroundingPhoto {
    /// The image. A cutout is a PNG with a transparent background around the subject; a whole photo is a JPEG.
    /// Kept outside the main database file, since images are large.
    @Attribute(.externalStorage) var imageData: Data = Data()
    /// True when the subject was lifted out, false for a whole photo.
    var isCutout: Bool = false
    /// What it reminds you of. Optional.
    var caption: String = ""
    var createdAt: Date = Date.now

    init(imageData: Data, isCutout: Bool, caption: String = "", createdAt: Date = .now) {
        self.imageData = imageData
        self.isCutout = isCutout
        self.caption = caption
        self.createdAt = createdAt
    }
}
