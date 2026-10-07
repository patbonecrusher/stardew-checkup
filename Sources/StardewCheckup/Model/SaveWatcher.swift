import Foundation

/// Watches the folder that contains a save file and reports when the file changes.
///
/// Stardew Valley writes a new save to a temporary file and then renames it over the
/// old one, so watching the file descriptor itself would be left pointing at the
/// `_old` copy. Watching the directory catches every variant of that dance; we then
/// compare the file's modification date and size to decide whether it really changed.
final class SaveWatcher {
    private let fileURL: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var pending: DispatchWorkItem?
    private var lastStamp: (Date, Int)?
    private var pollTimer: Timer?

    init(fileURL: URL, onChange: @escaping () -> Void) {
        self.fileURL = fileURL
        self.onChange = onChange
        lastStamp = SaveWatcher.stamp(of: fileURL)
        start()
    }

    deinit { stop() }

    /// Call after a successful load so a change we triggered ourselves is not reported twice.
    func markCurrent() {
        lastStamp = SaveWatcher.stamp(of: fileURL)
    }

    private func start() {
        let dir = fileURL.deletingLastPathComponent()
        fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else {
            // No permission to watch the folder (sandbox with only the file granted):
            // fall back to polling the file's attributes.
            pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.check() }
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete, .attrib, .extend], queue: .main)
        src.setEventHandler { [weak self] in self?.scheduleCheck() }
        src.setCancelHandler { [fd] in close(fd) }
        src.resume()
        source = src
    }

    private func stop() {
        pending?.cancel()
        pollTimer?.invalidate()
        pollTimer = nil
        source?.cancel()
        source = nil
    }

    /// Debounce: the game touches the folder several times while saving.
    private func scheduleCheck() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.check() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func check() {
        guard let now = SaveWatcher.stamp(of: fileURL) else { return }  // mid-rename; wait for the next event
        if let last = lastStamp, last.0 == now.0, last.1 == now.1 { return }
        lastStamp = now
        onChange()
    }

    private static func stamp(of url: URL) -> (Date, Int)? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date,
              let size = attrs[.size] as? Int else { return nil }
        return (date, size)
    }
}
