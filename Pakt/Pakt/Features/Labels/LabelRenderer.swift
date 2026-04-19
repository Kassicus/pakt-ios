import UIKit

/// Renders a 40×30 mm box label at 300 DPI (≈ 472×354 px). Matches the web app's
/// label dimensions so printed labels are interchangeable across clients.
/// Layout: QR on the left (square), text on the right (short code, type, destination).
enum LabelRenderer {
    private static let pixelWidth: CGFloat = 472
    private static let pixelHeight: CGFloat = 354
    private static let margin: CGFloat = 16

    static func image(for box: Box) -> UIImage? {
        let size = CGSize(width: pixelWidth, height: pixelHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let qrSide = pixelHeight - margin * 2
            let qrRect = CGRect(x: margin, y: margin, width: qrSide, height: qrSide)
            let payload = QRPayload.string(for: box.shortCode)
            if let qr = QRGenerator.image(for: payload, size: qrSide) {
                qr.draw(in: qrRect)
            }

            let textX = qrRect.maxX + margin
            let textWidth = pixelWidth - textX - margin

            // Short code — big and monospaced
            let codeFont = UIFont.monospacedSystemFont(ofSize: 42, weight: .bold)
            let codeAttrs: [NSAttributedString.Key: Any] = [
                .font: codeFont,
                .foregroundColor: UIColor.black,
            ]
            let codeString = NSAttributedString(string: box.shortCode, attributes: codeAttrs)
            codeString.draw(in: CGRect(x: textX, y: margin, width: textWidth, height: 56))

            // Type label
            let typeFont = UIFont.systemFont(ofSize: 26, weight: .medium)
            let typeAttrs: [NSAttributedString.Key: Any] = [
                .font: typeFont,
                .foregroundColor: UIColor.black,
            ]
            let typeString = NSAttributedString(
                string: box.boxType?.label ?? "",
                attributes: typeAttrs
            )
            typeString.draw(in: CGRect(x: textX, y: margin + 64, width: textWidth, height: 36))

            // Destination room
            let destFont = UIFont.systemFont(ofSize: 22, weight: .regular)
            let destAttrs: [NSAttributedString.Key: Any] = [
                .font: destFont,
                .foregroundColor: UIColor.darkGray,
            ]
            let destLabel = box.destinationRoom.map { "→ \($0.label)" } ?? ""
            let destString = NSAttributedString(string: destLabel, attributes: destAttrs)
            destString.draw(in: CGRect(x: textX, y: margin + 112, width: textWidth, height: 32))

            // Tags
            let tagLabels = box.tags.map { $0.label }.joined(separator: " · ")
            if !tagLabels.isEmpty {
                let tagFont = UIFont.systemFont(ofSize: 18, weight: .regular)
                let tagAttrs: [NSAttributedString.Key: Any] = [
                    .font: tagFont,
                    .foregroundColor: UIColor.systemRed,
                ]
                let tagString = NSAttributedString(string: tagLabels, attributes: tagAttrs)
                tagString.draw(in: CGRect(x: textX, y: margin + 150, width: textWidth, height: 28))
            }
        }
    }
}
