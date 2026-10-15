import Foundation

// Data for the Planner tabs shown on collection pages (Bundles, Fishing, Crafting, Museum,
// Shipping, Monster Hunting). Each is built for the host player while parsing.

/// An item a planner asks for, with what the host owns of it.
struct PlanItem: Identifiable {
    let id = UUID()
    let name: String
    var need = 1
    /// Minimum quality accepted (0 normal, 1 silver, 2 gold, 4 iridium).
    var quality = 0
    /// Owned anywhere at that quality or better.
    var have = 0
    /// Of those, how many are in the backpack.
    var inInventory = 0
    var places = ""
    /// Already handed in (bundle slot filled).
    var done = false
    /// Where to get it, when it is not owned.
    var hint: String? = nil
    var isMoney = false
    var isMissing: Bool { !done && have < need }
    var isReady: Bool { !done && inInventory >= need }
    var qualityLabel: String? { [1: "Silver", 2: "Gold", 4: "Iridium"][quality] }
}

// MARK: Bundles

struct BundlePlanRow: Identifiable {
    enum State: Int, CaseIterable {
        case ready, fetch, partial, missing, done
    }
    let id: String
    let room: String
    let name: String
    /// Items the bundle takes, and how many are already in.
    var slots: Int
    var filled: Int
    var items: [PlanItem] = []
    var reward = ""
    var state: State = .missing
    var left: Int { max(0, slots - filled) }
    /// Open slots you could fill with what you own.
    var ownedForOpen: Int { items.filter { !$0.done && !$0.isMissing }.count }
}

struct BundlePlanData {
    var rows: [BundlePlanRow] = []
    var isJoja = false
    var roomsDone = 0
    var roomsTotal = 6
}

// MARK: Fishing

struct FishPlanRow: Identifiable {
    enum Group: Int, CaseIterable {
        case today, otherWeather, blocked, laterSeason, crabPot
    }
    let fish: FishInfo
    var group: Group
    /// Things still standing between you and this fish (unmet requirements).
    var blockers: [String] = []
    /// Seasons it can next be caught, starting from the current one.
    var nextSeason = ""
    var id: String { fish.name }
}

struct FishPlanData {
    var season = ""
    var day = 1
    var isRaining = false
    var fishingLevel = 0
    var rows: [FishPlanRow] = []
    var caught = 0
    var total = 0
}

// MARK: Museum

struct MuseumPlanRow: Identifiable {
    enum State: Int, CaseIterable { case donateNow, lost, notFound }
    let name: String
    let isArtifact: Bool
    var state: State
    var places = ""
    var hint = ""
    var id: String { name }
}

struct MuseumPlanData {
    var rows: [MuseumPlanRow] = []
    var donated = 0
    var total = 0
}

// MARK: Shipping

struct ShipPlanRow: Identifiable {
    enum State: Int, CaseIterable { case shipNow, notOwned }
    let item: PlanItem
    var state: State
    var id: UUID { item.id }
}

struct ShipPlanData {
    var rows: [ShipPlanRow] = []
    var shipped = 0
    var total = 0
}

struct CropPlanRow: Identifiable {
    enum State: Int, CaseIterable { case shipNow, plantNow, laterSeason, done }
    let name: String
    var shipped = 0
    var owned = 0
    var ownedPlaces = ""
    var seedsOwned = 0
    var seed = ""
    var seasons: [String] = []
    var days = 0
    var regrow = 0
    var seedSource = ""
    /// Planted today, when the first harvest would be (nil if it won't make it before the season ends).
    var harvestDay: Int? = nil
    var state: State = .laterSeason
    var id: String { name }
    var left: Int { max(0, 15 - shipped) }
}

struct CropPlanData {
    var rows: [CropPlanRow] = []
    var season = ""
    var day = 1
    var topCrop = ""
    var topShipped = 0
}

// MARK: Monster Hunting

struct MonsterPlanRow: Identifiable {
    let goal: String
    var target: Int
    var killed: Int
    var monsters: [String]
    var whereToFind: String
    var reward: String
    var claimed: Bool
    var id: String { goal }
    var left: Int { max(0, target - killed) }
    var isDone: Bool { killed >= target }
}

struct MonsterPlanData {
    var rows: [MonsterPlanRow] = []
    var mineLevel = 0
    var skullLevel = 0
}
