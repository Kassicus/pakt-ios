import UIKit

/// Renders a 40×30 mm box label at ~300 DPI (472×354 px). Matches the web
/// app's label layout 1:1 so printed labels are interchangeable across
/// clients.
///
/// Layout (mirrors `pakt/src/lib/labels.tsx`):
///   - QR: 290×290 px, padded 12 px from the left, vertically centered in
///     the content area (excluding the fragile bar when present).
///   - Right strip (from the QR's right edge to the label's right edge):
///     column 1 at ~35% width holds a big bold short code, rotated -90°.
///     Column 2 at ~78% width holds "Source → Destination" rotated -90°.
///   - Fragile bar: if the box is flagged fragile, a full-width 48 px bar
///     at the bottom with white "FRAGILE" text on black.
enum LabelRenderer {
    private static let labelWidth: CGFloat = 472
    private static let labelHeight: CGFloat = 354
    private static let qrSize: CGFloat = 290
    private static let pad: CGFloat = 12
    private static let fragileBarHeight: CGFloat = 48

    static func image(for box: Box) -> UIImage? {
        let size = CGSize(width: labelWidth, height: labelHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let tagBarText = tagBarLabel(for: box.tags)
            let hasTagBar = tagBarText != nil
            let contentHeight = labelHeight - (hasTagBar ? fragileBarHeight : 0)
            let contentCenterY = contentHeight / 2

            // QR — left column, vertically centered in the content area.
            let qrTop = max(pad, (contentHeight - qrSize) / 2)
            let qrRect = CGRect(x: pad, y: qrTop, width: qrSize, height: qrSize)
            if let qr = QRGenerator.image(for: QRPayload.string(for: box.shortCode), size: qrSize) {
                qr.draw(in: qrRect)
            }

            // Right strip geometry.
            let stripLeft = pad + qrSize + 8           // 310
            let stripRight = labelWidth - pad          // 460
            let stripWidth = stripRight - stripLeft    // 150
            let col1CenterX = stripLeft + stripWidth * 0.35  // ~362.5 — short code
            let col2CenterX = stripLeft + stripWidth * 0.78  // ~427   — route

            // Short code — rotated -90°, big and heavy.
            let codeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .black),
                .foregroundColor: UIColor.black,
                .kern: 2.24,   // 0.04em * 56pt
            ]
            drawRotated(
                text: box.shortCode,
                attributes: codeAttrs,
                centerX: col1CenterX,
                centerY: contentCenterY,
                context: cg
            )

            // Route — "source → destination" rotated -90°.
            if let route = routeLine(
                source: box.sourceRoom?.label,
                destination: box.destinationRoom?.label
            ) {
                let routeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: UIColor.black,
                    .kern: 0.24,   // 0.01em * 24pt
                ]
                drawRotated(
                    text: route,
                    attributes: routeAttrs,
                    centerX: col2CenterX,
                    centerY: contentCenterY,
                    context: cg
                )
            }

            // Tag bar — shows whichever tag is active (FRAGILE / PERISHABLE /
            // LIVE ANIMAL / etc.). Same style as the web's fragile bar.
            if let barText = tagBarText {
                drawTagBar(text: barText, context: cg)
            }
        }
    }

    // MARK: - Helpers

    /// The tag-bar text (uppercased). Returns nil if the box has no tags.
    /// Multiple tags are joined with " · " and rendered in a single bar.
    private static func tagBarLabel(for tags: [BoxTag]) -> String? {
        let labels = tags.map { BoxTagLabels.map[$0] ?? $0.rawValue }
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: " · ").uppercased()
    }

    /// Draw the full-width bottom bar with the given text. Auto-shrinks the
    /// font size if the text won't fit at the default 32pt.
    private static func drawTagBar(text: String, context cg: CGContext) {
        let barRect = CGRect(
            x: 0,
            y: labelHeight - fragileBarHeight,
            width: labelWidth,
            height: fragileBarHeight
        )
        cg.setFillColor(UIColor.black.cgColor)
        cg.fill(barRect)

        let maxTextWidth = labelWidth - 32  // leave ~16px padding each side
        let baseSize: CGFloat = 32
        let (fontSize, kern) = fittedBarFontSize(for: text, maxWidth: maxTextWidth, baseSize: baseSize)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .black),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.white,
            .strokeWidth: -2,
            .kern: kern,
        ]
        let string = NSAttributedString(string: text, attributes: attrs)
        let textSize = string.size()
        let origin = CGPoint(
            x: (labelWidth - textSize.width) / 2,
            y: barRect.midY - textSize.height / 2
        )
        string.draw(at: origin)
    }

    /// Shrink font size proportionally until the text fits. Keeps the same
    /// 0.22em kerning ratio as the web so spacing looks consistent.
    private static func fittedBarFontSize(
        for text: String,
        maxWidth: CGFloat,
        baseSize: CGFloat
    ) -> (fontSize: CGFloat, kern: CGFloat) {
        var size = baseSize
        while size > 14 {
            let kern = 0.22 * size
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size, weight: .black),
                .kern: kern,
            ]
            let width = (text as NSString).size(withAttributes: attrs).width
            if width <= maxWidth { return (size, kern) }
            size -= 1
        }
        return (size, 0.22 * size)
    }

    private static func routeLine(source: String?, destination: String?) -> String? {
        let src = source?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        let dst = destination?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        switch (src, dst) {
        case let (s?, d?): return "\(s) → \(d)"
        case (nil, let d?): return "→ \(d)"
        case (let s?, nil): return "\(s) →"
        default: return nil
        }
    }

    /// Draw an attributed string rotated -90° (counter-clockwise, reading
    /// bottom-to-top) around the given center point.
    private static func drawRotated(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        centerX: CGFloat,
        centerY: CGFloat,
        context cg: CGContext
    ) {
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()

        cg.saveGState()
        cg.translateBy(x: centerX, y: centerY)
        cg.rotate(by: -.pi / 2)
        string.draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2))
        cg.restoreGState()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
