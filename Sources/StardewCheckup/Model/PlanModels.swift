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
    /// When and where every fish can be caught (caught ones too), keyed by name.
    var catchInfo: [String: FishPlanRow] = [:]
    /// Fish that recipes, bundles and quests still ask for.
    var needs: [FishNeedRow] = []
}

/// One thing that still needs a fish: a recipe, a bundle slot or a quest.
struct FishNeed: Identifiable {
    enum Kind: String { case cooking = "Cooking", crafting = "Crafting", bundle = "Bundle", quest = "Quest" }
    let kind: Kind
    let purpose: String
    let count: Int
    var quality = 0
    var note: String? = nil
    let id = UUID()
    var qualityLabel: String? { [1: "Silver", 2: "Gold", 4: "Iridium"][quality] }
}

struct FishNeedRow: Identifiable {
    let fish: FishInfo
    var needs: [FishNeed] = []
    var have = 0
    var places = ""
    var caughtBefore = false
    var id: String { fish.name }
    /// Copies still to catch so every need can be met (needs are counted separately).
    var toCatch: Int {
        let total = needs.reduce(0) { $0 + $1.count }
        return max(0, total - have)
    }
    /// True when some need asks for a better quality than you own.
    var qualityShort = false
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

// MARK: Storage

/// One stack of items in a container.
struct StoredItem: Identifiable {
    let id = UUID()
    let name: String
    var count: Int
    var quality: Int
    /// Item kind for grouping: "Tool", "Weapon", "Ring", "Hat", "Boots", "Clothing", "Furniture" or "Item".
    var kind: String
    var itemId: String = ""
}

/// A chest, fridge, auto-grabber or the backpack, with what is inside.
struct StorageBox: Identifiable {
    let id: String
    var name: String            // "Chest", "Big Chest", "Stone Chest", "Fridge", "Auto-Grabber", "Backpack"...
    var location: String        // "Farm", "Shed", "Farmhouse"...
    var tile: (x: Int, y: Int)? = nil
    /// Player-chosen chest colour as RGB, nil for the default wood colour.
    var color: (r: Int, g: Int, b: Int)? = nil
    var capacity: Int = 36
    var items: [StoredItem] = []
    /// Directions from the farmhouse front door, when it can be worked out.
    var directions: String? = nil
    /// Farm building this container is inside, if any (its footprint is highlighted on the map).
    var building: String? = nil
    /// True when the tile is on the Farm map itself (drawn on the farm map).
    var onFarm = false
    var label: String { tile.map { "\(name), \(location) (\($0.x), \($0.y))" } ?? "\(name), \(location)" }
    var usedSlots: Int { items.count }
}

/// A building's footprint on the farm map.
struct FarmBuilding: Identifiable {
    let name: String
    let x: Int, y: Int, w: Int, h: Int
    var door: (x: Int, y: Int)? = nil
    var id: String { "\(name)-\(x)-\(y)" }
}

struct StorageData {
    var boxes: [StorageBox] = []
    var buildings: [FarmBuilding] = []
    var frontDoor: (x: Int, y: Int)? = nil
    var totalStacks: Int { boxes.reduce(0) { $0 + $1.items.count } }
}

// MARK: Golden Walnuts

/// One golden walnut source, with how many of its walnuts the host has found.
struct WalnutGuideRow: Identifiable {
    let id: String
    let name: String
    let area: String
    let total: Int
    let found: Int
    let hint: String
    var isDone: Bool { found >= total }
}

struct WalnutGuideData {
    var rows: [WalnutGuideRow]
    var found: Int
    var total: Int

    /// Areas in the order you reach them on the island.
    static let areas = ["Island South", "Island East (Jungle)", "Island North", "Field Office", "Island West", "Island Southeast (Cove)", "Volcano", "Anywhere on the island"]

    static func area(id: String, name: String) -> String {
        if id.hasPrefix("Volcano") || name.hasPrefix("Volcano") { return "Volcano" }
        if name.hasPrefix("Field Office") { return "Field Office" }
        if name.hasPrefix("Island Jungle") || id == "TreeNut" { return "Island East (Jungle)" }
        if name.hasPrefix("Island Cove") || id == "Darts" { return "Island Southeast (Cove)" }
        if name.hasPrefix("Island North") || id == "Island_N_BuriedTreasureNut" { return "Island North" }
        if name.hasPrefix("Island West") || name.hasPrefix("Island Farm") || id.hasPrefix("Island_W_")
            || ["Birdie", "TigerSlimeNut", "IslandFarming", "MusselStone"].contains(id) { return "Island West" }
        if name.hasPrefix("Island South") { return "Island South" }
        return "Anywhere on the island"
    }
}

// MARK: Scarecrows

/// A scarecrow (plain, deluxe or Rarecrow) standing somewhere.
struct PlacedScarecrow: Identifiable {
    let name: String            // "Scarecrow", "Deluxe Scarecrow", "Rarecrow #3"
    let location: String
    let tile: (x: Int, y: Int)
    /// Tiles it protects around itself (8, or 16 for the Deluxe Scarecrow).
    let radius: Int
    var directions: String? = nil
    var id: String { "\(location)-\(tile.x)-\(tile.y)" }
    var onFarm: Bool { location == "Farm" }
}

/// One of the eight Rarecrows and where the host's copies are.
struct RarecrowStatus: Identifiable {
    let number: Int
    let source: String
    var placed: [String] = []   // "Farm (63, 32)"
    var stored: [String] = []   // "Big Chest, Farm (76, 19)"
    var id: Int { number }
    var have: Bool { !placed.isEmpty || !stored.isEmpty }
}

struct ScarecrowData {
    var rarecrows: [RarecrowStatus] = []
    var scarecrows: [PlacedScarecrow] = []
    /// Crop tiles on the Farm map and whether a scarecrow covers them.
    var crops: [(x: Int, y: Int, protected: Bool)] = []
    var buildings: [FarmBuilding] = []
    var frontDoor: (x: Int, y: Int)? = nil
    var hasLetter = false
    var knowsDeluxe = false
    var deluxeCrafted = 0
    var unprotected: Int { crops.filter { !$0.protected }.count }
}

enum RarecrowData {
    /// Big craftable item id → Rarecrow number.
    static let numbers: [String: Int] = ["110": 1, "113": 2, "126": 3, "136": 4, "137": 5, "138": 6, "139": 7, "140": 8]
    /// Where each one comes from (shop data from Data/Shops and Data/MuseumRewards).
    static let sources: [Int: String] = [
        1: "Stardew Valley Fair (Fall 16): star token booth, 800 star tokens",
        2: "Spirit's Eve (Fall 27): Pierre's shop, 5,000g",
        3: "Casino in the Calico Desert (needs the Club Card from Mr. Qi): 10,000 Qi Coins",
        4: "Festival of Ice (Winter 8): the traveling merchant, 5,000g. The Traveling Cart also sells it sometimes in fall and winter",
        5: "Flower Dance (Spring 24): Pierre's shop, 2,500g",
        6: "The Dwarf's shop in the Mines, 2,500g",
        7: "Museum reward for donating 20 artifacts (collect it from Gunther's counter). If lost, the Night Market magic boat sells it again",
        8: "Museum reward for donating 40 items. If lost, the Night Market magic boat sells it again",
    ]
}
