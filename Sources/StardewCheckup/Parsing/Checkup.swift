import Foundation

/// Scratch state shared between a section function and its per-player helper
/// (the `meta` object in the original source).
class SectionMeta {
    var hasDetails = false
}

/// Drives the whole checkup: builds `SaveInfo` and runs each section in the
/// same order as the site's `handleFileSelect`.
final class Checkup {
    let doc: XNode
    let info = SaveInfo()

    init(tree: XTree) {
        self.doc = XNode(tree.root, tree: tree)
        self.hostPlayer = doc.first("SaveGame > player") ?? doc.find("player").first ?? doc
    }

    /// The host farmer element (`SaveGame > player`), looked up once.
    let hostPlayer: XNode

    /// Host player's heart-event states keyed by the Social section's event id string
    /// (e.g. "53|584059"), and per-villager friendship status; filled by `parseSocial`
    /// and consumed by `parseCharacters`.
    var hostEventStates: [String: MarkState] = [:]
    var hostCharacterStatus: [String: CharacterStatus] = [:]

    /// Set via `--timing` to print per-section timings to stderr.
    static var timingEnabled = false

    private func timed(_ label: String, _ f: () -> Section?) -> Section? {
        let t0 = Date()
        let s = f()
        if Checkup.timingEnabled {
            FileHandle.standardError.write(Data(String(format: "%-28@ %6.0f ms\n", label, Date().timeIntervalSince(t0) * 1000).utf8))
        }
        return s
    }

    func run() -> Report {
        var report = Report()
        var sections: [Section?] = []
        sections.append(parseSummary())
        sections.append(timed("parseMoney") { parseMoney() })
        sections.append(timed("parseSkills") { parseSkills() })
        sections.append(timed("parseSkillMastery") { parseSkillMastery() })
        sections.append(timed("parseQuests") { parseQuests() })
        sections.append(timed("parseSpecialOrders") { parseSpecialOrders() })
        sections.append(timed("parseMonsters") { parseMonsters() })
        sections.append(timed("parseStardrops") { parseStardrops() })
        sections.append(timed("parseFamily") { parseFamily() })
        sections.append(timed("parseSocial") { parseSocial() })
        sections.append(timed("parseCalendar") { parseCalendar() })
        sections.append(timed("parseCharacters") { parseCharacters() })
        sections.append(timed("parseCooking") { parseCooking() })
        sections.append(timed("parseCrafting") { parseCrafting() })
        sections.append(timed("parseFishing") { parseFishing() })
        sections.append(timed("parseBasicShipping") { parseBasicShipping() })
        sections.append(timed("parseCropShipping") { parseCropShipping() })
        sections.append(timed("parsePowers") { parsePowers() })
        sections.append(timed("parseMuseum") { parseMuseum() })
        sections.append(timed("parseSecretNotes") { parseSecretNotes() })
        sections.append(timed("parseJournalScraps") { parseJournalScraps() })
        sections.append(timed("parseBundles") { parseBundles() })
        sections.append(timed("parseRaccoons") { parseRaccoons() })
        sections.append(timed("parseGrandpa") { parseGrandpa() })
        sections.append(timed("parseWalnuts") { parseWalnuts() })
        sections.append(timed("parseIslandUpgrades") { parseIslandUpgrades() })
        sections.append(timed("parsePerfectionTracker") { parsePerfectionTracker() })
        sections.append(timed("parseArcadeGames") { parseArcadeGames() })
        sections.append(timed("parseAnimals") { parseAnimals() })
        report.sections = sections.compactMap { $0 }
        report.farmName = info.farmName
        report.playerNames = info.playerOrder.map { info.playerName($0) }
        report.version = info.version
        report.farmerName = info.playerName(info.farmerId)
        report.overview = buildOverview()
        if let summary = report.sections.first?.globalCells.first?.summary {
            let lines = summary.compactMap { b -> String? in if case .result(let t) = b { return t.plain }; return nil }
            // lines: farm, farmer, date, played, version
            report.summaryLine = lines.dropFirst(2).map { $0.replacingOccurrences(of: "Played for ", with: "").replacingOccurrences(of: "Save is from version ", with: "v") }.joined(separator: " · ")
        }
        return report
    }

    /// Collects the dashboard numbers from the perfection tracker and the sections' own notes.
    private func buildOverview() -> Overview {
        var o = info.overview
        let host = info.farmerId
        let pt = info.perfection
        func add(_ title: String, _ anchor: String, _ key: String) {
            guard let v = pt.perPlayer[host]?[key] else { return }
            o.collections.append((title, anchor, v.count, v.total))
        }
        add("Shipping", "Basic_Shipping", "Shipping")
        add("Cooking", "Cooking", "Cooking")
        add("Crafting", "Crafting", "Crafting")
        add("Fishing", "Fishing", "Fishing")
        add("Great Friends", "Social", "Great Friends")
        add("Skills", "Skills", "Skills")
        if info.isAtLeast("1.5") {
            o.collections.append(("Golden Walnuts", "Golden_Walnuts", pt.walnuts.count, pt.walnuts.total))
        }
        return o
    }

    // MARK: - Shared helpers

    /// Runs `body` for the host and every farmhand, collecting one column per player
    /// (port of `table[0] = parsePlayerX(...)` + `parseFarmhands`).
    func perPlayer(_ body: (XNode) -> [Cell]) -> [[Cell]] {
        var columns: [[Cell]] = [body(hostPlayer)]
        if info.numPlayers > 1 {
            for fh in info.farmhands(in: doc) {
                columns.append(body(fh))
            }
        }
        return columns
    }

    /// Builds a per-player section with the standard header/footer treatment.
    func playerSection(title: String, version: String, _ body: (XNode, SectionMeta) -> [Cell]) -> Section {
        var section = Section(title: title, version: version)
        let meta = SectionMeta()
        section.columns = perPlayer { body($0, meta) }
        section.hasDetails = meta.hasDetails
        return section
    }

    func playerName(_ player: XNode) -> String { player.childText("name") }

    /// `<ol>` detail list from pre-sorted strings.
    static func sortedItems(_ items: [DetailItem]) -> [DetailItem] {
        items.sorted { $0.sortKey < $1.sortKey }
    }
}
