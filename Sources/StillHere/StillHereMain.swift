import AppKit
import StillHereCore
import Darwin

func printJSON(_ value: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) {
        print(String(decoding: data, as: UTF8.self))
    }
}

func runtimeState(_ storage: AppStorage) -> [String: Any]? {
    guard let data = try? Data(contentsOf: storage.directory.appendingPathComponent("runtime.json")),
          var state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let pid = state["pid"] as? Int32 else { return nil }
    if kill(pid, 0) != 0 && errno == ESRCH { state["running"] = false; state["protected"] = false }
    return state
}

@main
enum StillHereMain {
    @MainActor static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let storage = AppStorage()
        if args.contains("--version") { print(appVersion); return }
        if args.contains("--help") {
            print("""
            StillHere \(appVersion) — independent Mac privacy wallpaper
            --status                    Print current application status
            --shield                    Ask the running app to enable privacy
            --unlock                    Remove the privacy wallpaper
            --settings                  Show settings while privacy is off
            --quit                      Quit and remove the privacy wallpaper
            --fixture                   Show the explicit automation test window
            --close-fixture             Close that test window
            --diagnose                  Qualify capture from this terminal's existing permission context
            STILLHERE_DATA_DIR          Optional isolated profile directory for tests
            """)
            return
        }
        if args.contains("--status") { printJSON(runtimeState(storage) ?? ["running": false, "protected": false]); return }
        if args.contains("--diagnose") { exit(runCommandLineDiagnostics(storage: storage)) }
        if args.contains("--init-password-stdin") {
            printJSON(["error": "This version does not use an exit password. Existing data was not changed."])
            exit(2)
        }
        let commands = ["--shield": "shield", "--unlock": "unlock", "--settings": "settings",
                        "--quit": "quit", "--fixture": "fixture", "--close-fixture": "close-fixture", "--diagnose": "diagnose"]
        let action = args.compactMap { commands[$0] }.first
        let running = runtimeState(storage)?["running"] as? Bool == true
        if let action, running {
            DistributedNotificationCenter.default().postNotificationName(commandNotification,
                object: storage.commandScope, userInfo: ["action": action], deliverImmediately: true)
            printJSON(["requestSent": action])
            return
        }
        if let action, action != "fixture" {
            printJSON(["error": "StillHere is not running. Open StillHere.app first."])
            exit(3)
        }
        do { try storage.prepare() }
        catch { printJSON(["error": error.localizedDescription]); exit(1) }
        let lockPath = storage.directory.appendingPathComponent("run.lock").path
        let descriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0, flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            printJSON(["error": "Another StillHere instance owns this profile."])
            exit(4)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate(storage: storage, fixture: args.contains("--fixture"))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
