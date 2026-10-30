import SlitCore
import SwiftUI

/// A development shell. No camera, simulated capture, or storage success is presented.
struct GripShellView: View {
    @AppStorage(SlitDefaults.gridPreferenceKey) private var gridEnabled = SlitDefaults.gridInitiallyEnabled
    @State private var isMorePresented = false

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
                        previewPlaceholder.aspectRatio(4 / 3.0, contentMode: .fit)
                        VStack {
                            Spacer()
                            captureControls(isLandscape: true)
                        }
                        .frame(width: 144)
                    }
                    .padding(.horizontal, 24)
                } else {
                    previewPlaceholder.aspectRatio(3 / 4.0, contentMode: .fit)
                        .frame(maxHeight: max(0, geometry.size.height - 210))
                    Text("Camera implementation pending")
                        .font(.caption).foregroundStyle(GripTheme.secondary)
                        .frame(height: 44)
                    Spacer(minLength: 0)
                    captureControls(isLandscape: false)
                }
            }
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(GripTheme.background.ignoresSafeArea())
        .foregroundStyle(GripTheme.text)
        .sheet(isPresented: $isMorePresented) {
            NavigationStack {
                Form {
                    Section("Composition") {
                        Toggle("Grid", isOn: $gridEnabled)
                            .accessibilityIdentifier("gridToggle")
                        Text("A 3 × 3 guide. The setting is saved on this device.")
                            .font(.footnote)
                    }
                    Section("Build status") {
                        Text("Development shell")
                        Text("Capture, focus, storage, and review are not connected yet.")
                        Text("The camera is not opened and no photographs are saved.")
                    }
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

    private var previewPlaceholder: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.4))
            VStack(spacing: 12) {
                Image(systemName: "camera").font(.largeTitle)
                Text("Camera integration pending").font(.callout)
                Text("Development shell · no live preview").font(.caption)
            }
            .foregroundStyle(GripTheme.secondary)
            if gridEnabled { CompositionGrid() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cameraPlaceholder")
    }

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
            Button {} label: {
                Circle().fill(GripTheme.shutter)
                    .padding(6)
                    .overlay(Circle().stroke(GripTheme.shutter, lineWidth: 2))
                    .frame(width: GripTheme.shutterDiameter, height: GripTheme.shutterDiameter)
            }
            .disabled(true)
            .opacity(0.4)
            .accessibilityLabel("Take photograph")
            .accessibilityHint("Unavailable until native capture is implemented")
            .accessibilityIdentifier("shutterButton")
        }
        .padding(.horizontal, isLandscape ? 0 : 24)
    }
}
