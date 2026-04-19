import AVFoundation
import SwiftUI
import UIKit

/// Live camera QR scanner. Calls `onShortCode` once per successful scan, then
/// pauses the session — caller can dismiss or present a follow-up view.
struct QRScannerView: UIViewControllerRepresentable {
    let onShortCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_: QRScannerController, context _: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let parent: QRScannerView
        private var hasFired = false

        init(parent: QRScannerView) { self.parent = parent }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasFired,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let raw = obj.stringValue,
                  let shortCode = QRPayload.parseShortCode(from: raw)
            else { return }
            hasFired = true
            DispatchQueue.main.async { self.parent.onShortCode(shortCode) }
        }
    }
}

final class QRScannerController: UIViewController {
    weak var coordinator: QRScannerView.Coordinator?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            showPermissionOverlay()
            return
        }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(coordinator, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview
        drawReticle()
    }

    private func drawReticle() {
        let reticle = UIView()
        reticle.translatesAutoresizingMaskIntoConstraints = false
        reticle.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        reticle.layer.borderWidth = 2
        reticle.layer.cornerRadius = 12
        view.addSubview(reticle)
        NSLayoutConstraint.activate([
            reticle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reticle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            reticle.widthAnchor.constraint(equalToConstant: 240),
            reticle.heightAnchor.constraint(equalToConstant: 240),
        ])
    }

    private func showPermissionOverlay() {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.text = "Camera access is required to scan QR labels.\nEnable it in Settings → Pakt → Camera."
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
