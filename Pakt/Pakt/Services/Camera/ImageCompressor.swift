import UIKit

/// Mirrors the web app's client-side compression contract:
/// max long edge 1600px, JPEG quality 0.82.
enum ImageCompressor {
    static let maxLongEdge: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.82

    static func compressed(_ image: UIImage) -> Data? {
        let resized = resize(image)
        return resized.jpegData(compressionQuality: jpegQuality)
    }

    private static func resize(_ image: UIImage) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        let longEdge = max(width, height)
        guard longEdge > maxLongEdge else { return image }

        let scale = maxLongEdge / longEdge
        let target = CGSize(width: width * scale, height: height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
