import Foundation

/// Per-player data gathered once up front (port of `populateData`).
final class PlayerData {
    var name = ""
    var umid = "0"
    var stats: [String: String] = [:]
    var mailReceived: Set<String> = []
    var eventsSeen: Set<String> = []
    var experiencePoints: [Int] = []
    var chestConsumedMineLevels: [Int: String] = [:]
    var maxStamina = 0

    func stat(_ key: String) -> Int { num(stats[key]) }
    func hasStat(_ key: String) -> Bool { stats[key] != nil }
    func hasMail(_ key: String) -> Bool { mailReceived.contains(key) }
    func hasEvent(_ key: String) -> Bool { eventsSeen.contains(key) }
    func hasEvent(_ key: Int) -> Bool { eventsSeen.contains(String(key)) }
    func xp(_ i: Int) -> Int { i < experiencePoints.count ? experiencePoints[i] : 0 }
}

struct CountTotal {
    var count: Int
    var total: Int
    var ratio: Double { total == 0 ? 0 : Double(count) / Double(total) }
}

/// Mirrors `saveInfo.perfectionTracker`.
final class PerfectionTracker {
    var goldClock = false
    var earthObelisk = false
    var waterObelisk = false
    var desertObelisk = false
    var islandObelisk = false
    var walnuts = CountTotal(count: 0, total: 130)

    /// Per-player count/total goals keyed by umid then by goal name
    /// ("Shipping", "Cooking", "Crafting", "Fishing", "Great Friends", "Skills").
    var perPlayer: [String: [String: CountTotal]] = [:]
    /// Per-player boolean goals ("Monsters", "Stardrops").
    var perPlayerBool: [String: [String: Bool]] = [:]

    func set(_ umid: String, _ key: String, _ v: CountTotal) {
        perPlayer[umid, default: [:]][key] = v
    }
    func set(_ umid: String, _ key: String, _ v: Bool) {
        perPlayerBool[umid, default: [:]][key] = v
    }
    func get(_ umid: String, _ key: String) -> CountTotal {
        perPlayer[umid]?[key] ?? CountTotal(count: 0, total: 1)
    }
    func getBool(_ umid: String, _ key: String) -> Bool {
        perPlayerBool[umid]?[key] ?? false
    }
    func setBuilding(_ type: String) {
        switch type {
        case "Gold Clock": goldClock = true
        case "Earth Obelisk": earthObelisk = true
        case "Water Obelisk": waterObelisk = true
        case "Desert Obelisk": desertObelisk = true
        case "Island Obelisk": islandObelisk = true
        default: break
        }
    }
}

enum OutputPref: String, CaseIterable, Identifiable {
    case showAll = "show_all"
    case hideDetails = "hide_details"
    case hideAll = "hide_all"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .showAll: return "Show summary and details"
        case .hideDetails: return "Show summary but hide details"
        case .hideAll: return "Hide summary and details"
        }
    }
    var showsSummary: Bool { self != .hideAll }
    var showsDetails: Bool { self == .showAll }
}

/// Port of the `saveInfo` structure threaded through every parse function.
final class SaveInfo {
    var version = "1.2"
    var versionLabel = ""
    var nsPrefix = "xsi"
    var farmerId = "0"
    var farmName = ""
    var numPlayers = 1
    /// Ordered list of (umid, name); host first.
    var playerOrder: [String] = []
    var players: [String: String] = [:]
    var data: [String: PlayerData] = [:]
    var children: [String: [String]] = [:]
    var partners: [String: String] = [:]
    var objects: [String: String] = ObjectData.objects
    let perfection = PerfectionTracker()
    var overview = Overview()

    func isAtLeast(_ v: String) -> Bool { compareSemVer(version, v) >= 0 }
    func isBefore(_ v: String) -> Bool { compareSemVer(version, v) < 0 }

    var host: PlayerData { data[farmerId]! }

    func playerName(_ umid: String) -> String { players[umid] ?? "" }

    /// Multiplayer-aware subject used by several global sections.
    var intro: String {
        numPlayers > 1 ? "Inhabitants of \(farmName) Farm have" : "\(playerName(farmerId)) has"
    }

    /// Selector that matches a type attribute, e.g. `[@xsi:type='Farm']`.
    func typeIs(_ type: String) -> String { "[@\(nsPrefix):type='\(type)']" }

    /// The umid for a player element (host id for 1.2 saves which have none).
    func umid(of player: XNode) -> String {
        isAtLeast("1.3") ? player.childText("UniqueMultiplayerID") : farmerId
    }

    /// Farmhand elements (location changed in 1.6).
    func farmhands(in doc: XNode) -> [XNode] {
        let selector = isAtLeast("1.6") ? "farmhands > Farmer" : "farmhand"
        return doc.find(selector).filter(SaveInfo.isValidFarmhand)
    }

    static func isValidFarmhand(_ player: XNode) -> Bool {
        !(player.childText("userID").isEmpty && player.childText("name").isEmpty)
    }
}
