import Foundation
import AppKit

/// Access to the Stardew Valley saves folder.
///
/// The app never reads the saves folder until the user has pointed at it once through an
/// open panel (which also lets people keep saves somewhere other than the default). The
/// choice is stored as a bookmark so it survives relaunches, and it is security-scoped so
/// the same code works inside the App Sandbox. Individual files chosen with ⌘O work
/// regardless.
enum SaveAccess {
    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    private static let folderKey = "saves-folder-bookmark"
    private static let fileKey = "last-save-bookmark"
    private static var activeScopes: [URL] = []

    /// The default Stardew save folder for this user (may not be readable when sandboxed).
    static var defaultSavesDirectory: URL {
        // Inside the sandbox `homeDirectoryForCurrentUser` is the container; use the real home.
        let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath()
        let real = isSandboxed ? realHomeDirectory() : home
        return real.appendingPathComponent(".config/StardewValley/Saves", isDirectory: true)
    }

    private static func realHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// The saves folder the user has granted, if any.
    static var savesDirectory: URL? {
        resolveBookmark(key: folderKey)
    }

    static var hasFolderGrant: Bool { resolveBookmark(key: folderKey) != nil }

    /// Remember the user's chosen saves folder.
    static func rememberFolder(_ url: URL) {
        store(url, key: folderKey)
    }

    /// Remember an individually chosen save file so it can be reopened later.
    static func rememberFile(_ url: URL) {
        store(url, key: fileKey)
    }

    static var lastFile: URL? { resolveBookmark(key: fileKey) }

    static func forgetFolder() {
        UserDefaults.standard.removeObject(forKey: folderKey)
    }

    private static func store(_ url: URL, key: String) {
        // Security-scoped when possible (sandbox); a plain bookmark otherwise.
        if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: key)
        } else if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            NSLog("Could not create bookmark for \(url.path)")
        }
    }

    /// Resolves a bookmark and starts accessing it (kept open for the app's lifetime).
    private static func resolveBookmark(key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        let url: URL
        if let u = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
            url = u
        } else if let u = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
            url = u
        } else {
            return nil
        }
        if stale { store(url, key: key) }
        if !activeScopes.contains(url) {
            if url.startAccessingSecurityScopedResource() { activeScopes.append(url) }
        }
        return url
    }

    /// Asks the user to grant access to the Stardew Valley saves folder.
    @MainActor
    static func requestSavesFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose your Stardew Valley Saves folder"
        panel.message = "Select the Saves folder (usually ~/.config/StardewValley/Saves) so the app can list your saves and reload them when the game saves."
        panel.prompt = "Grant Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        let def = defaultSavesDirectory
        panel.directoryURL = FileManager.default.fileExists(atPath: def.path) ? def : def.deletingLastPathComponent().deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        rememberFolder(url)
        _ = resolveBookmark(key: folderKey)
        return url
    }
}
