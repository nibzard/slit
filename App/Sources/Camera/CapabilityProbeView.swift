#if DEBUG
import AVKit
import SwiftUI

@MainActor
private final class ProbeModel: ObservableObject {
    @Published var text = "Capability probe has not run. Aim the rear main camera at a test chart."
    @Published var files: [URL] = []
    @Published var canCapture = false
    @Published var canRetry = false
    let probe: CapabilityProbe
    private var applyUpdates: Task<Void, Never>?

    init() {
        // The publish closure is Sendable, so it must not capture this MainActor
        // model. It captures only the Sendable stream continuation; the consumer
        // task applies each update on the main actor below.
        let (updates, continuation) = AsyncStream<CapabilityProbe.Update>.makeStream()
        probe = CapabilityProbe { update in continuation.yield(update) }
        applyUpdates = Task { @MainActor [weak self] in
            for await update in updates {
                guard let self else { return }
                self.text = update.text
                self.files = update.files
                self.canCapture = update.canCapture
                self.canRetry = update.canRetry
            }
        }
    }

    deinit {
        applyUpdates?.cancel()
    }
}

/// Development entry point only. It does not replace Grip or claim library persistence.
struct CapabilityProbeView: View {
    @StateObject private var model = ProbeModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var sharing = false

    var body: some View {
        VStack {
            Text("Development capability probe").font(.headline)
            ScrollView { Text(model.text).font(.caption.monospaced()).textSelection(.enabled) }
            Button("Capture test DNG") { model.probe.capture() }
                .disabled(!model.canCapture || sharing || scenePhase != .active)
            if model.canRetry {
                Button("Retry probe write") { model.probe.retryWrite() }
            }
            Button("Share probe files") { sharing = true }
                .disabled(model.files.isEmpty)
        }
        .padding()
        .background(ProbeHardwareInput(enabled: scenePhase == .active && !sharing) { source, phase in
            model.probe.hardware(source: source, phase: phase)
        })
        .sheet(isPresented: $sharing) { ProbeShareSheet(files: model.files) }
        .onChange(of: sharing) { _, presented in model.probe.setInputEnabled(!presented) }
        .onAppear { model.probe.start() }
        .onDisappear { model.probe.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.probe.start() } else { model.probe.stop() }
        }
    }
}

private struct ProbeHardwareInput: UIViewRepresentable {
    let enabled: Bool
    let receive: (String, String) -> Void

    /// Holds the hardware-capture interaction directly. The view's interaction
    /// order carries no meaning and must not be used for lookup.
    final class Coordinator {
        var interaction: AVCaptureEventInteraction?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let interaction = AVCaptureEventInteraction(primary: { event in
            receive("primary", phaseName(event.phase))
        }, secondary: { event in
            receive("secondary", phaseName(event.phase))
        })
        interaction.isEnabled = enabled
        context.coordinator.interaction = interaction
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.interaction?.isEnabled = enabled
    }

    private func phaseName(_ phase: AVCaptureEventPhase) -> String {
        switch phase {
        case .began: return "began"
        case .ended: return "ended"
        case .cancelled: return "cancelled"
        @unknown default: return "unknown"
        }
    }
}

private struct ProbeShareSheet: UIViewControllerRepresentable {
    let files: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: files, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
