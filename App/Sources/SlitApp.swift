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
            GripShellView()
                .preferredColorScheme(.dark)
        }
    }
}
