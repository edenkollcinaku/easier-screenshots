import AppKit
import ImageIO

enum Failure: Error {
    case invalidPNG, missingCopy, oldFileCopied, prematurelyCopied, fileChanged, unexpectedCopy
}

func makePNG(red: UInt8, green: UInt8, blue: UInt8) throws -> Data {
    let bytes = Data([red, green, blue, 255])
    guard let pixel = CGDataProvider(data: bytes as CFData),
          let image = CGImage(
            width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: pixel, decode: nil, shouldInterpolate: false, intent: .defaultIntent
          ) else { throw Failure.invalidPNG }
    let data = NSMutableData()
    guard let writer = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
        throw Failure.invalidPNG
    }
    CGImageDestinationAddImage(writer, image, nil)
    guard CGImageDestinationFinalize(writer) else { throw Failure.invalidPNG }
    return data as Data
}

func wait(_ seconds: Double) {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
}

@main
struct SmokeTest {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("easier-screenshots-test-\(UUID())")
        let folder = root.appendingPathComponent("Screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("Before launch", forType: .string)

        let first = try makePNG(red: 255, green: 0, blue: 0)
        let second = try makePNG(red: 0, green: 255, blue: 0)
        let third = try makePNG(red: 0, green: 0, blue: 255)
        let old = folder.appendingPathComponent("Already on disk.png")
        try third.write(to: old)
        var stopped = false
        let watcher = ScreenshotWatcher(folder: folder, pasteboard: pasteboard) { stopped = true }
        try watcher.start()
        wait(0.4)
        guard pasteboard.string(forType: .string) == "Before launch" else { throw Failure.oldFileCopied }

        let new = folder.appendingPathComponent("New capture.png")
        try first.write(to: new, options: .atomic)
        wait(0.4)
        guard pasteboard.data(forType: .png) == first else { throw Failure.missingCopy }
        guard try Data(contentsOf: new) == first else { throw Failure.fileChanged }

        let partial = folder.appendingPathComponent("Capture in progress.png")
        let split = min(16, second.count - 1)
        try second.prefix(split).write(to: partial)
        wait(0.35)
        guard pasteboard.data(forType: .png) == first else { throw Failure.prematurelyCopied }
        let file = try FileHandle(forWritingTo: partial)
        try file.seekToEnd()
        try file.write(contentsOf: second.dropFirst(split))
        try file.close()
        wait(0.45)
        guard pasteboard.data(forType: .png) == second else { throw Failure.missingCopy }

        let unrelated = folder.appendingPathComponent("Recording.mov")
        try third.write(to: unrelated, options: .atomic)
        wait(0.35)
        guard pasteboard.data(forType: .png) == second else { throw Failure.unexpectedCopy }

        try FileManager.default.moveItem(at: folder, to: root.appendingPathComponent("Renamed"))
        wait(0.35)
        precondition(stopped, "Folder removal should stop the watcher.")
        withExtendedLifetime(watcher) {}
        print("Verified startup preserves clipboard, new images copy with exact bytes and stay on disk, partial writes retry, recordings are ignored, and moving the folder stops the watch.")
    }
}
