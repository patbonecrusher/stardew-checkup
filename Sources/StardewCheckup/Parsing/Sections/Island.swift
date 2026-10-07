import Foundation

extension Checkup {

    // MARK: Golden Walnuts (1.5)

    func parseWalnuts() -> Section? {
        let version = "1.5"
        if info.isBefore(version) { return nil }
        var section = Section(title: "Golden Walnuts", version: version)
        var count = 0
        var foundCount = 0
        let gameCount = num(doc.text("goldenWalnutsFound"))
        let parrotUsed = doc.text("activatedGoldenParrot") == "true"
        var found: [String: Int] = [:]
        var need: [(String, Int)] = []

        let allAtOnce = WalnutData.allAtOnce
        let extra = WalnutData.extra
        let limited = WalnutData.limited
        let allAtOnceById = Dictionary(uniqueKeysWithValues: allAtOnce.map { ($0.id, $0) })
        let limitedById = Dictionary(uniqueKeysWithValues: limited.map { ($0.id, $0) })

        if doc.text("SaveGame > goldenCoconutCracked") == "true" {
            found["GoldenCoconut"] = 1
            foundCount += 1
        }
        for s in doc.find("collectedNutTracker > string") {
            if let g = allAtOnceById[s.text] {
                found[g.id] = g.num
                foundCount += g.num
            }
        }
        for item in doc.find("limitedNutDrops > item") {
            let id = item.text("key > string")
            let n = num(item.text("value > int"))
            // Using the Joja Golden Parrot sets a lot of these to 9999
            if let g = limitedById[id], n > 0 {
                let v = min(n, g.num)
                found[id] = v
                foundCount += v
            }
        }
        for g in allAtOnce {
            count += g.num
            if found[g.id] == nil { need.append((g.id, g.num)) }
        }
        for g in extra {
            count += g.num
            if found[g.id] == nil { need.append((g.id, g.num)) }
        }
        for g in limited {
            count += g.num
            if let f = found[g.id] {
                if f < g.num { need.append((g.id, g.num - f)) }
            } else {
                need.append((g.id, g.num))
            }
        }

        info.perfection.walnuts = CountTotal(count: gameCount, total: count)
        var ptPct = RichText()
        if info.isAtLeast("1.5") {
            let x = min(100, 100 * Double(gameCount) / Double(count))
            ptPct = Fmt.ptLink(toFixed(x, x < 100 ? 1 : 0) + "%")
        }
        var cell = Cell()
        cell.summary.append(.result("\(info.intro) found \(gameCount) of \(count) golden walnuts.".rt + ptPct))
        if foundCount != gameCount {
            cell.summary.append(.warn(RichText("Warning: Save lists a count of \(gameCount) but we've found markers for \(foundCount)")))
        }
        let parrot = wikify("Golden Parrot", "Golden_Walnut#Golden_Joja_Parrot")
        if gameCount < count {
            cell.summary.append(.result("The ".rt + parrot + " will charge \(addCommas(10000 * (count - gameCount)))g to collect the rest."))
        } else {
            cell.summary.append(.result("The ".rt + parrot + (parrotUsed ? " was" : " was not") + " used to finish the collection."))
        }
        cell.summary.append(.achList([
            (gameCount >= 10 ? Fmt.milestone("Collect enough walnuts (10) to earn Leo's trust.", true) : Fmt.milestone("Collect enough walnuts (10) to earn Leo's trust.", false) + "\(10 - gameCount) more").progress(gameCount, 10),
            (gameCount >= 101 ? Fmt.milestone("Collect enough walnuts (101) to access the secret room.", true) : Fmt.milestone("Collect enough walnuts (101) to access the secret room", false) + "\(101 - gameCount) more").progress(gameCount, 101),
        ]))
        if foundCount < count {
            section.hasDetails = true
            var items: [DetailItem] = []
            var val = 0
            for (id, n) in need {
                val += n
                let goal = allAtOnceById[id] ?? limitedById[id] ?? extra.first { $0.id == id }
                guard let g = goal else { continue }
                var line = RichText(g.name + (n > 1 ? " -- \(n) walnuts" : ""))
                if !g.hint.isEmpty {
                    line += " ("
                    line += RichText(runs: [Run(text: "Hover for spoilers", italic: true, tooltip: g.hint)])
                    line += ")"
                }
                items.append(DetailItem(line, value: val))
            }
            cell.details.append(.need(RichText("Left to find:"), items, ordered: true))
        }
        section.globalCells = [cell]
        return section
    }

    // MARK: Island Upgrades (1.5)

    func parseIslandUpgrades() -> Section? {
        let version = "1.5"
        if info.isBefore(version) { return nil }
        var section = Section(title: "Island Upgrades", version: version)
        let upgrades: [(String, Int, String)] = [
            ("Island_FirstParrot", 1, "Feed Leo's Friend"),
            ("Island_Turtle", 10, "Turtle Relocation"),
            ("Island_UpgradeHouse", 20, "Island Farmhouse"),
            ("Island_Resort", 20, "Resort"),
            ("Island_UpgradeTrader", 10, "Island Trader"),
            ("Island_UpgradeBridge", 10, "Bridge to Dig Site"),
            ("Island_UpgradeParrotPlatform", 10, "Parrot Express Platforms"),
            ("Island_UpgradeHouse_Mailbox", 5, "Mailbox"),
            ("Island_W_Obelisk", 20, "Obelisk to Return to Valley"),
            ("Island_VolcanoBridge", 5, "Bridge in Volcano entrance"),
            ("Island_VolcanoShortcutOut", 5, "Exit hole from Volcano vendor"),
        ]
        var boughtCount = 0
        var need: [(String, Int)] = []
        var cost = 0
        for (id, c, name) in upgrades {
            if info.host.hasMail(id) {
                boughtCount += 1
            } else {
                need.append((name, c))
                cost += c
            }
        }
        var cell = Cell()
        cell.summary.append(.result(RichText("\(info.intro) purchased \(boughtCount) of \(upgrades.count) Island Upgrades.")))
        cell.summary.append(.achList([
            (boughtCount >= upgrades.count ? Fmt.milestone("Purchase all upgrades.", true)
                : Fmt.milestone("Purchase all upgrades", false) + "\(upgrades.count - boughtCount) more (costs \(cost) walnuts)").progress(boughtCount, upgrades.count),
        ]))
        if boughtCount < upgrades.count {
            section.hasDetails = true
            let items = need.map { DetailItem($0.0 + ($0.1 > 1 ? " -- costs \($0.1) walnuts" : "")) }
            cell.details.append(.need(RichText("Left to buy:"), items, ordered: true))
        }
        section.globalCells = [cell]
        return section
    }

    // MARK: Perfection Tracker (1.5)

    func parsePerfectionTracker() -> Section? {
        // Scoring details from Utility.percentGameComplete()
        let version = "1.5"
        if info.isBefore(version) { return nil }
        var section = Section(title: "Perfection Tracker", version: version)
        section.hasDetails = true
        let pt = info.perfection
        for b in doc.find("locations > GameLocation\(info.typeIs("Farm")) > buildings > Building") {
            pt.setBuilding(b.childText("buildingType"))
        }
        let waivers = info.isAtLeast("1.6") ? num(doc.text("perfectionWaivers")) : 0
        let extra = waivers > 0 ? "(+\(waivers) Waivers)" : ""
        var numObelisks = 0
        var missing: [RichText] = []
        if pt.earthObelisk { numObelisks += 1 } else { missing.append(wikify("Earth", "Earth Obelisk", noAnchor: true)) }
        if pt.waterObelisk { numObelisks += 1 } else { missing.append(wikify("Water", "Water Obelisk", noAnchor: true)) }
        if pt.desertObelisk { numObelisks += 1 } else { missing.append(wikify("Desert", "Desert Obelisk", noAnchor: true)) }
        if pt.islandObelisk { numObelisks += 1 } else { missing.append(wikify("Island", "Island Obelisk", noAnchor: true)) }
        numObelisks = min(numObelisks, 4)

        // The game counts the highest percentage among players for each player-specific goal.
        let pKeys = ["Shipping", "Cooking", "Crafting", "Fishing", "Great Friends", "Skills"]
        let bKeys = ["Monsters", "Stardrops"]
        var pct: [String: Double] = ["Walnuts": min(pt.walnuts.ratio, 1)]
        var flag: [String: Bool] = [:]
        var best: [String: String] = [:]
        for k in pKeys {
            pct[k] = 0
            best[k] = ""
            for umid in info.playerOrder {
                let p = min(pt.get(umid, k).ratio, 1)
                if p > pct[k]! { pct[k] = p; best[k] = info.playerName(umid) }
            }
        }
        for k in bKeys {
            flag[k] = false
            best[k] = ""
            for umid in info.playerOrder where !flag[k]! && pt.getBool(umid, k) {
                flag[k] = true
                best[k] = info.playerName(umid)
            }
        }
        let ptPct = Double(numObelisks) + (pt.goldClock ? 10 : 0) + (flag["Monsters"]! ? 10 : 0) + (flag["Stardrops"]! ? 10 : 0)
            + 15 * pct["Shipping"]! + 11 * pct["Great Friends"]! + 10 * pct["Cooking"]! + 10 * pct["Crafting"]! + 10 * pct["Fishing"]!
            + 5 * pct["Walnuts"]! + 5 * pct["Skills"]!
        let left = 100 - ptPct - Double(waivers)
        let adj = min(100, ptPct + Double(waivers))
        let adjStr = toFixed(adj, adj < 100 ? 1 : 0)
        let ptStr = toFixed(ptPct, ptPct < 100 ? 1 : 0)
        let leftStr = toFixed(left, left < 100 ? 1 : 0)
        info.overview.perfectionPct = adj

        var cell = Cell()
        cell.summary.append(.result(RichText("Inhabitants of \(info.farmName) Farm have earned \(adjStr)% Total Perfection (details below).")))
        cell.summary.append(.result(RichText("Note that the Walnut Room display always rounds down and will show: \(Int(ptPct.rounded(.down)))% \(extra)".trimmingCharacters(in: .whitespaces))))
        cell.summary.append(.achList([
            (dbl(ptStr) >= 100 ? Fmt.milestone("100% Completion", true) : Fmt.milestone("100% Completion", false) + "\(leftStr)% more").progress(fraction: dbl(ptStr) / 100),
        ]))

        func seeAbove(_ s: String) -> RichText { " -- see \(s) above for needs".rt }
        var lines: [StatusLine] = []
        lines.append(pct["Shipping"]! >= 1 ? Fmt.perfectionPct(pct["Shipping"]!, 15, "Produce & Forage Shipped", true, who: best["Shipping"]!)
            : Fmt.perfectionPct(pct["Shipping"]!, 15, "Produce & Forage Shipped", false, who: best["Shipping"]!) + seeAbove("Basic Shipping"))
        var ob = numObelisks == 4 ? Fmt.perfectionNum(numObelisks, 4, "Obelisks on Farm", true) : Fmt.perfectionNum(numObelisks, 4, "Obelisks on Farm", false) + " -- need "
        if numObelisks < 4 {
            for (i, m) in missing.enumerated() { if i > 0 { ob += ", " }; ob += m }
        }
        lines.append(ob)
        lines.append(Fmt.perfectionBool(10, "Golden Clock on Farm", pt.goldClock) + (pt.goldClock ? RichText() : " -- need to build a ".rt + wikify("Gold Clock")))
        lines.append(Fmt.perfectionBool(10, "Monster Slayer Hero (all slayer goals)", flag["Monsters"]!, who: best["Monsters"]!) + (flag["Monsters"]! ? RichText() : seeAbove("Monster Hunting")))
        lines.append(pct["Great Friends"]! >= 1 ? Fmt.perfectionPct(pct["Great Friends"]!, 11, "Great Friends (maxing all relationships)", true, who: best["Great Friends"]!)
            : Fmt.perfectionPct(pct["Great Friends"]!, 11, "Great Friends (maxing all relationships)", false, who: best["Great Friends"]!) + seeAbove("Social"))
        lines.append(pct["Skills"]! >= 1 ? Fmt.perfectionPctNum(pct["Skills"]!, 5, 25, "Farmer Level (max all skills)", true, who: best["Skills"]!)
            : Fmt.perfectionPctNum(pct["Skills"]!, 5, 25, "Farmer Level (max all skills)", false, who: best["Skills"]!) + seeAbove("Skills"))
        lines.append(Fmt.perfectionBool(10, "Found All Stardrops", flag["Stardrops"]!, who: best["Stardrops"]!) + (flag["Stardrops"]! ? RichText() : seeAbove("Stardrops")))
        lines.append(pct["Cooking"]! >= 1 ? Fmt.perfectionPct(pct["Cooking"]!, 10, "Cooking Recipes Made", true, who: best["Cooking"]!)
            : Fmt.perfectionPct(pct["Cooking"]!, 10, "Cooking Recipes Made", false, who: best["Cooking"]!) + seeAbove("Cooking"))
        lines.append(pct["Crafting"]! >= 1 ? Fmt.perfectionPct(pct["Crafting"]!, 10, "Crafting Recipes Made", true, who: best["Crafting"]!)
            : Fmt.perfectionPct(pct["Crafting"]!, 10, "Crafting Recipes Made", false, who: best["Crafting"]!) + seeAbove("Crafting"))
        lines.append(pct["Fishing"]! >= 1 ? Fmt.perfectionPct(pct["Fishing"]!, 10, "Fish Caught", true, who: best["Fishing"]!)
            : Fmt.perfectionPct(pct["Fishing"]!, 10, "Fish Caught", false, who: best["Fishing"]!) + seeAbove("Fishing"))
        lines.append(pct["Walnuts"]! >= 1 ? Fmt.perfectionPctNum(pct["Walnuts"]!, 5, 130, "Golden Walnuts Found", true)
            : Fmt.perfectionPctNum(pct["Walnuts"]!, 5, 130, "Golden Walnuts Found", false) + seeAbove("Golden Walnuts"))
        if waivers > 0 {
            lines.append(StatusLine(kind: .perfection, state: .yes, text: RichText(runs: [Run(text: "\(waivers)%", color: .yes, bold: true), Run(text: " from purchase of \(waivers) Perfection Waivers", color: .yes)])))
        }
        cell.details.append(.result(RichText("Percentage Breakdown")))
        cell.details.append(.achList(lines))
        section.globalCells = [cell]
        return section
    }
}
