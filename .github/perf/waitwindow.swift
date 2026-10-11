import CoreGraphics
import Foundation

// waitwindow <pid> <t0 epoch seconds> <min width> <min height> <timeout s>
// Prints the seconds from t0 until a window owned by pid, at least that size, is on screen; "timeout" otherwise.
let args = CommandLine.arguments
let pid = Int32(args[1])!, t0 = Double(args[2])!, minW = Double(args[3])!, minH = Double(args[4])!, timeout = Double(args[5])!
while Date().timeIntervalSince1970 - t0 < timeout {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    let found = windows.contains { window in
        guard (window[kCGWindowOwnerPID as String] as? Int32) == pid,
              let bounds = window[kCGWindowBounds as String] as? [String: Double] else { return false }
        return (bounds["Width"] ?? 0) >= minW && (bounds["Height"] ?? 0) >= minH
    }
    if found {
        print(String(format: "%.3f", Date().timeIntervalSince1970 - t0))
        exit(0)
    }
    usleep(5_000)
}
print("timeout")
