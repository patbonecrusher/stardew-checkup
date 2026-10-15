import Foundation

/// How a villager reacts to a gift.
enum GiftTaste: Int, Comparable {
    case hate, dislike, neutral, like, love
    static func < (a: GiftTaste, b: GiftTaste) -> Bool { a.rawValue < b.rawValue }
}

/// An item the host owns somewhere (inventory, chests, fridges), summed across stacks.
struct OwnedItem {
    let name: String          // as stored in the save, e.g. "Ancient Fruit Wine"
    let tasteName: String     // name the gift tables use, e.g. "Wine"
    let category: Int
    let isArtifact: Bool
    var count = 0
    var bestQuality = 0
    /// Where it is kept → count there.
    var places: [String: Int] = [:]
    /// Quality → count, overall and in the backpack only (bundles ask for a minimum quality).
    var byQuality: [Int: Int] = [:]
    var inventoryByQuality: [Int: Int] = [:]

    func count(atLeast quality: Int) -> Int { byQuality.filter { $0.key >= quality }.values.reduce(0, +) }
    func inventoryCount(atLeast quality: Int) -> Int { inventoryByQuality.filter { $0.key >= quality }.values.reduce(0, +) }

    /// True when every copy is forage lying on the ground rather than something you hold.
    var onlyOnGround: Bool { !places.isEmpty && places.keys.allSatisfy { $0.hasPrefix("Ground") } }
    var placeSummary: String {
        places.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")
    }
}

/// Gift-taste rules: villager-specific items and categories (from `CharacterData`) layered over the
/// universal rules on the wiki's Friendship page. Save items carry the game's category code.
enum GiftTastes {
    // Category codes used in save files.
    static let fruit = -79, vegetable = -75, flower = -80, egg = -5, milk = -6, fish = -4
    static let artisan = -26, cooking = -7, gem = -2, mineral = -12, book = -102, trinket = -101
    static let monsterLoot = -28, metal = -15, ingredients = -25, syrup = -27, fishShop = -23
    /// `<preserve>` value → base item name used by the gift tables.
    static let preserveNames: [String: String] = ["Wine": "Wine", "Jelly": "Jelly", "Pickles": "Pickles", "Juice": "Juice", "Roe": "Roe",
                                                  "AgedRoe": "Aged Roe", "Honey": "Honey", "DriedFruit": "Dried Fruit",
                                                  "DriedMushroom": "Dried Mushrooms", "SmokedFish": "Smoked Fish", "Bait": "Bait"]

    static let universalLoves: Set<String> = ["Golden Pumpkin", "Magic Rock Candy", "Pearl", "Prismatic Shard", "Rabbit's Foot", "Stardrop Tea"]
    static let fruitTreeFruit: Set<String> = ["Apple", "Apricot", "Cherry", "Orange", "Peach", "Pomegranate"]
    static let universalLikeItems: Set<String> = fruitTreeFruit.union(["Life Elixir", "Maple Syrup", "Piña Colada", "Rainbow Shell", "Treasure Chest"])
    static let universalNeutralItems: Set<String> = ["Bread", "Coral", "Duck Feather", "Fried Egg", "Hops", "Mystic Syrup", "Nautilus Shell", "Roe",
                                                     "Squid Ink", "Sweet Gem Berry", "Tea Leaves", "Truffle", "Wheat", "Wool", "Quartz"]
    static let universalDislikeItems: Set<String> = ["Oil", "Unmilled Rice", "Price Catalogue", "Cave Carrot", "Spring Onion", "Void Egg", "Wheat Flour",
                                                     "Rice", "Vinegar", "Solar Essence", "Void Essence", "Sugar", "Qi Fruit", "Jack-O-Lantern"]
    static let universalHateItems: Set<String> = ["Void Mayonnaise", "Strange Bun", "Seafoam Pudding", "Poppy", "Carp", "Snail", "Sea Urchin",
                                                  "Seaweed", "Green Algae", "White Algae", "Red Mushroom", "Monster Musk", "Hay", "Sap",
                                                  "Copper Ore", "Iron Ore", "Radioactive Ore", "Radioactive Bar", "Dragon Tooth", "Golden Coconut"]
    static let foragedMinerals: Set<String> = ["Quartz", "Fire Quartz", "Frozen Tear", "Earth Crystal"]

    private struct CategoryRule {
        let taste: GiftTaste
        let categories: Set<Int>
        let exceptions: Set<String>
        let foragedOnly: Bool   // "All Foraged Minerals"
        let geodeOnly: Bool     // "All Geode Minerals"
        let artifacts: Bool     // "All Artifacts"
    }

    /// Per villager: normalized item names by taste, and category rules.
    private struct Profile {
        var items: [GiftTaste: Set<String>] = [:]
        var rules: [CategoryRule] = []
    }
    private static var profiles: [String: Profile] = [:]
    private static let lock = NSLock()

    private static func profile(for info: CharacterInfo) -> Profile {
        lock.lock(); defer { lock.unlock() }
        if let p = profiles[info.name] { return p }
        var p = Profile()
        let tiers: [(GiftTaste, CharacterInfo.GiftTier)] = [(.love, info.gifts.love), (.like, info.gifts.like), (.neutral, info.gifts.neutral),
                                                            (.dislike, info.gifts.dislike), (.hate, info.gifts.hate)]
        for (taste, tier) in tiers {
            p.items[taste] = Set(tier.items.map(normalize))
            for note in tier.notes {
                if let rule = parse(note, taste) { p.rules.append(rule) }
            }
        }
        profiles[info.name] = p
        return p
    }

    private static func parse(_ note: String, _ taste: GiftTaste) -> CategoryRule? {
        let n = note.trimmingCharacters(in: .whitespaces)
        guard n.hasPrefix("All "), !n.hasPrefix("All Universal") else { return nil }
        var head = n
        var exceptions: Set<String> = []
        if let open = n.firstIndex(of: "(") {
            head = String(n[..<open])
            var inner = String(n[n.index(after: open)...])
            if let close = inner.lastIndex(of: ")") { inner = String(inner[..<close]) }
            inner = inner.replacingOccurrences(of: "except for", with: "").replacingOccurrences(of: "except", with: "")
                .replacingOccurrences(of: "excluding", with: "")
            for part in inner.replacingOccurrences(of: " & ", with: ",").replacingOccurrences(of: " and ", with: ",").split(separator: ",") {
                let item = part.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".;:"))
                if !item.isEmpty { exceptions.insert(normalize(item)) }
            }
        }
        head = head.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
        var cats: Set<Int> = []
        var foraged = false, geode = false, artifacts = false
        switch head {
        case "All Fruit": cats = [fruit]
        case "All Vegetables": cats = [vegetable]
        case "All Flowers": cats = [flower]
        case "All Eggs": cats = [egg]
        case "All Milk": cats = [milk]
        case "All Fish": cats = [fish]
        case "All Artisan Goods": cats = [artisan]
        case "All Cooking", "All Cooked Dishes": cats = [cooking]
        case "All Gems": cats = [gem]
        case "All Books": cats = [book]
        case "All Artifacts": artifacts = true
        case "All Trinkets": cats = [trinket]
        case "All Foraged Minerals": cats = [mineral]; foraged = true
        case "All Geode Minerals": cats = [mineral]; geode = true
        default:
            // Long-form notes such as "All Cooking except for the fish dishes …" start the same way.
            if head.hasPrefix("All Cooking") { cats = [cooking] } else { return nil }
        }
        return CategoryRule(taste: taste, categories: cats, exceptions: exceptions, foragedOnly: foraged, geodeOnly: geode, artifacts: artifacts)
    }

    /// Lower-cased name without parentheticals, so "Strange Doll (green)" matches "Strange Doll".
    static func normalize(_ name: String) -> String {
        var s = name
        if let i = s.firstIndex(of: "(") { s = String(s[..<i]) }
        return s.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Resolution order mirrors the game: villager item → universal item → villager category → universal category.
    static func taste(of item: OwnedItem, for info: CharacterInfo) -> GiftTaste {
        let p = profile(for: info)
        let key = normalize(item.tasteName)
        for taste in [GiftTaste.love, .hate, .like, .dislike, .neutral] where p.items[taste]?.contains(key) ?? false {
            return taste
        }

        let exact = item.tasteName
        if universalLoves.contains(exact) { return .love }
        if universalHateItems.contains(exact) { return .hate }
        if universalLikeItems.contains(exact) { return .like }
        if universalDislikeItems.contains(exact) { return .dislike }
        if universalNeutralItems.contains(exact) { return .neutral }

        for rule in p.rules where !rule.exceptions.contains(key) {
            if rule.artifacts { if item.isArtifact { return rule.taste } else { continue } }
            guard rule.categories.contains(item.category) else { continue }
            if rule.foragedOnly && !foragedMinerals.contains(exact) { continue }
            if rule.geodeOnly && foragedMinerals.contains(exact) { continue }
            return rule.taste
        }

        if item.isArtifact { return .dislike }
        switch item.category {
        case artisan, cooking, flower, gem, vegetable: return .like
        case mineral: return foragedMinerals.contains(exact) ? .like : .dislike
        case fish, metal, ingredients, syrup, fishShop: return .dislike
        case monsterLoot: return .hate
        default: return .neutral
        }
    }
}

extension Checkup {
    /// Everything giftable the host owns: inventory, every placed chest (including auto-grabber and
    /// fridge contents) keyed by location.
    /// Owned items keyed by name, or by item id when `byID` (ids tell apart items sharing a
    /// name, such as white and brown eggs, and group every flavor of Jelly, Wine...).
    func collectOwnedItems(byID: Bool = false) -> [String: OwnedItem] {
        var owned: [String: OwnedItem] = [:]
        let giftable: Set<String> = ["Object", "ColoredObject"]
        func add(_ item: XNode, place: String) {
            let type = item.attr("\(info.nsPrefix):type") ?? (item.name == "Object" ? "Object" : "")
            guard giftable.contains(type) else { return }
            let name = item.childText("name")
            let stack = max(1, num(item.childText("stack")))
            guard !name.isEmpty, item.childText("isRecipe") != "true", item.childText("questItem") != "true" else { return }
            let category = Int(item.childText("category")) ?? 0
            let preserve = item.childText("preserve")
            let tasteName = GiftTastes.preserveNames[preserve] ?? name
            let isArtifact = item.childText("type") == "Arch"
            // Skip debris, machines, seeds, fertilizer, building materials, trash, crafting, bait and tackle.
            if category == -999 || category == -9 || name == "Artifact Spot" { return }
            let key = byID ? (item.childText("itemId").isEmpty ? item.childText("parentSheetIndex") : item.childText("itemId")) : name
            var entry = owned[key] ?? OwnedItem(name: name, tasteName: tasteName, category: category, isArtifact: isArtifact)
            entry.count += stack
            let quality = num(item.childText("quality"))
            entry.bestQuality = max(entry.bestQuality, quality)
            entry.places[place, default: 0] += stack
            entry.byQuality[quality, default: 0] += stack
            if place == "Inventory" { entry.inventoryByQuality[quality, default: 0] += stack }
            owned[key] = entry
        }
        for item in hostPlayer.find("items > Item") { add(item, place: "Inventory") }

        func locationName(of node: XNode) -> String {
            var cur: XNode? = node
            while let n = cur {
                if n.name == "GameLocation" || n.name == "indoors" {
                    let nm = n.childText("name")
                    if !nm.isEmpty { return nm }
                }
                cur = n.parent
            }
            return "Chest"
        }
        for chest in doc.find("[@\(info.nsPrefix):type='Chest']") {
            let items = chest.find("items > Item")
            guard !items.isEmpty else { continue }
            let kind = chest.childText("name")
            let place = (kind == "Chest" || kind.isEmpty ? "Chest" : kind) + " (\(locationName(of: chest)))"
            for item in items { add(item, place: place) }
        }
        for fridge in doc.find("fridge") where !fridge.find("items > Item").isEmpty {
            for item in fridge.find("items > Item") { add(item, place: "Fridge (\(locationName(of: fridge)))") }
        }
        // Forage spawned on the ground today is as good as owned: it only takes a walk.
        for loc in doc.find("locations > GameLocation") {
            let name = loc.childText("name")
            for obj in loc.find("objects > item > value > Object") where obj.childText("isSpawnedObject") == "true" {
                add(obj, place: "Ground (\(name))")
            }
        }
        return owned
    }

    /// Loved / liked items the host owns, for one villager, best first.
    func giftSuggestions(for info: CharacterInfo, owned: [String: OwnedItem]) -> GiftSuggestions {
        var loves: [GiftSuggestion] = []
        var likes: [GiftSuggestion] = []
        // Never suggest seeds, fertilizer, building materials, trash, crafting items, bait or tackle.
        let skipCategories: Set<Int> = [-74, -19, -16, -20, -8, -21, -22]
        for item in owned.values where !skipCategories.contains(item.category) {
            switch GiftTastes.taste(of: item, for: info) {
            case .love: loves.append(GiftSuggestion(item: item, taste: .love))
            case .like: likes.append(GiftSuggestion(item: item, taste: .like))
            default: break
            }
        }
        func order(_ a: GiftSuggestion, _ b: GiftSuggestion) -> Bool {
            if a.points() != b.points() { return a.points() > b.points() }
            if a.inInventory != b.inInventory { return a.inInventory }
            if a.onlyOnGround != b.onlyOnGround { return !a.onlyOnGround }
            if a.count != b.count { return a.count > b.count }
            return a.name < b.name
        }
        return GiftSuggestions(loves: loves.sorted(by: order), likes: likes.sorted(by: order))
    }
}
