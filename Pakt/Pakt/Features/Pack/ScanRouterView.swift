import SwiftData
import SwiftUI

/// Top-level entry for scanning a QR label. Scans once, then routes to Pack
/// or Unpack based on where the box is in its lifecycle.
struct ScanRouterView: View {
    let move: Move

    @Environment(\.dismiss) private var dismiss
    @State private var scannedBox: Box?
    @State private var unknownCode: String?

    var body: some View {
        Group {
            if let box = scannedBox {
                if box.status >= .delivered {
                    UnpackView(box: box)
                } else {
                    PackView(box: box)
                }
            } else {
                scanner
            }
        }
        .navigationTitle("Scan label")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unknown box",
               isPresented: Binding(
                get: { unknownCode != nil },
                set: { if !$0 { unknownCode = nil } }
               )
        ) {
            Button("Scan again", role: .cancel) { unknownCode = nil }
        } message: {
            if let code = unknownCode {
                Text("We didn't find a box with code \(code). The label might belong to a different move.")
            }
        }
    }

    private var scanner: some View {
        QRScannerView { shortCode in
            if let match = liveBoxes.first(where: { $0.shortCode == shortCode }) {
                scannedBox = match
            } else {
                unknownCode = shortCode
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Text("Point the camera at a Pakt label.")
                .font(.pakt(.body))
                .padding(.horizontal, PaktSpace.s4)
                .padding(.vertical, 10)
                .background(Capsule().fill(.black.opacity(0.6)))
                .foregroundStyle(.white)
                .padding(.bottom, 32)
        }
    }

    private var liveBoxes: [Box] {
        (move.boxes ?? []).filter { $0.deletedAt == nil }
    }
}
