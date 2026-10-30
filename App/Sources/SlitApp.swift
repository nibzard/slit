import SlitCore
import SwiftUI

@main
struct SlitApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-grid-for-ui-test") {
            UserDefaults.standard.removeObject(forKey: SlitDefaults.gridPreferenceKey)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--capability-probe") {
                CapabilityProbeView().preferredColorScheme(.dark)
            } else {
                GripShellView().preferredColorScheme(.dark)
            }
            #else
            GripShellView().preferredColorScheme(.dark)
            #endif
        }
    }
}
