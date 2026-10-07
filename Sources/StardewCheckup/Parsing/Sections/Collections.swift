import Foundation

/// Ordered dictionary helper so detail lists iterate in the site's insertion order.
struct OrderedMap {
    private(set) var keys: [String] = []
    private var dict: [String: String] = [:]

    init(_ pairs: [(String, String)] = []) {
        for (k, v) in pairs { self[k] = v }
    }
    subscript(_ key: String) -> String? {
        get { dict[key] }
        set {
            if dict[key] == nil, newValue != nil { keys.append(key) }
            dict[key] = newValue
        }
    }
    var count: Int { keys.count }
    var pairs: [(String, String)] { keys.map { ($0, dict[$0]!) } }
    func has(_ key: String) -> Bool { dict[key] != nil }
}

extension Checkup {

    // MARK: Cooking

    func parseCooking() -> Section {
        var recipes = OrderedMap(CollectionData.cookingRecipes)
        let translate: [String: String] = [
            "Cheese Cauli.": "Cheese Cauliflower", "Cookies": "Cookie", "Cran. Sauce": "Cranberry Sauce",
            "Dish o' The Sea": "Dish O' The Sea", "Eggplant Parm.": "Eggplant Parmesan", "Vegetable Stew": "Vegetable Medley",
        ]
        if info.isAtLeast("1.4") {
            recipes["733"] = "Shrimp Cocktail"; recipes["253"] = "Triple Shot Espresso"; recipes["265"] = "Seafoam Pudding"
        }
        if info.isAtLeast("1.5") {
            recipes["903"] = "Ginger Ale"; recipes["904"] = "Banana Pudding"; recipes["905"] = "Mango Sticky Rice"
            recipes["906"] = "Poi"; recipes["907"] = "Tropical Curry"; recipes["921"] = "Squid Ink Ravioli"
        }
        if info.isAtLeast("1.6") {
            recipes["MossSoup"] = "Moss Soup"
        }
        var reverse: [String: String] = [:]
        for (id, name) in recipes.pairs { reverse[name] = id }

        return playerSection(title: "Cooking", version: "1.2") { player, meta in
            // cookingRecipes is keyed by name, recipesCooked by object ID; some names differ.
            let recipeCount = recipes.count
            var known: [String: Int] = [:]
            var knownCount = 0
            var crafted: [String: Int] = [:]
            var craftCount = 0
            var modKnown = 0
            var modCraft = 0
            let umid = info.umid(of: player)
            let name = playerName(player)

            for item in player.find("cookingRecipes > item") {
                var id = item.text("key > string")
                let n = num(item.text("value > int"))
                if let t = translate[id] { id = t }
                if reverse[id] != nil {
                    known[id] = n
                    knownCount += 1
                } else {
                    modKnown += 1
                }
            }
            for item in player.find("recipesCooked > item") {
                let id = item.first("key")?.allChildren.first?.text ?? ""
                let n = num(item.text("value > int"))
                if let r = recipes[id] {
                    if n > 0 { crafted[r] = n; craftCount += 1 }
                } else if n > 0 {
                    modCraft += 1
                }
            }
            var ptPct = RichText()
            if info.isAtLeast("1.5") {
                info.perfection.set(umid, "Cooking", CountTotal(count: craftCount, total: recipeCount))
                ptPct = Fmt.ptLink(pct: Double(craftCount) / Double(recipeCount))
            }
            var cell = Cell()
            cell.summary.append(.result("\(name) has cooked \(craftCount) and knows \(knownCount) of \(recipeCount)\(modKnown > 0 ? " base game" : "") recipes.".rt + ptPct))
            if modKnown > 0 {
                cell.summary.append(.note(RichText("\(name) has also cooked \(modCraft) and knows \(modKnown) unrecognized (probably mod) recipes.")))
            }
            let total = craftCount + modCraft
            cell.summary.append(.achList([
                (total >= 10 ? Fmt.achieve("Cook", "cook 10 different recipes", true) : Fmt.achieve("Cook", "cook 10 different recipes", false) + "\(10 - total) more").progress(total, 10),
                (total >= 25 ? Fmt.achieve("Sous Chef", "cook 25 different recipes", true) : Fmt.achieve("Sous Chef", "cook 25 different recipes", false) + "\(25 - total) more").progress(total, 25),
                (total >= recipeCount + modKnown ? Fmt.achieve("Gourmet Chef", "cook every recipe", true)
                    : Fmt.achieve("Gourmet Chef", "cook every recipe", false) + "\(modKnown > 0 ? "at least " : "")\(recipeCount + modKnown - total) more").progress(total, recipeCount + modKnown),
            ]))
            if total < recipeCount + modKnown {
                var needK: [DetailItem] = []
                var needC: [DetailItem] = []
                for (_, r) in recipes.pairs {
                    if known[r] == nil {
                        needK.append(DetailItem(wikify(r)))
                    } else if crafted[r] == nil {
                        needC.append(DetailItem(wikify(r)))
                    }
                }
                meta.hasDetails = true
                var groups: [DetailItem] = []
                if !needC.isEmpty { groups.append(DetailItem(RichText("Known Recipes"), children: Checkup.sortedItems(needC), ordered: true)) }
                if !needK.isEmpty { groups.append(DetailItem(RichText("Unknown Recipes"), children: Checkup.sortedItems(needK), ordered: true)) }
                if modKnown > 0 {
                    groups.append(DetailItem(modCraft >= modKnown ? "Possibly additional mod recipes" : "Plus at least \(modKnown - modCraft) mod recipes"))
                }
                cell.details.append(.need(RichText("Left to cook:"), groups, ordered: false))
            }
            return [cell]
        }
    }

    // MARK: Crafting

    func parseCrafting() -> Section {
        var recipes = CollectionData.craftingRecipes
        let translate = ["Oil Of Garlic": "Oil of Garlic"]
        if info.isAtLeast("1.3") {
            recipes += ["Wood Sign", "Stone Sign", "Garden Pot"]
        }
        if info.isAtLeast("1.4") {
            recipes += ["Brick Floor", "Grass Starter", "Deluxe Scarecrow", "Mini-Jukebox", "Tree Fertilizer", "Tea Sapling", "Warp Totem: Desert"]
        }
        if info.isAtLeast("1.5") {
            recipes += ["Rustic Plank Floor", "Stone Walkway Floor", "Fairy Dust", "Bug Steak", "Dark Sign", "Quality Bobber", "Stone Chest", "Monster Musk", "Mini-Obelisk", "Farm Computer", "Ostrich Incubator", "Geode Crusher", "Fiber Seeds", "Solar Panel", "Bone Mill", "Warp Totem: Island", "Thorns Ring", "Glowstone Ring", "Heavy Tapper", "Hopper", "Magic Bait", "Hyper Speed-Gro", "Deluxe Fertilizer", "Deluxe Retaining Soil", "Cookout Kit"]
        }
        if info.isAtLeast("1.6") {
            recipes += ["Anvil", "Bait Maker", "Big Chest", "Big Stone Chest", "Blue Grass Starter", "Challenge Bait", "Dehydrator", "Deluxe Bait", "Deluxe Worm Bin", "Fish Smoker", "Heavy Furnace", "Mini-Forge", "Mushroom Log", "Mystic Tree Seed", "Sonar Bobber", "Statue Of Blessings", "Statue Of The Dwarf King", "Tent Kit", "Text Sign", "Treasure Totem"]
        }
        let recipeSet = Set(recipes)

        return playerSection(title: "Crafting", version: "1.2") { player, meta in
            let recipeCount = recipes.count
            var known: [String: Int] = [:]
            var knownCount = 0
            var craftCount = 0
            var needC: [DetailItem] = []
            var modKnown = 0
            var modCraft = 0
            let umid = info.umid(of: player)
            let name = playerName(player)

            for item in player.find("craftingRecipes > item") {
                var id = item.text("key > string")
                let n = num(item.text("value > int"))
                if let t = translate[id] { id = t }
                if id == "Wedding Ring" { continue }
                if !recipeSet.contains(id) {
                    modKnown += 1
                    if n > 0 { modCraft += 1 }
                    continue
                }
                known[id] = n
                knownCount += 1
                if n > 0 {
                    craftCount += 1
                } else {
                    needC.append(DetailItem(wikify(id)))
                }
            }
            var ptPct = RichText()
            if info.isAtLeast("1.5") {
                info.perfection.set(umid, "Crafting", CountTotal(count: craftCount, total: recipeCount))
                ptPct = Fmt.ptLink(pct: Double(craftCount) / Double(recipeCount))
            }
            var cell = Cell()
            cell.summary.append(.result("\(name) has crafted \(craftCount) and knows \(knownCount) of \(recipeCount) base game recipes.".rt + ptPct))
            if modKnown > 0 {
                cell.summary.append(.note(RichText("\(name) has also crafted \(modCraft) and knows \(modKnown) unrecognized (probably mod) recipes.")))
            }
            let total = craftCount + modCraft
            cell.summary.append(.achList([
                (total >= 15 ? Fmt.achieve("D.I.Y.", "craft 15 different items", true) : Fmt.achieve("D.I.Y.", "craft 15 different items", false) + "\(15 - total) more").progress(total, 15),
                (total >= 30 ? Fmt.achieve("Artisan", "craft 30 different items", true) : Fmt.achieve("Artisan", "craft 30 different items", false) + "\(30 - total) more").progress(total, 30),
                (total >= recipeCount + modKnown ? Fmt.achieve("Craft Master", "craft every item", true)
                    : Fmt.achieve("Craft Master", "craft every item", false) + "\(modKnown > 0 ? "at least " : "")\(recipeCount + modKnown - total) more").progress(total, recipeCount + modKnown),
            ]))
            if total < recipeCount + modKnown {
                meta.hasDetails = true
                var groups: [DetailItem] = []
                if !needC.isEmpty { groups.append(DetailItem(RichText("Known Recipes"), children: Checkup.sortedItems(needC), ordered: true)) }
                if knownCount < recipeCount {
                    let needK = recipes.filter { known[$0] == nil }.map { DetailItem(wikify($0)) }
                    groups.append(DetailItem(RichText("Unknown Recipes"), children: Checkup.sortedItems(needK), ordered: true))
                }
                if modKnown > 0 {
                    groups.append(DetailItem(modCraft >= modKnown ? "Possibly additional mod recipes" : "Plus at least \(modKnown - modCraft) mod recipes"))
                }
                cell.details.append(.need(RichText("Left to craft:"), groups, ordered: false))
            }
            return [cell]
        }
    }

    // MARK: Fishing

    func parseFishing() -> Section {
        var recipes = OrderedMap(CollectionData.fish)
        var bobber = OrderedMap()
        if info.isAtLeast("1.3") {
            recipes["798"] = "Midnight Squid"; recipes["799"] = "Spook Fish"; recipes["800"] = "Blobfish"
        }
        if info.isAtLeast("1.4") {
            recipes["269"] = "Midnight Carp"; recipes["267"] = "Flounder"
        }
        if info.isAtLeast("1.5") {
            recipes["836"] = "Stingray"; recipes["837"] = "Lionfish"; recipes["838"] = "Blue Discus"
        }
        if info.isAtLeast("1.6") {
            recipes["Goby"] = "Goby"; recipes["CaveJelly"] = "Cave Jelly"; recipes["RiverJelly"] = "River Jelly"
            recipes["SeaJelly"] = "Sea Jelly"; recipes["372"] = "Clam"
            // Extended Family legendaries only matter for bobber unlocks
            bobber["898"] = "Son of Crimsonfish"; bobber["899"] = "Ms. Angler"; bobber["900"] = "Legend II"
            bobber["901"] = "Radioactive Carp"; bobber["902"] = "Glacierfish Jr."
        }
        var ignore: Set<String> = CollectionData.fishIgnore
        if info.isBefore("1.6") {
            ignore.formUnion(["372", "898", "899", "900", "901", "902"])
        }

        return playerSection(title: "Fishing", version: "1.2") { player, meta in
            let recipeCount = recipes.count
            var count = 0
            var craftCount = 0
            var bobberCount = 0
            var modCount = 0
            var known: [String: Int] = [:]
            let umid = info.umid(of: player)
            let name = playerName(player)

            for item in player.find("fishCaught > item") {
                let rawId = item.first("key")?.allChildren.first?.text ?? ""
                let n = num(item.find("value > ArrayOfInt > int").first?.text)
                // 1.6 saves use keys like "(O)145"
                var id = rawId
                if let paren = rawId.firstIndex(of: ")") {
                    id = String(rawId[rawId.index(after: paren)...])
                }
                if n > 0 {
                    bobberCount += 1
                    if !ignore.contains(id) {
                        count += n
                        if let r = recipes[id] {
                            craftCount += 1
                            known[r] = n
                        } else if let b = bobber[id] {
                            known[b] = n
                        } else {
                            modCount += 1
                        }
                    }
                }
            }
            if umid == info.farmerId { info.overview.fishCaught = Set(known.keys) }
            var ptPct = RichText()
            if info.isAtLeast("1.5") {
                info.perfection.set(umid, "Fishing", CountTotal(count: craftCount, total: recipeCount))
                ptPct = Fmt.ptLink(pct: Double(craftCount) / Double(recipeCount))
            }
            var cell = Cell()
            cell.summary.append(.result("\(name) has \(count) total catches and has caught \(craftCount) of \(recipeCount) base game fish.".rt + ptPct))
            if modCount > 0 {
                cell.summary.append(.note(RichText("\(name) has also caught \(modCount) unrecognized (probably mod) fish.")))
            }
            var achs: [StatusLine] = [
                (count >= 100 ? Fmt.achieve("Mother Catch", "catch 100 total fish", true) : Fmt.achieve("Mother Catch", "catch 100 total fish", false) + "\(100 - count) more").progress(count, 100),
                (craftCount >= 10 ? Fmt.achieve("Fisherman", "catch 10 different fish", true) : Fmt.achieve("Fisherman", "catch 10 different fish", false) + "\(10 - craftCount) more").progress(craftCount, 10),
                (craftCount >= 24 ? Fmt.achieve("Ol' Mariner", "catch 24 different fish", true) : Fmt.achieve("Ol' Mariner", "catch 24 different fish", false) + "\(24 - craftCount) more").progress(craftCount, 24),
            ]
            if info.isAtLeast("1.4") {
                achs.append((craftCount >= recipeCount ? Fmt.achieve("Master Angler", "catch every type of fish", true)
                    : Fmt.achieve("Master Angler", "catch every type of fish", false) + "\(recipeCount - craftCount) more").progress(craftCount, recipeCount))
            } else {
                let goal = min(59, recipeCount)
                achs.append(craftCount >= goal ? Fmt.achieve("Master Angler", "catch 59 different fish", true)
                    : Fmt.achieve("Master Angler", "catch 59 different fish", false) + "\(goal - craftCount) more")
                if compareSemVer(info.version, "1.3") == 0 {
                    achs.append(craftCount >= recipeCount ? Fmt.milestone("Catch every type of fish", true)
                        : Fmt.milestone("Catch every type of fish", false) + "\(recipeCount - craftCount) more")
                }
            }
            cell.summary.append(.achList(achs))

            let totalBobbers = 39
            let bobbersUnlocked = min(totalBobbers, 1 + bobberCount / 2)
            let bobberFishLeft = 2 * (totalBobbers - 1) - bobberCount
            if info.isAtLeast("1.6") {
                cell.summary.append(.result(RichText("\(name) has unlocked \(bobbersUnlocked) of \(totalBobbers) bobber styles.")))
                cell.summary.append(.achList([
                    (bobbersUnlocked >= totalBobbers ? Fmt.milestone("Unlock every bobber style", true)
                        : Fmt.milestone("Unlock every bobber style", false) + "\(bobberFishLeft) more unique fish").progress(bobbersUnlocked, totalBobbers),
                ]))
            }
            if craftCount < recipeCount {
                let need = recipes.pairs.filter { known[$0.1] == nil }.map { DetailItem(wikify($0.1)) }
                meta.hasDetails = true
                cell.details.append(.need(RichText("Left to catch for achievements and bobber unlocks:"), Checkup.sortedItems(need), ordered: true))
            }
            if info.isAtLeast("1.6") {
                let achieveLeft = recipeCount - craftCount
                if bobbersUnlocked < totalBobbers && bobberFishLeft > achieveLeft {
                    let need = bobber.pairs.filter { known[$0.1] == nil }.map { DetailItem(wikify($0.1)) }
                    meta.hasDetails = true
                    cell.details.append(.need(RichText("Left to catch for bobber unlocks (don't need all):"), Checkup.sortedItems(need), ordered: true))
                }
            }
            return [cell]
        }
    }

    // MARK: Basic Shipping

    func parseBasicShipping() -> Section {
        var recipes = OrderedMap(CollectionData.basicShipping)
        if info.isAtLeast("1.4") {
            for (k, v) in [("807", "Dinosaur Mayonnaise"), ("812", "Roe"), ("445", "Caviar"), ("814", "Squid Ink"), ("815", "Tea Leaves"), ("447", "Aged Roe"), ("614", "Green Tea"), ("271", "Unmilled Rice")] { recipes[k] = v }
        }
        if info.isAtLeast("1.5") {
            for (k, v) in [("91", "Banana"), ("289", "Ostrich Egg"), ("829", "Ginger"), ("830", "Taro Root"), ("832", "Pineapple"), ("834", "Mango"), ("848", "Cinder Shard"), ("851", "Magma Cap"), ("881", "Bone Fragment"), ("909", "Radioactive Ore"), ("910", "Radioactive Bar")] { recipes[k] = v }
        }
        if info.isAtLeast("1.6") {
            for (k, v) in [("Moss", "Moss"), ("MysticSyrup", "Mystic Syrup"), ("Raisins", "Raisins"), ("DriedFruit", "Dried Fruit"), ("DriedMushrooms", "Dried Mushrooms"), ("Carrot", "Carrot"), ("SummerSquash", "Summer Squash"), ("Broccoli", "Broccoli"), ("Powdermelon", "Powdermelon"), ("SmokedFish", "Smoked Fish")] { recipes[k] = v }
        }
        return playerSection(title: "Basic Shipping", version: "1.2") { player, meta in
            let recipeCount = recipes.count
            var crafted: [String: Int] = [:]
            var craftCount = 0
            let umid = info.umid(of: player)
            for item in player.find("basicShipped > item") {
                let id = item.first("key")?.allChildren.first?.text ?? ""
                let n = num(item.text("value > int"))
                if let r = recipes[id], n > 0 {
                    crafted[r] = n
                    craftCount += 1
                }
            }
            var ptPct = RichText()
            if info.isAtLeast("1.5") {
                info.perfection.set(umid, "Shipping", CountTotal(count: craftCount, total: recipeCount))
                ptPct = Fmt.ptLink(pct: Double(craftCount) / Double(recipeCount))
            }
            var cell = Cell()
            cell.summary.append(.result("\(playerName(player)) has shipped \(craftCount) of \(recipeCount) basic items.".rt + ptPct))
            cell.summary.append(.achList([
                (craftCount >= recipeCount ? Fmt.achieve("Full Shipment", "ship every item", true)
                    : Fmt.achieve("Full Shipment", "ship every item", false) + "\(recipeCount - craftCount) more").progress(craftCount, recipeCount),
            ]))
            if craftCount < recipeCount {
                let need = recipes.pairs.filter { crafted[$0.1] == nil }.map { DetailItem(wikify($0.1)) }
                meta.hasDetails = true
                cell.details.append(.need(RichText("Left to ship:"), Checkup.sortedItems(need), ordered: true))
            }
            return [cell]
        }
    }

    // MARK: Crop Shipping

    func parseCropShipping() -> Section {
        let poly = OrderedMap(CollectionData.polyCrops)
        let monoExtras: [String: String] = ["454": "Ancient Fruit", "591": "Tulip", "593": "Summer Spangle", "595": "Fairy Rose", "597": "Blue Jazz"]
        return playerSection(title: "Crop Shipping", version: "1.2") { player, meta in
            let recipeCount = poly.count
            var crafted: [String: Int] = [:]
            var craftCount = 0
            var maxShip = 0
            var maxCrop = "of any crop"
            let farmer = playerName(player)
            for item in player.find("basicShipped > item") {
                let id = item.first("key")?.allChildren.first?.text ?? ""
                let n = num(item.text("value > int"))
                if let r = poly[id] {
                    crafted[r] = n
                    if n >= 15 { craftCount += 1 }
                    if n > maxShip { maxShip = n; maxCrop = r }
                } else if let r = monoExtras[id] {
                    if n > maxShip { maxShip = n; maxCrop = r }
                }
            }
            var cell = Cell()
            cell.summary.append(.result(RichText(maxShip > 0 ? "\(farmer) has shipped \(maxCrop) the most (\(maxShip))." : "\(farmer) has not shipped any crops yet.")))
            cell.summary.append(.achList([
                (maxShip >= 300 ? Fmt.achieve("Monoculture", "ship 300 of one crop", true)
                    : Fmt.achieve("Monoculture", "ship 300 of one crop", false) + "\(300 - maxShip) more \(maxCrop)").progress(maxShip, 300),
            ]))
            cell.summary.append(.result(RichText("\(farmer) has shipped 15 items from \(craftCount) of \(recipeCount) different crops.")))
            cell.summary.append(.achList([
                (craftCount >= recipeCount ? Fmt.achieve("Polyculture", "ship 15 of each crop", true)
                    : Fmt.achieve("Polyculture", "ship 15 of each crop", false) + " more of \(recipeCount - craftCount) crops").progress(craftCount, recipeCount),
            ]))
            if craftCount < recipeCount {
                var need: [DetailItem] = []
                for (_, r) in poly.pairs {
                    if let n = crafted[r] {
                        if n < 15 { need.append(DetailItem(wikify(r) + " -- \(15 - n) more")) }
                    } else {
                        need.append(DetailItem(wikify(r) + " -- 15 more"))
                    }
                }
                meta.hasDetails = true
                cell.details.append(.need(RichText("Left to ship:"), Checkup.sortedItems(need), ordered: true))
            }
            return [cell]
        }
    }
}
