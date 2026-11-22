import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Runs on the main queue and wakes only when the screenshot folder changes.
final class ScreenshotWatcher {
    private static let pngEndChunk: [UInt8] = [0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82]
    private let folder: URL
    private let pasteboard: NSPasteboard
    private let onStop: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var scheduledScan: DispatchWorkItem?
    private var knownFiles: Set<URL> = []
    private var pendingFiles: Set<URL> = []
    private var retriesRemaining = 12

    init(folder: URL, pasteboard: NSPasteboard, onStop: @escaping () -> Void) {
        self.folder = folder
        self.pasteboard = pasteboard
        self.onStop = onStop
    }

    func start() throws {
        precondition(source == nil)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        knownFiles = try imageFiles()

        let descriptor = open(folder.path, O_EVTONLY | O_CLOEXEC)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }

        let invalidated: DispatchSource.FileSystemEvent = [.rename, .delete, .revoke]
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: invalidated.union(.write), queue: .main
        )
        source.setCancelHandler { close(descriptor) }
        source.setEventHandler { [weak self] in
            guard let self, let events = self.source?.data else { return }
            guard events.intersection(invalidated).isEmpty else {
                self.stop()
                self.onStop()
                return
            }
            self.retriesRemaining = 12
            self.scheduleScan()
        }
        self.source = source
        source.activate()
        scheduleScan() // Catch a file written while the watch was being registered.
    }

    deinit { stop() }

    private func stop() {
        scheduledScan?.cancel()
        scheduledScan = nil
        source?.cancel()
        source = nil
    }

    private func imageFiles() throws -> Set<URL> {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
        let contents = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
        )
        return Set(contents.filter { url in
            guard UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true,
                  let values = try? url.resourceValues(forKeys: keys) else { return false }
            return values.isRegularFile == true && values.isSymbolicLink == false
        })
    }

    private func scheduleScan() {
        scheduledScan?.cancel()
        let scan = DispatchWorkItem { [weak self] in self?.scan() }
        scheduledScan = scan
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150), execute: scan)
    }

    private func scan() {
        scheduledScan = nil
        guard let currentFiles = try? imageFiles() else { return }
        pendingFiles.formUnion(currentFiles.subtracting(knownFiles))
        pendingFiles.formIntersection(currentFiles)
        knownFiles = currentFiles

        let newestFirst = pendingFiles.map { url in
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return (url, (date, url.lastPathComponent))
        }.sorted { $0.1 > $1.1 }.map(\.0)

        // Keep retrying files that are still being written. Once a newer image
        // has been copied, older images from this batch can stay on disk only.
        if let copied = newestFirst.firstIndex(where: copyImage) {
            pendingFiles = Set(newestFirst.prefix(copied))
        }
        guard !pendingFiles.isEmpty else { return }
        guard retriesRemaining > 0 else {
            pendingFiles.removeAll()
            return
        }
        retriesRemaining -= 1
        scheduleScan()
    }

    private func copyImage(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let image = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetStatus(image) == .statusComplete,
              CGImageSourceGetStatusAtIndex(image, 0) == .statusComplete else { return false }

        let item = NSPasteboardItem()
        if CGImageSourceGetType(image) as String? == UTType.png.identifier {
            // ImageIO can recognize a PNG before its final IEND chunk is on disk.
            guard data.suffix(Self.pngEndChunk.count).elementsEqual(Self.pngEndChunk),
                  item.setData(data, forType: .png) else { return false }
        } else {
            guard let tiff = NSImage(data: data)?.tiffRepresentation,
                  item.setData(tiff, forType: .tiff) else { return false }
        }

        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }
}
