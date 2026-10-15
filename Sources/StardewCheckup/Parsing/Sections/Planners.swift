import Foundation

extension Checkup {

    // MARK: Shared helpers

    /// Builds a planner item from what the host owns: matched by item name, by the base name of
    /// flavored goods ("Blueberry Jelly" counts as Jelly), or by category for "Egg (Any)" / "Milk (Any)".
    func planItem(_ name: String, id: String? = nil, need: Int = 1, quality: Int = 0) -> PlanItem {
        var item = PlanItem(name: name, need: need, quality: quality)
        let owned = hostOwnedItems
        let matches: [OwnedItem]
        if let id, let byID = hostOwnedByID[id] {
            matches = [byID]
        } else if id != nil && Int(id!) != nil && !name.hasSuffix("(Any)") {
            // Known numeric id and none owned: don't fall back to a name another item shares.
            matches = []
        } else if name == "Egg (Any)" {
            matches = owned.values.filter { $0.category == GiftTastes.egg }
        } else if name == "Milk (Any)" {
            matches = owned.values.filter { $0.category == GiftTastes.milk }
        } else if let exact = owned[name] {
            matches = [exact]
        } else {
            matches = owned.values.filter { $0.tasteName == name }
        }
        var places: [String: Int] = [:]
        for m in matches {
            item.have += m.count(atLeast: quality)
            item.inInventory += m.inventoryCount(atLeast: quality)
            for (k, v) in m.places { places[k, default: 0] += v }
        }
        // Places count every quality; `have` counts only copies good enough.
        item.places = places.sorted { $0.value > $1.value }.map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")
        if item.have < need { item.hint = itemHint(name) }
        return item
    }

    /// Short "where to get it" text for fish, crops and museum pieces.
    func itemHint(_ name: String) -> String? {
        if let f = FishData.all.first(where: { $0.name == name }) {
            var t = f.crabPot ? f.location : "\(f.location); \(f.seasons.count == 4 ? "all seasons" : f.seasons.joined(separator: ", ")); \(f.time)"
            if f.weather != .any { t += "; \(f.weather == .rain ? "rain" : "sun") only" }
            return t
        }
        if let c = CropData.info(name) {
            return "Grow: \(c.seasons.joined(separator: ", ")), \(c.days) days; \(c.seed): \(c.source)"
        }
        if let m = MuseumSourceData.sources[name] { return m }
        return nil
    }

    private var currentDate: (season: String, day: Int, year: Int) {
        (capitalize(doc.text("currentSeason")), num(doc.text("dayOfMonth")), num(doc.text("year")))
    }

    var hostIsRaining: Bool {
        if let item = doc.find("locationWeather > item").first(where: { $0.text("key > string") == "Default" }) ?? doc.find("locationWeather > item").first {
            return item.text("value > LocationWeather > isRaining > boolean") == "true"
        }
        return doc.text("isRaining") == "true"
    }

    // MARK: Bundles

    private static let bigCraftables: [String: String] = [
        "8": "Scarecrow", "9": "Lightning Rod", "10": "Bee House", "12": "Keg", "13": "Furnace", "15": "Preserves Jar",
        "16": "Cheese Press", "17": "Loom", "19": "Oil Maker", "20": "Recycling Machine", "21": "Crystalarium",
        "24": "Mayonnaise Machine", "25": "Seed Maker", "104": "Heater", "114": "Charcoal Kiln", "154": "Worm Bin",
        "156": "Slime Incubator", "158": "Slime Egg-Press", "163": "Cask", "165": "Auto-Grabber",
    ]
    private static let rings: [String: String] = ["516": "Small Glow Ring", "517": "Glow Ring", "518": "Magnet Ring", "519": "Small Magnet Ring", "520": "Slime Charmer Ring"]

    func buildBundlePlan() -> BundlePlanData {
        var data = BundlePlanData()
        let host = info.host
        data.isJoja = host.hasMail("JojaMember")
        let ccLoc = doc.first("locations > GameLocation\(info.typeIs("CommunityCenter"))")
        let roomNames = ["Pantry", "Crafts Room", "Fish Tank", "Boiler Room", "Vault", "Bulletin Board"]
        var roomDone: Set<String> = []
        for (r, b) in (ccLoc?.find("areasComplete > boolean") ?? []).enumerated() where b.text == "true" && r < roomNames.count {
            roomDone.insert(roomNames[r])
        }
        let jojaRooms: [(String, String)] = [("jojaBoilerRoom", "Boiler Room"), ("jojaCraftsRoom", "Crafts Room"), ("jojaPantry", "Pantry"), ("jojaFishTank", "Fish Tank"), ("jojaVault", "Vault")]
        for (mail, room) in jojaRooms where host.hasMail(mail) { roomDone.insert(room) }
        data.roomsDone = roomDone.count

        var filled: [String: Set<Int>] = [:]
        for item in ccLoc?.find("bundles > item") ?? [] {
            let id = item.text("key > int")
            var s: Set<Int> = []
            for (i, b) in item.find("ArrayOfBoolean > boolean").enumerated() where b.text == "true" { s.insert(i) }
            filled[id] = s
        }
        var raw: [(String, String)] = []
        if info.isBefore("1.5") {
            raw = CollectionData.defaultBundleData
        } else {
            for item in doc.find("bundleData > item") { raw.append((item.text("key > string"), item.text("value > string"))) }
        }
        let money = num(hostPlayer.childText("money"))
        for (k, v) in raw {
            let kf = k.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            let vf = v.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard kf.count >= 2, vf.count >= 5, roomNames.contains(kf[0]) else { continue }
            let id = kf[1]
            let done = filled[id] ?? []
            let fields = vf[2].split(separator: " ").map(String.init)
            var items: [PlanItem] = []
            var i = 0
            while i + 2 < fields.count {
                let slot = i / 3
                if fields[i] == "-1" {
                    var it = PlanItem(name: addCommas(num(fields[i + 1])) + "g", need: num(fields[i + 1]))
                    it.isMoney = true
                    it.have = money; it.inInventory = money
                    it.done = done.contains(slot)
                    items.append(it)
                } else {
                    let name = info.objects[fields[i]] ?? "Item \(fields[i])"
                    var it = planItem(name, id: fields[i], need: max(1, num(fields[i + 1])), quality: num(fields[i + 2]))
                    it.done = done.contains(slot)
                    items.append(it)
                }
                i += 3
            }
            let slots = vf[4].isEmpty ? items.count : num(vf[4])
            var row = BundlePlanRow(id: id, room: kf[0], name: vf[0], slots: slots, filled: done.count, items: items)
            let rw = vf[1].split(separator: " ").map(String.init)
            if rw.count >= 3 {
                let n = num(rw[2])
                let nm: String? = rw[0] == "BO" ? Checkup.bigCraftables[rw[1]] : rw[0] == "R" ? Checkup.rings[rw[1]] : info.objects[rw[1]]
                if let nm { row.reward = n > 1 ? "\(n) \(nm)" : nm }
            }
            let open = items.filter { !$0.done }
            let ready = open.filter(\.isReady).count
            let owned = open.filter { !$0.isMissing }.count
            if row.left == 0 || roomDone.contains(kf[0]) {
                row.state = .done
            } else if ready >= row.left {
                row.state = .ready
            } else if owned >= row.left {
                row.state = .fetch
            } else if owned > 0 {
                row.state = .partial
            } else {
                row.state = .missing
            }
            data.rows.append(row)
        }
        return data
    }

    // MARK: Fishing

    func buildFishPlan(caught: Set<String>) -> FishPlanData {
        let date = currentDate
        let host = info.host
        var data = FishPlanData(season: date.season, day: date.day, isRaining: hostIsRaining)
        let xp = host.xp(1)
        let levels = [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000]
        data.fishingLevel = levels.firstIndex { $0 > xp } ?? 10
        let island = host.hasMail("willyBoatFixed")
        let rustyKey = host.hasMail("HasRustyKey") || hostPlayer.childText("hasRustyKey") == "true"
        let bus = host.hasMail("ccVault") || host.hasMail("jojaVault")
        let woods = host.hasMail("beenToWoods")
        let swamp = host.hasMail("henchmanGone")
        let lair = host.hasMail("HasDarkTalisman") || host.hasMail("henchmanGone")
        var mine = num(hostPlayer.childText("deepestMineLevel"))
        if hostPlayer.childText("hasSkullKey") == "true" { mine = max(mine, 120) }

        /// Unmet requirement for one location, nil when you can fish there.
        func blocker(_ loc: String) -> String? {
            if loc.contains("Ginger Island") || loc.contains("Pirate Cove") || loc.contains("Volcano") {
                return island ? nil : "Ginger Island (repair Willy's boat)"
            }
            if loc.hasPrefix("Mines") {
                let floor = Int(loc.drop { !$0.isNumber }.prefix { $0.isNumber }) ?? 0
                return mine >= floor ? nil : "reach mine floor \(floor) (deepest: \(mine))"
            }
            if loc.contains("Mutant Bug Lair") { return lair ? nil : "Mutant Bug Lair (Dark Talisman quest)" }
            if loc.contains("Sewers") { return rustyKey ? nil : "Rusty Key (60 museum donations)" }
            if loc.contains("Desert") { return bus ? nil : "the Desert (repair the bus)" }
            if loc.contains("Witch's Swamp") { return swamp ? nil : "Witch's Swamp (Goblin Problem quest)" }
            if loc.contains("Secret Woods") { return woods ? nil : "Secret Woods (Steel Axe for the log)" }
            return nil
        }
        let seasons = CalendarData.seasons
        let si = seasons.firstIndex(of: date.season) ?? 0
        // Qi's "Extended Family" order (QiChallenge7) is the only time its legendaries bite.
        let extendedFamily = doc.find("specialOrders > SpecialOrder").contains { $0.childText("questKey") == "QiChallenge7" }
        for fish in FishData.all {
            if fish.note.contains("Extended Family") && !extendedFamily { continue }
            data.total += 1
            if caught.contains(fish.name) { data.caught += 1; continue }
            var row = FishPlanRow(fish: fish, group: .laterSeason)
            if fish.crabPot {
                row.group = .crabPot
                data.rows.append(row)
                continue
            }
            let locs = fish.location.components(separatedBy: ", ")
            let blocks = locs.map(blocker)
            if blocks.allSatisfy({ $0 != nil }) { row.blockers = Array(Set(blocks.compactMap { $0 })).sorted() }
            if fish.minLevel > data.fishingLevel { row.blockers.append("Fishing level \(fish.minLevel) (you have \(data.fishingLevel))") }
            let islandAllYear = island && fish.note.contains("All Seasons on Ginger Island")
            var inSeason = fish.seasons.contains(date.season) || islandAllYear
            if fish.location.contains("Night Market") {
                inSeason = date.season == "Winter" && (15...17).contains(date.day)
                row.nextSeason = "Winter 15–17"
            } else if !inSeason {
                row.nextSeason = (1...3).map { seasons[(si + $0) % 4] }.first { fish.seasons.contains($0) } ?? ""
            }
            let weatherOK = fish.weather == .any || (fish.weather == .rain) == data.isRaining
            if !row.blockers.isEmpty {
                row.group = .blocked
            } else if inSeason {
                row.group = weatherOK ? .today : .otherWeather
            } else {
                row.group = .laterSeason
            }
            data.rows.append(row)
        }
        return data
    }

    // MARK: Crafting

    func buildCraftingPlan() -> CookPlanData {
        var known: Set<String> = []
        var crafted: [String: Int] = [:]
        for item in hostPlayer.find("craftingRecipes > item") {
            var id = item.text("key > string")
            if id == "Oil Of Garlic" { id = "Oil of Garlic" }
            known.insert(id)
            let n = num(item.text("value > int"))
            if n > 0 { crafted[id] = n }
        }
        let valid = Set(craftingRecipeNames())
        let owned = hostOwnedItems
        let craftables = Set(CraftingData.recipes.map(\.name))
        var data = CookPlanData()
        for recipe in CraftingData.recipes where valid.contains(recipe.name) {
            var row = CookPlanRow(name: recipe.name, state: .learn, known: known.contains(recipe.name), source: recipe.source)
            row.timesCooked = crafted[recipe.name] ?? 0
            for (name, count) in recipe.ingredients {
                var ing = CookIngredient(name: name, need: count)
                ing.isDish = craftables.contains(name)
                // Exact name, or any flavor of a flavored good (Honey takes Wild Honey, Tulip Honey...).
                let matches = owned[name].map { [$0] } ?? owned.values.filter { $0.tasteName == name || (name == "Honey" && $0.name.hasSuffix("Honey")) }
                var places: [String: Int] = [:]
                for m in matches {
                    ing.have += m.count
                    for (k, v) in m.places { places[k, default: 0] += v }
                }
                ing.inReach = places["Inventory"] ?? 0
                ing.places = places.sorted { $0.value > $1.value }.map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")
                row.ingredients.append(ing)
            }
            let allOwned = row.ingredients.allSatisfy { !$0.isMissing }
            let allInReach = row.ingredients.allSatisfy { $0.inReach >= $0.need }
            if row.timesCooked > 0 { row.state = .cooked }
            else if !row.known { row.state = .learn }
            else if allInReach { row.state = .cookNow }
            else if allOwned { row.state = .fetch }
            else { row.state = .missing }
            data.rows.append(row)
        }
        return data
    }

    // MARK: Museum

    func buildMuseumPlan(donated: Set<String>) -> MuseumPlanData {
        var found: Set<String> = []
        for item in hostPlayer.find("archaeologyFound > item") where num(item.find("value > ArrayOfInt > int").first?.text) > 0 {
            found.insert(item.first("key")?.allChildren.first?.text ?? "")
        }
        for item in hostPlayer.find("mineralsFound > item") where num(item.text("value > int")) > 0 {
            found.insert(item.first("key")?.allChildren.first?.text ?? "")
        }
        var data = MuseumPlanData()
        let all = CollectionData.artifacts.map { ($0.0, $0.1, true) } + CollectionData.minerals.map { ($0.0, $0.1, false) }
        data.total = all.count
        for (id, name, isArtifact) in all {
            if donated.contains(id) { data.donated += 1; continue }
            var row = MuseumPlanRow(name: name, isArtifact: isArtifact, state: .notFound)
            row.hint = MuseumSourceData.sources[name] ?? ""
            if let o = hostOwnedItems[name] {
                row.state = .donateNow
                row.places = o.placeSummary
            } else if found.contains(id) {
                row.state = .lost
            }
            data.rows.append(row)
        }
        return data
    }

    // MARK: Shipping

    func buildShipPlan(items: [(String, String)], shipped: [String: Int]) -> ShipPlanData {
        var data = ShipPlanData(total: items.count)
        for (id, name) in items {
            if shipped[name] != nil { data.shipped += 1; continue }
            let it = planItem(name, id: id)
            data.rows.append(ShipPlanRow(item: it, state: it.have > 0 ? .shipNow : .notOwned))
        }
        return data
    }

    func buildCropPlan(shipped: [String: Int]) -> CropPlanData {
        let date = currentDate
        var data = CropPlanData(season: date.season, day: date.day)
        if let top = shipped.max(by: { $0.value < $1.value }) { data.topCrop = top.key; data.topShipped = top.value }
        let seasons = CalendarData.seasons
        let si = seasons.firstIndex(of: date.season) ?? 0
        for (_, name) in CollectionData.polyCrops {
            var row = CropPlanRow(name: name, shipped: shipped[name] ?? 0)
            if let o = hostOwnedItems[name] { row.owned = o.count; row.ownedPlaces = o.placeSummary }
            if let c = CropData.info(name) {
                row.seed = c.seed; row.seasons = c.seasons; row.days = c.days; row.regrow = c.regrow; row.seedSource = c.source
                row.seedsOwned = hostOwnedItems[c.seed]?.count ?? 0
                if c.seasons.contains(date.season) {
                    // Growing days left: rest of this season plus any following seasons the crop also grows in.
                    var daysLeft = 28 - date.day
                    var next = si + 1
                    while next < si + 4, c.seasons.contains(seasons[next % 4]) { daysLeft += 28; next += 1 }
                    if c.days <= daysLeft { row.harvestDay = date.day + c.days }
                }
            }
            if row.shipped >= 15 { row.state = .done }
            else if row.owned > 0 { row.state = .shipNow }
            else if row.harvestDay != nil { row.state = .plantNow }
            else { row.state = .laterSeason }
            data.rows.append(row)
        }
        return data
    }

    // MARK: Monster Hunting

    static let monsterGoalInfo: [String: (where: String, reward: String, mail: String)] = [
        "Slimes": ("Every floor of the Mines and the Skull Cavern, the Secret Woods; slimes in a Slime Hutch count too", "Slime Charmer Ring", "Gil_Slimes"),
        "Void Spirits": ("Mines floors 80–119 (Shadow Brutes and Shamans); Shadow Snipers in the dangerous Mines", "Savage Ring", "Gil_Shadows"),
        "Bats": ("Mines floors 31–39 (Bats), 41–79 (Frost Bats), 81–119 (Lava Bats); Iridium Bats in the Skull Cavern", "Vampire Ring", "Gil_Bats"),
        "Skeletons": ("Mines floors 71–79; Skeleton Mages in the dangerous Mines", "Skeleton Mask", "Gil_Skeletons"),
        "Cave Insects": ("Mines floors 1–39 (Bugs, Grubs, Cave Flies) and 50–79; the Mutant Bug Lair", "Insect Head", "Gil_Insects"),
        "Duggies": ("Mines floors 6–39, in patches of dirt; Magma Duggies in the Volcano", "Hard Hat", "Gil_Duggy"),
        "Dust Sprites": ("Mines floors 41–79, often in big swarms on dark floors", "Burglar's Ring", "Gil_DustSpirits"),
        "Rock Crabs": ("Mines floors 1–29 (Rock Crabs), 81–119 (Lava Crabs); Iridium Crabs in the Skull Cavern", "Crabshell Ring", "Gil_Crabs"),
        "Mummies": ("Skull Cavern; they only stay down after a bomb", "Arcane Hat", "Gil_Mummies"),
        "Pepper Rex": ("Skull Cavern, more common on deeper floors", "Knight's Helmet", "Gil_Dinos"),
        "Serpents": ("Skull Cavern; Royal Serpents on deeper floors", "Napalm Ring", "Gil_Serpents"),
        "Flame Spirits": ("Volcano Dungeon on Ginger Island (Magma Sprites and Sparkers)", "Marlon's phone number", "Gil_Telephone"),
    ]
}
