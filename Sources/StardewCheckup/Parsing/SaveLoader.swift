import Foundation

enum SaveLoadError: LocalizedError {
    case unreadable(String)
    case decompressFailed
    case notXML(String)
    case notASave

    var errorDescription: String? {
        switch self {
        case .unreadable(let why): return "The save file could not be read. \(why)"
        case .decompressFailed: return "The file looked like a compressed (Switch) save but could not be decompressed."
        case .notXML(let why): return "The file is not a readable Stardew Valley save. \(why)"
        case .notASave: return "This file does not contain a <SaveGame> root. Make sure you chose the full save file (e.g. Fred_148093307), not SaveGameInfo."
        }
    }
}

enum SaveLoader {

    /// Reads, decompresses if needed, parses and runs the checkup on one save file.
    static func load(url: URL) throws -> Report {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SaveLoadError.unreadable(error.localizedDescription)
        }
        let xmlData = try inflateIfNeeded(data)
        let tree: XTree
        do {
            tree = try XTree.parse(stripBOM(xmlData))
        } catch {
            throw SaveLoadError.notXML(error.localizedDescription)
        }
        guard tree.root.name == "SaveGame" else { throw SaveLoadError.notASave }
        var report = Checkup(tree: tree).run()
        report.sourceURL = url
        return report
    }

    /// Switch saves are compressed. The site assumes compression for anything under 500k;
    /// we additionally sniff for zlib/gzip headers so small uncompressed saves still work.
    static func inflateIfNeeded(_ data: Data) throws -> Data {
        guard data.count >= 2 else { return data }
        let b0 = data[data.startIndex]
        let b1 = data[data.startIndex + 1]
        let isGzip = b0 == 0x1f && b1 == 0x8b
        let isZlib = (b0 & 0x0f) == 8 && (UInt16(b0) << 8 | UInt16(b1)) % 31 == 0
        let looksLikeText = b0 == 0x3c || b0 == 0xef || b0 == 0xff || b0 == 0xfe  // '<' or a BOM
        if looksLikeText || !(isGzip || isZlib || data.count < 512_000) { return data }

        var payload: Data
        if isGzip {
            // RFC 1952 header: 10 bytes plus optional fields.
            var offset = 10
            let flags = data[data.startIndex + 3]
            let bytes = [UInt8](data)
            if flags & 0x04 != 0, offset + 2 <= bytes.count {
                let xlen = Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
                offset += 2 + xlen
            }
            if flags & 0x08 != 0 { while offset < bytes.count && bytes[offset] != 0 { offset += 1 }; offset += 1 }
            if flags & 0x10 != 0 { while offset < bytes.count && bytes[offset] != 0 { offset += 1 }; offset += 1 }
            if flags & 0x02 != 0 { offset += 2 }
            guard offset < bytes.count else { throw SaveLoadError.decompressFailed }
            payload = data.subdata(in: (data.startIndex + offset)..<data.endIndex)
        } else if isZlib {
            payload = data.subdata(in: (data.startIndex + 2)..<data.endIndex)
        } else {
            payload = data
        }
        // Apple's .zlib algorithm is raw DEFLATE; the trailing checksum is ignored.
        do {
            let out = try (payload as NSData).decompressed(using: .zlib)
            return out as Data
        } catch {
            if isGzip || isZlib { throw SaveLoadError.decompressFailed }
            return data // was just a small uncompressed file after all
        }
    }

    static func stripBOM(_ data: Data) -> Data {
        if data.count >= 3, data[data.startIndex] == 0xef, data[data.startIndex + 1] == 0xbb, data[data.startIndex + 2] == 0xbf {
            return data.subdata(in: (data.startIndex + 3)..<data.endIndex)
        }
        return data
    }

    // MARK: - Save discovery

    static var defaultSavesDirectory: URL { SaveAccess.defaultSavesDirectory }

    struct SaveEntry: Identifiable, Hashable {
        let url: URL
        let name: String
        let modified: Date
        var id: URL { url }
    }

    /// Lists `<Saves>/<name_id>/<name_id>` files, newest first.
    static func discoverSaves(in dir: URL? = SaveAccess.savesDirectory) -> [SaveEntry] {
        guard let dir else { return [] }
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        var out: [SaveEntry] = []
        for folder in folders {
            let name = folder.lastPathComponent
            let file = folder.appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: file.path), (attrs[.type] as? FileAttributeType) == .typeRegular else { continue }
            let modified = (attrs[.modificationDate] as? Date) ?? .distantPast
            out.append(SaveEntry(url: file, name: name, modified: modified))
        }
        return out.sorted { $0.modified > $1.modified }
    }
}

// MARK: - Plain text rendering (used by the CLI mode and for copying)

enum PlainTextRenderer {
    static func render(_ report: Report) -> String {
        var out = ""
        for section in report.sections {
            out += "\n=== \(section.title) ===\n"
            for cell in section.globalCells { out += render(cell, indent: 0) }
            if !section.columns.isEmpty {
                for row in 0..<section.rowCount {
                    for (p, col) in section.columns.enumerated() where row < col.count {
                        if section.columns.count > 1 { out += "  [\(report.playerNames[p])]\n" }
                        out += render(col[row], indent: section.columns.count > 1 ? 1 : 0)
                    }
                }
            }
            for cell in section.trailingCells { out += render(cell, indent: 0) }
        }
        return out
    }

    static func render(_ cell: Cell, indent: Int) -> String {
        var out = ""
        for b in cell.summary { out += render(b, indent: indent) }
        for b in cell.details { out += render(b, indent: indent) }
        return out
    }

    static func render(_ block: Block, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        switch block {
        case .result(let t): return pad + "◈ " + t.plain + "\n"
        case .explain(let t): return pad + "* " + t.plain + "\n"
        case .note(let t): return pad + "◈ " + t.plain + "\n"
        case .warn(let t): return pad + "! " + t.plain + "\n"
        case .achList(let items): return items.map { pad + "    " + $0.plain + "\n" }.joined()
        case .need(let label, let items, let ordered):
            return pad + "  ! " + label.plain + "\n" + renderItems(items, ordered: ordered, indent: indent + 2)
        case .list(let items, let ordered):
            return renderItems(items, ordered: ordered, indent: indent + 1)
        case .friends(let groups):
            return renderItems(groups.map(\.asDetailItem), ordered: false, indent: indent + 1)
        case .calendar(let c):
            var out = ""
            for season in CalendarData.seasons {
                let evs = (c.events[season] ?? []).sorted { $0.startDay < $1.startDay }
                guard !evs.isEmpty else { continue }
                out += pad + "  " + season + "\n"
                for e in evs {
                    let when = e.isMultiDay ? "\(e.startDay)–\(e.endDay)" : "\(e.startDay)"
                    let mark = e.done ? (e.kind == .birthday ? " (gift given)" : " (attended)") : ""
                    out += pad + "    \(when): \(e.name)\(mark)\n"
                }
            }
            return out
        case .cookPlan(let c):
            var out = ""
            for r in c.rows {
                let ing = r.ingredients.map { "\($0.name) \($0.have)/\($0.need)" + ($0.inReach < $0.need && $0.have >= $0.need ? " (chest)" : "") }.joined(separator: ", ")
                out += pad + "  [\(r.state.label)] \(r.name): \(ing)" + (r.known ? "" : " — learn: \(r.source)") + "\n"
            }
            return out
        case .storage(let s):
            var out = ""
            for b in s.boxes {
                out += pad + "  \(b.label) [\(b.items.count)/\(b.capacity)]\(b.color.map { " rgb(\($0.r),\($0.g),\($0.b))" } ?? "")\(b.directions.map { " — " + $0 } ?? "")\n"
                for i in b.items { out += pad + "    \(i.name) ×\(i.count)\(i.quality > 0 ? " q\(i.quality)" : "")\n" }
            }
            return out
        case .eventPlan(let e):
            var out = ""
            for r in e.rows where !r.isComplete {
                out += pad + "  \(r.name): \(r.hearts)♥ (\(r.points) pts), \(r.seenCount)/\(r.totalTracked) events seen\n"
                for st in r.steps {
                    let kind: String
                    switch st.kind {
                    case .ready: kind = "READY"
                    case .locked: kind = "need \(st.pointsNeeded) pts (~\(st.giftsNeeded) × \(st.bestGift ?? "loved gift"))"
                    case .bouquet: kind = "give a bouquet first"
                    case .marriage: kind = "requires marriage"
                    case .impossible: kind = "impossible"
                    }
                    out += pad + "    \(st.title) [\(kind)]: \(st.trigger)\n"
                }
            }
            return out
        case .giftPlan(let g):
            var out = pad + "  \(g.weekday); gift week resets in \(g.daysUntilReset) day(s); \(g.ownedCount) distinct giftable items owned\n"
            for r in g.rows {
                var line = pad + "  \(r.name): \(r.giftsThisWeek)/2 gifts this week, \(r.hearts)♥"
                if r.isMaxed { line += " (maxed)" }
                if let b = r.birthdayIn { line += b == 0 ? " BIRTHDAY TODAY" : " birthday in \(b) day(s)" }
                out += line + "\n"
                if !r.suggestions.loves.isEmpty { out += pad + "    loves: " + r.suggestions.loves.map { "\($0.name) ×\($0.count)" }.joined(separator: ", ") + "\n" }
                if !r.suggestions.likes.isEmpty { out += pad + "    likes: " + r.suggestions.likes.prefix(12).map { "\($0.name) ×\($0.count)" }.joined(separator: ", ") + "\n" }
            }
            return out
        case .characters(let c):
            var out = ""
            for info in CharacterData.all {
                let st = c.status(of: info.name)
                out += pad + "  \(info.name): \(st.status), \(st.hearts)♥ (\(st.points) pts), birthday \(info.birthday.season) \(info.birthday.day), \(info.address)\n"
                for e in info.heartEvents where !e.isMail {
                    let state = CharactersView.state(of: e, in: st)
                    let mark = state.map { $0 == .yes ? "seen" : ($0 == .imp ? "impossible" : "not seen") } ?? "untracked"
                    out += pad + "    \(e.title) [\(mark)]: \(e.trigger)\n"
                }
            }
            return out
        }
    }

    static func renderItems(_ items: [DetailItem], ordered: Bool, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        var out = ""
        var n = 0
        for item in items {
            n = item.value ?? (n + 1)
            let bullet = ordered ? "\(n)." : "-"
            out += pad + bullet + " " + item.text.plain + "\n"
            if !item.children.isEmpty {
                out += renderItems(item.children, ordered: item.childrenOrdered, indent: indent + 1)
            }
        }
        return out
    }
}

extension PlainTextRenderer {
    /// Text version of the Planner tabs, for `--dump <save> --planners`.
    static func renderPlanners(_ o: Overview) -> String {
        var out = ""
        func item(_ i: PlanItem) -> String {
            var t = i.name + (i.need > 1 && !i.isMoney ? " ×\(i.need)" : "") + (i.qualityLabel.map { " (\($0)+)" } ?? "")
            t += i.done ? " [done]" : i.isReady ? " [in backpack]" : i.isMissing ? " [missing\(i.hint.map { ": " + $0 } ?? "")]" : " [have \(i.have), in storage]"
            return t
        }
        if let b = o.bundlePlan {
            out += "== Bundles: \(b.roomsDone)/\(b.roomsTotal) rooms\(b.isJoja ? " (Joja)" : "")\n"
            for r in b.rows where r.state != .done {
                out += "  [\(r.state)] \(r.room) / \(r.name): \(r.left) left; reward \(r.reward)\n"
                for i in r.items where !i.done { out += "     - " + item(i) + "\n" }
            }
        }
        if let f = o.fishPlan {
            out += "== Fishing: \(f.season) \(f.day), \(f.isRaining ? "rain" : "dry"), level \(f.fishingLevel), \(f.caught)/\(f.total)\n"
            for g in FishPlanRow.Group.allCases {
                let rows = f.rows.filter { $0.group == g }
                if rows.isEmpty { continue }
                out += "  [\(g)] " + rows.map { $0.fish.name + ($0.nextSeason.isEmpty ? "" : " (\($0.nextSeason))") + ($0.blockers.isEmpty ? "" : " {\($0.blockers.joined(separator: "; "))}") }.joined(separator: ", ") + "\n"
            }
        }
        if let c = o.craftPlan {
            out += "== Crafting\n"
            for r in c.rows where r.state != .cooked {
                out += "  [\(r.state.label)] \(r.name): " + r.ingredients.map { "\($0.name) \($0.have)/\($0.need)" }.joined(separator: ", ") + (r.known ? "" : " — learn: \(r.source)") + "\n"
            }
        }
        if let m = o.museumPlan {
            out += "== Museum: \(m.donated)/\(m.total)\n"
            for s in MuseumPlanRow.State.allCases {
                let rows = m.rows.filter { $0.state == s }
                if rows.isEmpty { continue }
                out += "  [\(s)] " + rows.map { $0.name + (s == .donateNow ? " (\($0.places))" : "") }.joined(separator: ", ") + "\n"
            }
        }
        if let s = o.shipPlan {
            out += "== Shipping: \(s.shipped)/\(s.total)\n"
            for st in ShipPlanRow.State.allCases {
                let rows = s.rows.filter { $0.state == st }
                if !rows.isEmpty { out += "  [\(st)] " + rows.map { $0.item.name }.joined(separator: ", ") + "\n" }
            }
        }
        if let c = o.cropPlan {
            out += "== Crops: \(c.season) \(c.day)\n"
            for r in c.rows where r.state != .done {
                out += "  [\(r.state)] \(r.name): \(r.shipped)/15, own \(r.owned), seeds \(r.seedsOwned)" + (r.harvestDay.map { ", harvest day \($0)" } ?? "") + "\n"
            }
        }
        if let m = o.monsterPlan {
            out += "== Monsters: mine \(m.mineLevel), skull \(m.skullLevel)\n"
            for r in m.rows { out += "  \(r.goal): \(r.killed)/\(r.target)\(r.isDone ? (r.claimed ? " claimed" : " CLAIM") : "") — \(r.reward)\n" }
        }
        return out
    }
}
