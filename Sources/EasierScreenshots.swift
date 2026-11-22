import AppKit

@main
final class EasierScreenshots: NSObject, NSApplicationDelegate {
    private let folder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/Screenshots", isDirectory: true)
    private var statusItem: NSStatusItem?
    private var watcher: ScreenshotWatcher?

    static func main() {
        let app = NSApplication.shared
        let delegate = EasierScreenshots()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Easier Screenshots")

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Screenshots Folder", action: #selector(openFolder), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Screenshot Setup…", action: #selector(showSetup), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Easier Screenshots", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        statusItem = item
        startWatching()

        if watcher != nil && !UserDefaults.standard.bool(forKey: "didShowScreenshotSetup") {
            UserDefaults.standard.set(true, forKey: "didShowScreenshotSetup")
            DispatchQueue.main.async { self.showSetup() }
        }
    }

    private func startWatching() {
        let watcher = ScreenshotWatcher(folder: folder, pasteboard: .general) { [weak self] in
            self?.watcher = nil
            self?.statusItem?.button?.toolTip = "Folder moved or removed. Open Screenshots Folder to resume."
        }
        do {
            try watcher.start()
            self.watcher = watcher
            statusItem?.button?.toolTip = "Easier Screenshots"
        } catch {
            statusItem?.button?.toolTip = "Could not open Pictures/Screenshots."
        }
    }

    @objc private func openFolder() {
        if watcher == nil { startWatching() }
        if watcher != nil { NSWorkspace.shared.open(folder) }
    }

    @objc private func showSetup() {
        let alert = NSAlert()
        alert.messageText = "Set up screenshot saving"
        alert.informativeText = """
        In the macOS Screenshot toolbar, choose Options → Other Location, then select Pictures → Screenshots.

        Turn off Show Floating Thumbnail to copy your screenshots as soon as macOS saves them.
        """
        alert.addButton(withTitle: "Open Screenshot Toolbar")
        alert.addButton(withTitle: "Later")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            let screenshotApp = URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app", isDirectory: true)
            NSWorkspace.shared.open(screenshotApp)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
