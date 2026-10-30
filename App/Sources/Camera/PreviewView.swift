// ABOUTME: UIKit bridge that hosts an AVCaptureVideoPreviewLayer inside the fitted image rectangle.
// ABOUTME: The session joins the layer on the main thread only, once, at view construction; background-queue layer mutation destabilizes the camera pipeline.

import AVFoundation
import SwiftUI

struct PreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Runs on the main thread after the layer receives the session, so the owner starts the session with the layer attached.
    let onAttach: () -> Void

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        view.accessibilityLabel = "Camera preview"
        onAttach()
        return view
    }

    func updateUIView(_ view: PreviewUIView, context: Context) {}
}
