import CoreImage.CIFilterBuiltins
import UIKit

enum QRGenerator {
    /// Render a crisp, dark-foreground QR image at the requested pixel size.
    static func image(for payload: String, size: CGFloat) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard var ci = filter.outputImage else { return nil }

        let scale = size / ci.extent.width
        ci = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up)
    }
}
