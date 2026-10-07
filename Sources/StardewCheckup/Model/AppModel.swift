import SwiftUI
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @Published var report: Report?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var saves: [SaveLoader.SaveEntry] = SaveLoader.discoverSaves()
    /// True until the user has pointed the app at their Saves folder once.
    var needsFolderGrant: Bool { !SaveAccess.hasFolderGrant }
    @Published var showAcknowledgements = false

    /// Output Preferences, persisted like the site's cookies.
    @AppStorage("checkup-opt-old") var prefOldRaw: String = OutputPref.hideDetails.rawValue
    @AppStorage("checkup-opt-new") var prefNewRaw: String = OutputPref.hideAll.rawValue

    var prefOld: OutputPref {
        get { OutputPref(rawValue: prefOldRaw) ?? .hideDetails }
        set { prefOldRaw = newValue.rawValue; resetVisibility() }
    }
    var prefNew: OutputPref {
        get { OutputPref(rawValue: prefNewRaw) ?? .hideAll }
        set { prefNewRaw = newValue.rawValue; resetVisibility() }
    }

    /// Per-section show/hide state for summary and details (the site's toggle buttons).
    @Published var summaryShown: [String: Bool] = [:]
    @Published var detailsShown: [String: Bool] = [:]
    /// Which player columns are displayed (multiplayer toggle bar).
    @Published var hiddenPlayers: Set<Int> = []
    /// Section the sidebar wants to scroll to.
    @Published var scrollTarget: String?
    /// Sidebar selection: a section anchor, or `allSectionsID` for the full report.
    @Published var selectedSection: String? = AppModel.overviewID
    static let allSectionsID = "__all__"
    static let overviewID = "__overview__"

    private var currentURL: URL?
    private var watcher: SaveWatcher?
    /// Reload automatically when the game writes a new save (watches the save folder).
    @AppStorage("auto-reload") var autoReload = true {
        didSet { updateWatcher() }
    }
    @Published var lastLoaded: Date?

    init() {
        // `StardewCheckup --open <save file>` launches the GUI with that save loaded.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--open"), i + 1 < args.count {
            load(url: URL(fileURLWithPath: args[i + 1]))
        }
        // Test hook: `--remember-folder <path>` stores the folder grant without the panel.
        if let i = args.firstIndex(of: "--remember-folder"), i + 1 < args.count {
            SaveAccess.rememberFolder(URL(fileURLWithPath: args[i + 1], isDirectory: true))
            refreshSaves()
        }
    }

    func pref(for section: Section) -> OutputPref {
        section.isNew ? prefNew : prefOld
    }
    func isSummaryShown(_ s: Section) -> Bool { summaryShown[s.id] ?? pref(for: s).showsSummary }
    func isDetailsShown(_ s: Section) -> Bool { detailsShown[s.id] ?? pref(for: s).showsDetails }
    /// A section opened on its own page shows its details unless the user chose otherwise.
    func isDetailsShown(_ s: Section, standalone: Bool) -> Bool {
        standalone ? (detailsShown[s.id] ?? (s.hasDetails || pref(for: s).showsDetails)) : isDetailsShown(s)
    }
    func isSummaryShown(_ s: Section, standalone: Bool) -> Bool {
        standalone ? (summaryShown[s.id] ?? true) : isSummaryShown(s)
    }
    func toggleSummary(_ s: Section) { summaryShown[s.id] = !isSummaryShown(s) }
    func toggleDetails(_ s: Section) { detailsShown[s.id] = !isDetailsShown(s) }
    func setVisibility(_ s: Section, summary: Bool, details: Bool) {
        summaryShown[s.id] = summary
        detailsShown[s.id] = details
    }

    func resetVisibility() {
        summaryShown = [:]
        detailsShown = [:]
    }

    func togglePlayer(_ index: Int) {
        if hiddenPlayers.contains(index) { hiddenPlayers.remove(index) } else { hiddenPlayers.insert(index) }
    }

    func refreshSaves() {
        saves = SaveLoader.discoverSaves()
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Stardew Valley save file"
        panel.message = "Use the full save file named with your farmer's name and an ID number (e.g. Fred_148093307), not SaveGameInfo."
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        if let dir = SaveAccess.savesDirectory, FileManager.default.fileExists(atPath: dir.path) { panel.directoryURL = dir }
        if panel.runModal() == .OK, let url = panel.url {
            SaveAccess.rememberFile(url)
            load(url: url)
        }
    }

    /// Sandbox: ask for the saves folder, then list what's in it.
    func grantSavesFolder() {
        if SaveAccess.requestSavesFolder() != nil {
            refreshSaves()
        }
    }

    func reload() {
        if let url = currentURL { load(url: url) }
    }

    private func updateWatcher() {
        guard autoReload, let url = currentURL else { watcher = nil; return }
        if watcher == nil {
            watcher = SaveWatcher(fileURL: url) { [weak self] in self?.load(url: url, automatic: true) }
        }
    }

    /// Loads a save. An automatic reload keeps the current view state and stays quiet
    /// if the file is briefly unreadable while the game is still writing it.
    func load(url: URL, automatic: Bool = false) {
        if url != currentURL { watcher = nil }
        currentURL = url
        if !automatic { isLoading = true }
        errorMessage = nil
        Task.detached(priority: .userInitiated) {
            let result = Result { try SaveLoader.load(url: url) }
            await MainActor.run {
                self.isLoading = false
                switch result {
                case .success(let report):
                    self.report = report
                    self.lastLoaded = Date()
                    self.updateWatcher()
                    self.watcher?.markCurrent()
                    if automatic { return }
                    self.resetVisibility()
                    self.hiddenPlayers = []
                    self.scrollTarget = nil
                    // `--scroll-to <anchor>` jumps to a section after loading (handy for testing).
                    let args = CommandLine.arguments
                    if let i = args.firstIndex(of: "--scroll-to"), i + 1 < args.count {
                        let anchor = args[i + 1]
                        self.selectedSection = anchor
                    }
                case .failure(let error):
                    if automatic {
                        // Probably caught the game mid-write; try once more shortly.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                            guard let self, self.currentURL == url else { return }
                            if (try? SaveLoader.load(url: url)) != nil { self.load(url: url, automatic: true) }
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    func copyAsText() {
        guard let report else { return }
        let text = PlainTextRenderer.render(report)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
