import Foundation
import StillHereCore

// Use the terminal/automation caller's existing capture context. No permission
// is granted to the GUI and the same bundled probe qualifies both entry points.
func runCommandLineDiagnostics(storage: AppStorage) -> Int32 {
    let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/capture_probe")
    guard FileManager.default.isExecutableFile(atPath: helper.path) else {
        printJSON(["error": "Build the app bundle first: bash scripts/build-app.sh"])
        return 1
    }
    do {
        try storage.prepare()
        let directory = storage.directory.appendingPathComponent("Diagnostics/cli-\(Int(Date().timeIntervalSince1970))")
        let process = Process()
        process.executableURL = helper
        process.arguments = [directory.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let data = try? Data(contentsOf: directory.appendingPathComponent("results.json")),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let record = CaptureCompatibility.fromProbe(result, currentBuild: ProcessInfo.processInfo.operatingSystemVersionString) else {
            printJSON(["passed": false, "error": process.terminationStatus == 77 ?
                "The caller has no screen recording permission. No new permission was requested." : "The capture probe did not complete."])
            return 1
        }
        try storage.save(record, filename: "compatibility.json")
        let passed = record.isUsable(on: ProcessInfo.processInfo.operatingSystemVersionString)
        printJSON(["passed": passed, "osBuild": record.osBuild, "diagnostics": directory.path, "requestedPermissions": false])
        return passed ? 0 : 1
    } catch { printJSON(["error": error.localizedDescription]); return 1 }
}
