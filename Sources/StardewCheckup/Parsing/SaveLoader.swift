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
