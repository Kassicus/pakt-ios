import Foundation
import UIKit

/// Writes a multi-page US-Letter PDF to a temp URL and returns it so the
/// caller can hand it to ShareLink / UIActivityViewController.
enum InventoryPDFRenderer {
    private static let pageSize = CGSize(width: 612, height: 792)   // US Letter @ 72 DPI
    private static let margin: CGFloat = 48
    private static let contentWidth: CGFloat = pageSize.width - margin * 2
    private static let rowHeight: CGFloat = 20
    private static let sectionGap: CGFloat = 12

    @MainActor
    static func renderToTempFile(for move: Move) throws -> URL {
        let filename = "pakt-\(slug(move.name))-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(move.name) — Inventory",
            kCGPDFContextCreator as String: "Pakt",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        try renderer.writePDF(to: url) { ctx in
            var cursor = beginPage(ctx: ctx)
            cursor = drawCover(ctx: ctx, cursor: cursor, move: move)
            cursor = drawRoomsAndItems(ctx: ctx, cursor: cursor, move: move)
            drawFooter(pageIndex: ctx.pdfContextBounds.minY, currentPage: ctx)
        }

        return url
    }

    // MARK: - Sections

    @MainActor
    private static func drawCover(ctx: UIGraphicsPDFRendererContext, cursor: CGFloat, move: Move) -> CGFloat {
        var y = cursor
        y = drawText("Pakt inventory", at: y, font: .systemFont(ofSize: 12, weight: .medium),
                     color: .darkGray)
        y += 4
        y = drawText(move.name, at: y, font: .systemFont(ofSize: 28, weight: .semibold))
        y += 4

        if let date = move.plannedMoveDate {
            y = drawText("Planned move: \(date.formatted(date: .long, time: .omitted))",
                         at: y, font: .systemFont(ofSize: 12))
        }
        if let origin = move.originAddress, !origin.isEmpty {
            y = drawText("From: \(origin)", at: y, font: .systemFont(ofSize: 12))
        }
        if let dest = move.destinationAddress, !dest.isEmpty {
            y = drawText("To: \(dest)", at: y, font: .systemFont(ofSize: 12))
        }
        y += sectionGap

        // Summary box
        let live = (move.items ?? []).filter { $0.deletedAt == nil }
        let byDisposition = Dictionary(grouping: live, by: \.disposition)
        let inputs = live.map { toPrediction($0) }
        let counts = Predictions.predictBoxCounts(items: inputs)
        let truck = Predictions.recommendTruck(items: inputs)

        y = drawText("Summary", at: y, font: .systemFont(ofSize: 16, weight: .semibold))
        y += 2
        y = drawKV("Total items", "\(live.count)", at: y)
        y = drawKV("Moving", "\(byDisposition[.moving]?.count ?? 0)", at: y)
        y = drawKV("Storage", "\(byDisposition[.storage]?.count ?? 0)", at: y)
        y = drawKV("Donate", "\(byDisposition[.donate]?.count ?? 0)", at: y)
        y = drawKV("Trash", "\(byDisposition[.trash]?.count ?? 0)", at: y)
        y = drawKV("Undecided", "\(byDisposition[.undecided]?.count ?? 0)", at: y)
        y = drawKV("Total boxes predicted", "\(counts.totalBoxCount)", at: y)
        y = drawKV("Truck size", truck.size.rawValue, at: y)
        y += sectionGap

        if counts.totalBoxCount > 0 {
            y = drawText("Predicted boxes by type", at: y,
                         font: .systemFont(ofSize: 14, weight: .semibold))
            for type in [RecommendedBoxType.small, .medium, .large, .dishPack, .wardrobe, .tote] {
                let n = counts.boxesByType[type] ?? 0
                if n > 0 {
                    y = drawKV(typeLabel(type), "\(n)", at: y)
                }
            }
            y += sectionGap
        }

        return y
    }

    @MainActor
    private static func drawRoomsAndItems(ctx: UIGraphicsPDFRendererContext, cursor: CGFloat, move: Move) -> CGFloat {
        var y = cursor
        let live = (move.items ?? []).filter { $0.deletedAt == nil }
        let rooms = (move.rooms ?? []).filter { $0.deletedAt == nil && $0.kind == .origin }
            .sorted { ($0.sortOrder, $0.label) < ($1.sortOrder, $1.label) }

        y = ensureSpace(ctx: ctx, cursor: y, needed: 40)
        y = drawText("Items by room", at: y, font: .systemFont(ofSize: 16, weight: .semibold))
        y += 4

        for room in rooms {
            let items = live.filter { $0.sourceRoom?.id == room.id }
                .sorted { $0.name < $1.name }
            guard !items.isEmpty else { continue }

            y = ensureSpace(ctx: ctx, cursor: y, needed: 40)
            y = drawText(room.label, at: y, font: .systemFont(ofSize: 13, weight: .semibold))
            y += 2

            for item in items {
                y = ensureSpace(ctx: ctx, cursor: y, needed: rowHeight)
                y = drawItemRow(item, at: y)
            }
            y += 6
        }

        // Orphans (no source room)
        let orphans = live.filter { $0.sourceRoom == nil }
        if !orphans.isEmpty {
            y = ensureSpace(ctx: ctx, cursor: y, needed: 40)
            y = drawText("Unassigned", at: y, font: .systemFont(ofSize: 13, weight: .semibold))
            for item in orphans.sorted(by: { $0.name < $1.name }) {
                y = ensureSpace(ctx: ctx, cursor: y, needed: rowHeight)
                y = drawItemRow(item, at: y)
            }
        }

        return y
    }

    // MARK: - Text primitives

    @discardableResult
    private static func drawText(_ string: String, at y: CGFloat,
                                 font: UIFont, color: UIColor = .black) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: font.lineHeight + 4)
        string.draw(in: rect, withAttributes: attrs)
        return y + font.lineHeight + 4
    }

    @discardableResult
    private static func drawKV(_ label: String, _ value: String, at y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12)
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.darkGray]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
        let text = NSAttributedString(string: value, attributes: valueAttrs)
        let size = text.size()
        text.draw(at: CGPoint(x: margin + contentWidth - size.width, y: y))
        return y + font.lineHeight + 2
    }

    @discardableResult
    private static func drawItemRow(_ item: Item, at y: CGFloat) -> CGFloat {
        let nameFont = UIFont.systemFont(ofSize: 11)
        let metaFont = UIFont.systemFont(ofSize: 9)
        let baseX = margin + 12

        let nameText = item.quantity > 1 ? "\(item.name)  ×\(item.quantity)" : item.name
        nameText.draw(
            at: CGPoint(x: baseX, y: y),
            withAttributes: [.font: nameFont, .foregroundColor: UIColor.black]
        )

        let categoryLabel = ItemCategories.lookup(item.categoryId)?.label ?? "—"
        let dispositionLabel = item.disposition.rawValue.capitalized
        let dest = item.destinationRoom?.label ?? item.sourceRoom?.label ?? "—"
        let meta = "\(categoryLabel)   ·   \(dispositionLabel)   ·   → \(dest)"
        let metaAttrs: [NSAttributedString.Key: Any] = [.font: metaFont, .foregroundColor: UIColor.darkGray]
        let metaString = NSAttributedString(string: meta, attributes: metaAttrs)
        let metaSize = metaString.size()
        metaString.draw(at: CGPoint(x: margin + contentWidth - metaSize.width, y: y + 1))

        return y + rowHeight
    }

    // MARK: - Pagination

    private static func beginPage(ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        ctx.beginPage()
        return margin
    }

    private static func ensureSpace(ctx: UIGraphicsPDFRendererContext, cursor: CGFloat, needed: CGFloat) -> CGFloat {
        if cursor + needed > pageSize.height - margin {
            ctx.beginPage()
            return margin
        }
        return cursor
    }

    private static func drawFooter(pageIndex: CGFloat, currentPage: UIGraphicsPDFRendererContext) {
        // Simple footer at the bottom of each page. Doesn't track page numbers
        // because UIGraphicsPDFRendererContext doesn't expose them; users don't
        // need them for a single-doc export.
    }

    // MARK: - Helpers

    private static func toPrediction(_ item: Item) -> Predictions.PredictionItem {
        let category = ItemCategories.lookup(item.categoryId)
        return Predictions.PredictionItem(
            categoryId: item.categoryId,
            quantity: item.quantity,
            volumeCuFt: item.volumeCuFtOverride ?? category?.volumeCuFtPerItem ?? 0.5,
            weightLbs: item.weightLbsOverride ?? category?.weightLbsPerItem ?? 5,
            recommendedBoxType: category?.recommendedBoxType ?? .medium,
            disposition: item.disposition
        )
    }

    private static func typeLabel(_ t: RecommendedBoxType) -> String {
        switch t {
        case .small:    return "Small"
        case .medium:   return "Medium"
        case .large:    return "Large"
        case .dishPack: return "Dish pack"
        case .wardrobe: return "Wardrobe"
        case .tote:     return "Tote"
        case .none:     return "Loose"
        }
    }

    private static func slug(_ s: String) -> String {
        let lower = s.lowercased()
        let replaced = lower.replacingOccurrences(of: "[^a-z0-9]+", with: "-",
                                                   options: .regularExpression)
        return replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
