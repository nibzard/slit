// ABOUTME: Grip capture screen: top bar, fitted image area with live preview or honest state placeholders, status strip, and bottom capture controls.
// ABOUTME: The shutter is admission-gated; hardware capture events are bridged only while this screen can accept input.

import AVKit
import SlitCore
import SwiftUI
import UIKit

struct GripShellView: View {
    @StateObject private var camera = CameraModel()
    @AppStorage(SlitDefaults.gridPreferenceKey) private var gridEnabled = SlitDefaults.gridInitiallyEnabled
    @State private var isMorePresented = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            VStack(spacing: 0) {
                HStack {
                    Text("slit").font(.headline)
                    Spacer()
                    Button { isMorePresented = true } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("More")
                    .accessibilityIdentifier("moreButton")
                }
                .padding(.horizontal, 24)
                if isLandscape {
                    HStack(spacing: 16) {
                        imageArea(isLandscape: true)
                            .aspectRatio(4 / 3.0, contentMode: .fit)
                        VStack {
                            Spacer()
                            captureControls(isLandscape: true)
                        }
                        .frame(width: 144)
                    }
                    .padding(.horizontal, 24)
                } else {
                    imageArea(isLandscape: false)
                        .aspectRatio(3 / 4.0, contentMode: .fit)
                        .frame(maxHeight: max(0, geometry.size.height - 210))
                    statusStrip
                    Spacer(minLength: 0)
                    captureControls(isLandscape: false)
                }
            }
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(GripTheme.background.ignoresSafeArea())
        .foregroundStyle(GripTheme.text)
        .background(hardwareCaptureInput)
        .sheet(isPresented: $isMorePresented) {
            moreSheet
        }
        .onChange(of: isMorePresented) { _, presented in
            camera.setCaptureVisible(!presented)
        }
        .onChange(of: scenePhase) { _, phase in
            CameraDiagnostics.event("scenePhase \(String(describing: phase))")
            switch phase {
            case .active: camera.start()
            case .inactive:
                #if DEBUG
                // Churn mode restores the v1-v4 lifecycle: stop on every non-active phase.
                if CameraMode.current == .churn { camera.stop(); return }
                #endif
                camera.suspendInput()
            case .background: camera.stop()
            @unknown default: camera.stop()
            }
        }
        .onAppear { camera.start() }
    }

    // MARK: Image area

    @ViewBuilder
    private func imageArea(isLandscape: Bool) -> some View {
        ZStack {
            if showsLiveArea {
                #if DEBUG
                if CameraMode.current == .rawOnly {
                    statePlaceholder(text: "Raw-only mode: preview disabled for diagnosis. Capture stays available.")
                } else {
                    livePreview
                }
                #else
                livePreview
                #endif
            } else {
                switch camera.phase {
                case .permissionNeeded:
                    statePlaceholder(
                        title: "Camera access needed",
                        text: "Slit uses the rear main camera for street photographs.",
                        actionTitle: "Continue"
                    ) { camera.requestPermission() }
                case .denied:
                    statePlaceholder(
                        title: "Camera access denied",
                        text: "Allow camera access in Settings to capture. Saved photographs remain on this device.",
                        actionTitle: "Open Settings"
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                case .unavailable(let reason):
                    statePlaceholder(title: "Camera unavailable", text: reason, actionTitle: "Retry") {
                        camera.start()
                    }
                case .ready, .suspended, .starting:
                    EmptyView()
                }
            }
        }
    }

    private var showsLiveArea: Bool {
        switch camera.phase {
        case .ready, .suspended, .starting: return true
        default: return false
        }
    }

    private var livePreview: some View {
        ZStack {
            PreviewView(session: camera.session) { camera.previewDidAttach() }
            if gridEnabled { CompositionGrid() }
            if case .starting = camera.phase {
                Text("Starting camera")
                    .font(.caption)
                    .foregroundStyle(GripTheme.secondary)
            }
        }
    }

    private func statePlaceholder(title: String? = nil,
                                  text: String,
                                  actionTitle: String? = nil,
                                  action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera").font(.largeTitle)
            if let title { Text(title).font(.callout) }
            Text(text).font(.caption).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(GripTheme.secondary)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.4))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cameraPlaceholder")
    }

    private var statusStrip: some View {
        VStack(spacing: 2) {
            Text(camera.feedbackMessage ?? " ")
                .font(.caption)
                .foregroundStyle(GripTheme.secondary)
            #if DEBUG
            Text(camera.debugState)
                .font(.caption2.monospaced())
                .foregroundStyle(GripTheme.secondary.opacity(0.6))
                .lineLimit(1)
            #endif
        }
        .frame(minHeight: 44)
    }

    // MARK: Capture controls

    @ViewBuilder
    private func captureControls(isLandscape: Bool) -> some View {
        let layout = isLandscape ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout())
        layout {
            Button {} label: {
                Image(systemName: "photo").frame(width: 52, height: 52)
            }
            .disabled(true)
            .accessibilityLabel("Review unavailable. No saved photographs.")
            if !isLandscape { Spacer() }
            Button { camera.capture() } label: {
                Circle().fill(GripTheme.shutter)
                    .padding(6)
                    .overlay(Circle().stroke(GripTheme.shutter, lineWidth: 2))
                    .frame(width: GripTheme.shutterDiameter, height: GripTheme.shutterDiameter)
                    .scaleEffect(camera.acceptedFlash ? 0.92 : 1)
                    .opacity(camera.canCapture ? 1 : 0.4)
            }
            .disabled(!camera.canCapture)
            .animation(.easeOut(duration: 0.15), value: camera.acceptedFlash)
            .accessibilityLabel("Take photograph")
            .accessibilityIdentifier("shutterButton")
        }
        .padding(.horizontal, isLandscape ? 0 : 24)
    }

    // MARK: Hardware capture events

    private var hardwareCaptureInput: some View {
        HardwareCaptureInput(enabled: scenePhase == .active && !isMorePresented && camera.canCapture) { source, phase in
            camera.hardware(source: source, phase: phase)
        }
    }

    private var moreSheet: some View {
        NavigationStack {
            Form {
                Section("Composition") {
                    Toggle("Grid", isOn: $gridEnabled)
                        .accessibilityIdentifier("gridToggle")
                    Text("A 3 × 3 guide. The setting is saved on this device.")
                        .font(.footnote)
                }
                Section("Build status") {
                    Text("Camera capture")
                    Text("Preview and raw capture are connected. Saving photographs is not connected yet; captured photographs are not kept.")
                }
                #if DEBUG
                Section("Camera diagnostics") {
                    Text("mode: \(CameraMode.current.rawValue)")
                        .font(.caption.monospaced())
                    Text(CameraDiagnostics.recentLines(8).joined(separator: "\n"))
                        .font(.caption2.monospaced())
                        .foregroundStyle(GripTheme.secondary)
                        .lineLimit(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                #endif
            }
            .navigationTitle("More")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isMorePresented = false }
                }
            }
        }
    }
}

/// Bridges hardware capture events (Camera Control, volume buttons) to the camera owner.
/// The host view spans the screen: the interaction must sit on a full-size view in the responder chain.
private struct HardwareCaptureInput: UIViewRepresentable {
    let enabled: Bool
    let receive: (String, AVCaptureEventPhase) -> Void

    final class Coordinator {
        var interaction: AVCaptureEventInteraction?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let interaction = AVCaptureEventInteraction(primary: { event in
            receive("primary", event.phase)
        }, secondary: { event in
            receive("secondary", event.phase)
        })
        interaction.isEnabled = enabled
        context.coordinator.interaction = interaction
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.interaction?.isEnabled = enabled
    }
}
