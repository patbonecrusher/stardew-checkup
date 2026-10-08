import Foundation

// MARK: - Rich text

/// Semantic colours matching the site's CSS classes.
enum RunColor: Equatable {
    case yes        // .ach_yes / .ms_yes / .pt_yes  (#004000)
    case no         // .ach_no / .ms_no / .pt_no     (#c00000)
    case impossible // .ach_imp / .ms_imp / .pt_imp  (#888)
    case link       // a:link (#804000)
}

struct Run: Equatable {
    var text: String
    var color: RunColor? = nil
    var italic = false
    var bold = false
    var url: URL? = nil
    var tooltip: String? = nil
}

/// A line of styled text. Mirrors the inline HTML the site builds.
struct RichText: Equatable {
    var runs: [Run] = []

    init() {}
    init(_ plain: String) { runs = [Run(text: plain)] }
    init(runs: [Run]) { self.runs = runs }

    var plain: String { runs.map(\.text).joined() }
    var isEmpty: Bool { runs.allSatisfy { $0.text.isEmpty } }

    static func + (lhs: RichText, rhs: RichText) -> RichText {
        RichText(runs: lhs.runs + rhs.runs)
    }
    static func + (lhs: RichText, rhs: String) -> RichText {
        RichText(runs: lhs.runs + [Run(text: rhs)])
    }
    static func + (lhs: String, rhs: RichText) -> RichText {
        RichText(runs: [Run(text: lhs)] + rhs.runs)
    }
    static func += (lhs: inout RichText, rhs: RichText) { lhs.runs += rhs.runs }
    static func += (lhs: inout RichText, rhs: String) { lhs.runs.append(Run(text: rhs)) }

    /// Apply a colour to every run that does not already have one.
    func colored(_ c: RunColor) -> RichText {
        RichText(runs: runs.map { r in var r = r; if r.color == nil { r.color = c }; return r })
    }
    func italicized() -> RichText {
        RichText(runs: runs.map { r in var r = r; r.italic = true; return r })
    }
    func bolded() -> RichText {
        RichText(runs: runs.map { r in var r = r; r.bold = true; return r })
    }
}

extension String {
    var rt: RichText { RichText(self) }
    var italic: RichText { RichText(runs: [Run(text: self, italic: true)]) }
    var bold: RichText { RichText(runs: [Run(text: self, bold: true)]) }
}

/// Equivalent of `wikify(item, page, no_anchor)`.
func wikify(_ item: String, _ page: String? = nil, noAnchor: Bool = false) -> RichText {
    var trimmed = item.replacingOccurrences(of: " (White)", with: "")
    trimmed = trimmed.replacingOccurrences(of: " (Brown)", with: "")
    trimmed = trimmed.replacingOccurrences(of: " (Any)", with: "")
    trimmed = trimmed.replacingOccurrences(of: "#", with: ".23")
    trimmed = trimmed.replacingOccurrences(of: " ", with: "_")
    let base = "https://stardewvalleywiki.com/"
    let urlString: String
    if let page = page {
        urlString = noAnchor ? base + page : base + page + "#" + trimmed
    } else {
        urlString = base + trimmed
    }
    let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.union(CharacterSet(charactersIn: "#"))) ?? urlString
    return RichText(runs: [Run(text: item, color: .link, url: URL(string: encoded))])
}

// MARK: - Status lines (achievements, milestones, points, perfection)

/// One entry of the site's `<ul class="ach_list">`: a goal with a yes/no/impossible
/// state, its text, and an optional numeric progress for a bar.
struct StatusLine {
    enum Kind { case achievement, milestone, point, perfection }
    enum State { case yes, no, impossible }

    var kind: Kind
    var state: State
    /// The text after the status mark (e.g. "Greenhorn (earn 15,000g) -- need 1,000g more").
    var text: RichText
    var progress: (current: Double, goal: Double)? = nil
    var progressLabel: String? = nil

    /// Site-equivalent plain string, used by the text export.
    var plain: String {
        let mark: String
        switch (kind, state) {
        case (.point, _), (.perfection, _): mark = ""
        case (_, .yes): mark = "✔ "
        default: mark = "✘ "
        }
        return mark + text.plain
    }

    static func + (lhs: StatusLine, rhs: String) -> StatusLine {
        var l = lhs; l.text += rhs; return l
    }
    static func + (lhs: StatusLine, rhs: RichText) -> StatusLine {
        var l = lhs; l.text += rhs; return l
    }
    static func += (lhs: inout StatusLine, rhs: String) { lhs.text += rhs }
    static func += (lhs: inout StatusLine, rhs: RichText) { lhs.text += rhs }

    /// Attach a numeric progress (shown as a bar in the app).
    func progress(_ current: Int, _ goal: Int, label: String? = nil) -> StatusLine {
        var l = self
        l.progress = (Double(current), Double(goal))
        l.progressLabel = label ?? "\(addCommas(current)) / \(addCommas(goal))"
        return l
    }
    func progress(fraction: Double) -> StatusLine {
        var l = self
        l.progress = (min(max(fraction, 0), 1), 1)
        l.progressLabel = nil
        return l
    }
}

// MARK: - Result-string builders (ports of the site's helper functions)

enum Fmt {
    /// getAchieveString: when `yes` is false the caller appends the "need ..." text.
    static func achieve(_ name: String, _ desc: String, _ yes: Bool) -> StatusLine {
        let d = desc.isEmpty ? "" : "(\(desc)) "
        if yes {
            return StatusLine(kind: .achievement, state: .yes, text: RichText(runs: [Run(text: name, color: .yes, italic: true), Run(text: " \(d) achieved", color: .yes)]))
        } else {
            return StatusLine(kind: .achievement, state: .no, text: RichText(runs: [Run(text: name, color: .no, italic: true), Run(text: " \(d)", color: .no), Run(text: " -- need ")]))
        }
    }
    static func achieveImpossible(_ name: String, _ desc: String) -> StatusLine {
        let d = desc.isEmpty ? "" : "(\(desc)) "
        return StatusLine(kind: .achievement, state: .impossible, text: RichText(runs: [Run(text: name, color: .impossible, italic: true), Run(text: " \(d) impossible", color: .impossible)]))
    }
    static func milestone(_ desc: RichText, _ yes: Bool) -> StatusLine {
        if yes {
            return StatusLine(kind: .milestone, state: .yes, text: desc.colored(.yes))
        } else {
            return StatusLine(kind: .milestone, state: .no, text: desc.colored(.no) + " -- need ")
        }
    }
    static func milestone(_ desc: String, _ yes: Bool) -> StatusLine {
        milestone(RichText(desc), yes)
    }
    static func point(_ pts: Int, _ desc: RichText, cumulative: Bool, _ yes: Bool) -> StatusLine {
        let c = cumulative ? " more" : ""
        if yes {
            return StatusLine(kind: .point, state: .yes, text: RichText(runs: [Run(text: "+\(pts)\(c)", color: .yes, bold: true), Run(text: " earned (", color: .yes)]) + desc.colored(.yes) + RichText(runs: [Run(text: ")", color: .yes)]))
        } else {
            return StatusLine(kind: .point, state: .no, text: RichText(runs: [Run(text: " (\(pts)\(c))", color: .no, bold: true), Run(text: " possible (", color: .no)]) + desc.colored(.no) + RichText(runs: [Run(text: ")", color: .no)]))
        }
    }
    static func point(_ pts: Int, _ desc: String, cumulative: Bool, _ yes: Bool) -> StatusLine {
        point(pts, RichText(desc), cumulative: cumulative, yes)
    }
    static func pointImpossible(_ pts: Int, _ desc: String) -> StatusLine {
        StatusLine(kind: .point, state: .impossible, text: RichText(runs: [Run(text: "+\(pts)", color: .impossible, bold: true), Run(text: " impossible (\(desc))", color: .impossible)]))
    }

    static func perfectionPct(_ pct: Double, _ max: Int, _ desc: String, _ yes: Bool, who: String = "") -> StatusLine {
        var places = 2
        let extra = who.isEmpty ? "" : (pct == 0 ? "" : " thanks to \(who)")
        if pct < 0.0001 || pct > 0.9999 { places = 0 }
        let pts = toFixed(Double(max) * pct, places)
        let prettyPct = toFixed(100 * pct, Swift.max(0, places - 1))
        if yes {
            return StatusLine(kind: .perfection, state: .yes, text: RichText(runs: [Run(text: "\(pts)%", color: .yes, bold: true), Run(text: " from completion of \(desc)\(extra)", color: .yes)])).progress(fraction: pct)
        } else {
            return StatusLine(kind: .perfection, state: .no, text: RichText(runs: [Run(text: " \(pts)%", color: .no, bold: true), Run(text: " (of \(max)% possible) from \(desc)\(extra) (\(prettyPct)%)", color: .no)])).progress(fraction: pct)
        }
    }
    static func perfectionNum(_ n: Int, _ max: Int, _ desc: String, _ yes: Bool, who: String = "") -> StatusLine {
        let extra = who.isEmpty ? "" : (n == 0 ? "" : " thanks to \(who)")
        if yes {
            return StatusLine(kind: .perfection, state: .yes, text: RichText(runs: [Run(text: "\(n)%", color: .yes, bold: true), Run(text: " from completion of \(desc)\(extra)", color: .yes)])).progress(fraction: 1)
        } else {
            return StatusLine(kind: .perfection, state: .no, text: RichText(runs: [Run(text: " \(n)%", color: .no, bold: true), Run(text: " (of \(max)% possible) from \(desc)\(extra) (\(n)/\(max))", color: .no)])).progress(fraction: Double(n) / Double(max))
        }
    }
    static func perfectionPctNum(_ pct: Double, _ max: Int, _ count: Int, _ desc: String, _ yes: Bool, who: String = "") -> StatusLine {
        var places = 2
        let extra = who.isEmpty ? "" : (pct == 0 ? "" : " thanks to \(who)")
        if pct < 0.0001 || pct > 0.9999 { places = 0 }
        let pts = toFixed(Double(max) * pct, places)
        let pretty = "\(Int((Double(count) * pct).rounded()))/\(count) or \(toFixed(100 * pct, Swift.max(0, places - 1)))%"
        if yes {
            return StatusLine(kind: .perfection, state: .yes, text: RichText(runs: [Run(text: "\(pts)%", color: .yes, bold: true), Run(text: " from completion of \(desc)\(extra)", color: .yes)])).progress(fraction: pct)
        } else {
            return StatusLine(kind: .perfection, state: .no, text: RichText(runs: [Run(text: " \(pts)%", color: .no, bold: true), Run(text: " (of \(max)% possible) from \(desc)\(extra) (\(pretty))", color: .no)])).progress(fraction: pct)
        }
    }
    static func perfectionBool(_ max: Int, _ desc: String, _ yes: Bool, who: String = "") -> StatusLine {
        let extra = who.isEmpty ? "" : " thanks to \(who)"
        if yes {
            return StatusLine(kind: .perfection, state: .yes, text: RichText(runs: [Run(text: "\(max)%", color: .yes, bold: true), Run(text: " from completion of \(desc)\(extra)", color: .yes)])).progress(fraction: 1)
        } else {
            return StatusLine(kind: .perfection, state: .no, text: RichText(runs: [Run(text: " 0%", color: .no, bold: true), Run(text: " (of \(max)% possible) from \(desc)", color: .no)])).progress(fraction: 0)
        }
    }

    /// getPTLink: "(PT: 45.2%)" cross reference to the Perfection Tracker.
    static func ptLink(pct: Double) -> RichText {
        let places = (pct == 1) ? 0 : 1
        return ptLink(toFixed(100 * pct, places) + "%")
    }
    static func ptLink(_ text: String) -> RichText {
        RichText(runs: [Run(text: " ("), Run(text: "PT: \(text)", color: .link), Run(text: ")")])
    }

    /// Small inline status marker like `[<span class="ms_yes">6♥</span>]`.
    static func marker(_ text: String, _ state: MarkState) -> RichText {
        let color: RunColor = state == .yes ? .yes : (state == .no ? .no : .impossible)
        return RichText(runs: [Run(text: "["), Run(text: text, color: color), Run(text: "]")])
    }
}

enum MarkState { case yes, no, imp }

// MARK: - Output blocks

/// One list entry; may nest (ul/ol inside li).
struct DetailItem: Identifiable {
    let id = UUID()
    var text: RichText
    var children: [DetailItem] = []
    var childrenOrdered = false
    /// Explicit `<li value=...>` number (used by the walnut list).
    var value: Int? = nil

    init(_ text: RichText, children: [DetailItem] = [], ordered: Bool = false, value: Int? = nil) {
        self.text = text
        self.children = children
        self.childrenOrdered = ordered
        self.value = value
    }
    init(_ text: String) { self.init(RichText(text)) }

    /// Sort key equivalent to the site's `.sort()` on raw HTML strings.
    var sortKey: String { text.plain }
}

// MARK: - Friendship rows (Social details)

struct FriendEvent: Identifiable {
    let id = UUID()
    var label: String        // "6♥" or "14.1♥"
    var state: MarkState
    var note: String         // extra text such as "(Jas & Vincent both)"
}

/// One villager in the Social details, both as structured data (for heart meters)
/// and as the site's original text line (for the plain-text export).
struct FriendRow: Identifiable {
    let id = UUID()
    var name: String
    var url: URL?
    var status: String
    var hearts: Int?         // nil for pseudo rows such as polyamory events
    var points: Int = 0
    var maxHearts: Int = 10
    /// Hearts at or above this index are locked until dating (datable villagers).
    var lockedFrom: Int? = nil
    var isChild = false
    var need: RichText = RichText()   // "MAX" / "need 416 more"
    var events: [FriendEvent] = []
    var text: RichText                 // legacy full line
    var eventLine: RichText? = nil     // legacy "Event(s): [...]" line
    var sortKey: String { text.plain }
}

struct FriendGroup {
    var title: String
    var rows: [FriendRow]
}

// MARK: - Calendar

struct CalendarEvent: Identifiable {
    enum Kind { case birthday, festival, other }
    let id = UUID()
    var kind: Kind
    var name: String
    var startDay: Int
    var endDay: Int
    var url: URL? = nil
    /// Birthday: gift given on the birthday this year. Festival: attended at least once.
    var done: Bool = false
    var note: String = ""
    var isMultiDay: Bool { endDay > startDay }
}

struct CalendarData {
    static let seasons = ["Spring", "Summer", "Fall", "Winter"]
    var season: String      // current season
    var day: Int
    var year: Int
    /// Events keyed by season name.
    var events: [String: [CalendarEvent]]

    func events(on day: Int, in season: String) -> [CalendarEvent] {
        (events[season] ?? []).filter { day >= $0.startDay && day <= $0.endDay }
    }
}

// MARK: - Overview numbers gathered while parsing

struct Overview {
    var money = 0
    var farmerLevel: Int? = nil
    var farmerTitle = ""
    var grandpaPoints: Int? = nil
    var grandpaCandlesLit = 0
    var grandpaCandlesNext = 0
    /// Adjusted perfection percentage (0...100), 1.5+ saves only.
    var perfectionPct: Double? = nil
    /// Collection-style goals for the host player: (title, section anchor, done, total).
    var collections: [(String, String, Int, Int)] = []
    /// Host player's experience in Farming, Fishing, Foraging, Mining, Combat.
    var skillXP: [Int] = []
    var currentSeason = ""
    /// Fish names the host has caught at least once.
    var fishCaught: Set<String> = []
    /// Display names of books read / powers held by the host.
    var booksRead: Set<String> = []
    var powersHave: Set<String> = []
}

enum Block: Identifiable {
    case result(RichText)                                   // <span class="result">  ◈ prefix
    case explain(RichText)                                  // <span class="explain"> * italic
    case note(RichText)                                     // <span class="result note">
    case warn(RichText)                                     // <span class="result warn">
    case achList([StatusLine])                              // <ul class="ach_list">
    case need(RichText, [DetailItem], ordered: Bool)        // <span class="need">Label<ol>...</ol></span>
    case list([DetailItem], ordered: Bool)                  // bare <ol class="outer">
    case friends([FriendGroup])                             // Social friendship progress
    case calendar(CalendarData)                             // season grid with birthdays and festivals
    case characters(CharactersData)                         // villager reference pages

    var id: String {
        switch self {
        case .result(let t): return "r" + t.plain
        case .explain(let t): return "e" + t.plain
        case .note(let t): return "n" + t.plain
        case .warn(let t): return "w" + t.plain
        case .achList(let a): return "a" + a.map(\.plain).joined()
        case .need(let t, let items, _): return "d" + t.plain + items.map(\.sortKey).joined()
        case .list(let items, _): return "l" + items.map(\.sortKey).joined()
        case .friends(let groups): return "f" + groups.flatMap { $0.rows.map(\.sortKey) }.joined()
        case .calendar(let c): return "c\(c.season)\(c.day)\(c.year)"
        case .characters(let c): return "p\(c.season)\(c.day)\(c.year)\(c.statuses.count)"
        }
    }
}

/// A summary/details pair: one `<div class="X_summary">` plus its `<div class="X_details">`.
struct Cell {
    var summary: [Block] = []
    var details: [Block] = []
}

struct Section: Identifiable {
    let id: String             // anchor
    let title: String
    /// Version when the section was introduced; "1.6" sections are the "new" group.
    let version: String
    var hasDetails = false
    /// Cells shown once, above any per-player table (e.g. Museum totals).
    var globalCells: [Cell] = []
    /// Per-player columns; `columns[p][row]`. Rendered transposed like `printTranspose`.
    var columns: [[Cell]] = []
    /// Cells shown after the player table (e.g. Junimo Kart leaderboard).
    var trailingCells: [Cell] = []

    var isNew: Bool { compareSemVer(version, "1.6") >= 0 }
    var rowCount: Int { columns.map(\.count).max() ?? 0 }

    init(title: String, version: String) {
        self.title = title
        self.version = version
        self.id = Section.makeAnchor(title)
    }

    static func makeAnchor(_ text: String) -> String {
        String(text.map { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "*" ? $0 : "_" })
    }
}

struct Report {
    var sections: [Section] = []
    var farmName = ""
    var playerNames: [String] = []     // host first, then farmhands
    var version = ""
    var sourceURL: URL?
    /// "Day 3 of Fall, Year 2 · 40 hr 52 min · v1.6.15" for the window subtitle.
    var summaryLine = ""
    var overview = Overview()
    var farmerName = ""
}

extension FriendGroup {
    /// Legacy list form used by the plain-text export.
    var asDetailItem: DetailItem {
        DetailItem(RichText(title), children: rows.map { r in
            DetailItem(r.text, children: r.eventLine.map { [DetailItem($0)] } ?? [])
        }, ordered: true)
    }
}
