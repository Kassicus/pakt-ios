import SwiftUI
import UIKit

/// Thin UIActivityViewController bridge. ShareLink won't accept arbitrary file
/// URLs on iOS 17 without a Transferable wrapper, so we expose the activity
/// controller directly for maximum control (AirDrop, Save to Files, Mail, etc.)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

/// Identifiable wrapper so a URL can drive a SwiftUI `.sheet(item:)`.
struct PDFShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}
