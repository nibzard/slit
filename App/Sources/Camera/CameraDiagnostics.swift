// ABOUTME: Rolling camera lifecycle log: one os_log line per event plus a capped file copy in Documents.
// ABOUTME: The file copy lets a wedged device run be read after the force restart that recovers the subsystem.

import Foundation
import os

enum CameraDiagnostics {
    private static let logger = Logger(subsystem: "slit.camera", category: "lifecycle")
    private static let fileQueue = DispatchQueue(label: "slit.camera.diagnostics")
    private static let lineLimit = 300
    private static let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("camera-diagnostics.log")

    static func event(_ text: String) {
        let date = Date()
        fileQueue.async {
            let line = "\(stamp(date)) \(text)"
            logger.info("\(line, privacy: .public)")
            append(line)
        }
    }

    /// The most recent events, oldest first. Read after a restart to see what the session reported before a fault.
    static func recentLines(_ limit: Int = lineLimit) -> [String] {
        let stored = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let lines = stored.split(separator: "\n").map(String.init)
        return Array(lines.suffix(limit))
    }

    private static func append(_ line: String) {
        var lines = recentLines()
        lines.append(line)
        if lines.count > lineLimit { lines.removeFirst(lines.count - lineLimit) }
        let text = lines.joined(separator: "\n") + "\n"
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
