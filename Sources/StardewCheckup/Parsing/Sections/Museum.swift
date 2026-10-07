import Foundation

extension Checkup {

    // MARK: Museum Collection

    func parseMuseum() -> Section {
        var section = Section(title: "Museum Collection", version: "1.2")
        let artifacts = OrderedMap(CollectionData.artifacts)
        let minerals = OrderedMap(CollectionData.minerals)
        var donated: Set<String> = []
        let museum = doc.first("locations > GameLocation\(info.typeIs("LibraryMuseum"))")
        let artifactCount = artifacts.count
        let mineralCount = minerals.count
        let museumCount = artifactCount + mineralCount

        for item in museum?.find("museumPieces > item") ?? [] {
            let raw = item.first("value")?.allChildren.first?.text ?? ""
            let id = String(num(raw))
            if artifacts.has(id) || minerals.has(id) { donated.insert(id) }
        }
        let donatedCount = donated.count

        info.overview.collections.append(("Museum", "Museum_Collection", donatedCount, museumCount))
        var global = Cell()
        global.summary.append(.result(RichText("\(info.intro) donated \(donatedCount) of \(museumCount) items to the museum.")))
        global.summary.append(.achList([
            (donatedCount >= 40 ? Fmt.achieve("Treasure Trove", "donate 40 items", true) : Fmt.achieve("Treasure Trove", "donate 40 items", false) + "\(40 - donatedCount) more").progress(donatedCount, 40),
            (donatedCount >= 60 ? Fmt.milestone("Donate enough items (60) to get the Rusty Key", true) : Fmt.milestone("Donate enough items (60) to get the Rusty Key", false) + "\(60 - donatedCount) more").progress(donatedCount, 60),
            (donatedCount >= museumCount ? Fmt.achieve("A Complete Collection", "donate every item", true) : Fmt.achieve("A Complete Collection", "donate every item", false) + "\(museumCount - donatedCount) more").progress(donatedCount, museumCount),
        ]))
        if donatedCount < museumCount {
            section.hasDetails = true
            global.details.append(.need(RichText("See below for items left to donate"), [], ordered: false))
        }
        section.globalCells = [global]

        let meta = SectionMeta()
        section.columns = perPlayer { player in
            var found: Set<String> = []
            var foundArt = 0
            var foundMin = 0
            let farmer = playerName(player)
            for item in player.find("archaeologyFound > item") {
                let id = item.first("key")?.allChildren.first?.text ?? ""
                let n = num(item.find("value > ArrayOfInt > int").first?.text)
                if artifacts.has(id) && n > 0 { found.insert(id); foundArt += 1 }
            }
            for item in player.find("mineralsFound > item") {
                let id = item.first("key")?.allChildren.first?.text ?? ""
                let n = num(item.text("value > int"))
                if minerals.has(id) && n > 0 { found.insert(id); foundMin += 1 }
            }
            var cell = Cell()
            cell.summary.append(.result(RichText("\(farmer) has found \(foundArt) of \(artifactCount) artifacts.")))
            cell.summary.append(.result(RichText("\(farmer) has found \(foundMin) of \(mineralCount) minerals.")))
            cell.summary.append(.achList([
                (foundArt >= artifactCount ? Fmt.milestone("All artifacts found", true) : Fmt.milestone("All artifacts found", false) + "\(artifactCount - foundArt) more").progress(foundArt, artifactCount),
                (foundMin >= mineralCount ? Fmt.milestone("All minerals found", true) : Fmt.milestone("All minerals found", false) + "\(mineralCount - foundMin) more").progress(foundMin, mineralCount),
            ]))
            if donatedCount < museumCount || (foundArt + foundMin) < museumCount {
                func needList(_ map: OrderedMap) -> [DetailItem] {
                    var out: [DetailItem] = []
                    for (id, r) in map.pairs {
                        var need: [String] = []
                        if !found.contains(id) { need.append("found") }
                        if !donated.contains(id) { need.append("donated") }
                        if !need.isEmpty { out.append(DetailItem(wikify(r) + " -- not \(need.joined(separator: " or "))")) }
                    }
                    return Checkup.sortedItems(out)
                }
                let needArt = needList(artifacts)
                let needMin = needList(minerals)
                meta.hasDetails = true
                var groups: [DetailItem] = []
                if !needArt.isEmpty { groups.append(DetailItem(RichText("Artifacts"), children: needArt, ordered: true)) }
                if !needMin.isEmpty { groups.append(DetailItem(RichText("Minerals"), children: needMin, ordered: true)) }
                cell.details.append(.need(RichText("Items left:"), groups, ordered: false))
            }
            return [cell]
        }
        if meta.hasDetails { section.hasDetails = true }
        return section
    }

    // MARK: Grandpa's Evaluation

    func parseGrandpa() -> Section {
        // Scoring details from StardewValley.Utility.getGradpaScore() & getGrandpaCandlesFromScore()
        var section = Section(title: "Grandpa's Evaluation", version: "1.2")
        section.hasDetails = true
        let farmer = doc.text("player > name")
        var count = 0
        let maxCount = 21
        var candles = 1
        let maxCandles = 4
        let currentCandles = num(doc.text("locations > GameLocation\(info.typeIs("Farm")) > grandpaScore"))
        let money = num(doc.text("player > totalMoneyEarned"))
        let achieves: [String: String] = ["5": "A Complete Collection", "26": "Master Angler", "34": "Full Shipment"]
        var achHave: Set<String> = []
        var ccDone = false
        let ccRooms = ["ccBoilerRoom", "ccCraftsRoom", "ccPantry", "ccFishTank", "ccVault", "ccBulletin"]
        var ccHave = 0
        let ccCount = 6
        var isJojaMember = false
        var hasSpouse = doc.first("player > spouse") != nil
        let houseUpgrades = num(doc.text("player > houseUpgradeLevel"))
        var hasRustyKey = false
        var hasSkullKey = false
        var hasKeys: [String] = []
        var heartCount = 0
        var hasPet = false
        var petLove = 0
        let realPlayerLevel = num(doc.text("player > farmingLevel")) + num(doc.text("player > miningLevel")) + num(doc.text("player > combatLevel"))
            + num(doc.text("player > foragingLevel")) + num(doc.text("player > fishingLevel")) + num(doc.text("player > luckLevel"))
        let playerLevel = Double(realPlayerLevel) / 2
        let host = info.host

        if info.isAtLeast("1.6") {
            hasRustyKey = host.hasMail("HasRustyKey")
            hasSkullKey = host.hasMail("HasSkullKey")
        } else {
            hasRustyKey = doc.text("player > hasRustyKey") == "true"
            hasSkullKey = doc.text("player > hasSkullKey") == "true"
        }

        if money >= 1_000_000 { count += 7 }
        else if money >= 500_000 { count += 5 }
        else if money >= 300_000 { count += 4 }
        else if money >= 200_000 { count += 3 }
        else if money >= 100_000 { count += 2 }
        else if money >= 50_000 { count += 1 }
        for a in doc.find("player > achievements > int") where achieves[a.text] != nil {
            count += 1
            achHave.insert(a.text)
        }
        if host.hasEvent("191393") { ccDone = true }
        if ccDone {
            count += 3
        } else {
            isJojaMember = host.hasMail("JojaMember")
            for id in ccRooms where host.hasMail(id) { ccHave += 1 }
            if ccHave >= ccCount { count += 1 }
        }
        if hasRustyKey { count += 1; hasKeys.append("Rusty Key") }
        if hasSkullKey { count += 1; hasKeys.append("Skull Key") }
        if info.isAtLeast("1.3") {
            let uid = doc.first("player")?.childText("UniqueMultiplayerID") ?? ""
            if info.partners[uid] != nil { hasSpouse = true }
        }
        if hasSpouse && houseUpgrades >= 2 { count += 1 }
        if info.isAtLeast("1.3") {
            for item in doc.find("player > friendshipData > item") where num(item.text("value > Friendship > Points")) >= 1975 { heartCount += 1 }
        } else {
            for item in doc.find("player > friendships > item") where num(item.find("value > ArrayOfInt > int").first?.text) >= 1975 { heartCount += 1 }
        }
        if heartCount >= 10 { count += 2 } else if heartCount >= 5 { count += 1 }
        if playerLevel >= 25 { count += 2 } else if playerLevel >= 15 { count += 1 }
        for npc in doc.find("locations > GameLocation > Characters > NPC") {
            let t = npc.attr("\(info.nsPrefix):type") ?? ""
            if t == "Pet" || t == "Cat" || t == "Dog" {
                hasPet = true
                petLove = max(petLove, num(npc.text("friendshipTowardFarmer")))
            }
        }
        // Previously maxed but now butterflied pet.
        if info.isAtLeast("1.6") && host.hasMail("petLoveMessage") { petLove = 1000 }
        if petLove >= 999 { count += 1 }
        if count >= 12 { candles = 4 } else if count >= 8 { candles = 3 } else if count >= 4 { candles = 2 }
        info.overview.grandpaPoints = count
        info.overview.grandpaCandlesLit = currentCandles
        info.overview.grandpaCandlesNext = candles

        var cell = Cell()
        cell.summary.append(.result(RichText("\(farmer) has earned a total of \(count) point(s) (details below); the maximum possible is \(maxCount) points.")))
        cell.summary.append(.result(RichText("The shrine has \(currentCandles) candle(s) lit. The next evaluation will light \(candles) candle(s).")))
        cell.summary.append(.achList([
            (candles >= maxCandles ? Fmt.milestone("Four candle evaluation", true) : Fmt.milestone("Four candle evaluation", false) + "\(12 - count) more point(s)").progress(count, 12, label: "\(count) / 12 points"),
        ]))

        var d: [Block] = []
        d.append(.result(RichText("\(farmer) has earned a total of \(addCommas(money))g.")))
        func moneyPt(_ pts: Int, _ goal: Int, _ label: String, _ cum: Bool) -> StatusLine {
            money >= goal ? Fmt.point(pts, "at least \(label) earnings", cumulative: cum, true)
                : Fmt.point(pts, "at least \(label) earnings", cumulative: cum, false) + " -- need \(addCommas(goal - money))g more"
        }
        d.append(.achList([
            moneyPt(1, 50_000, "50,000g", false), moneyPt(1, 100_000, "100,000g", true), moneyPt(1, 200_000, "200,000g", true),
            moneyPt(1, 300_000, "300,000g", true), moneyPt(1, 500_000, "500,000g", true), moneyPt(2, 1_000_000, "1,000,000g", true),
        ]))
        d.append(.result(RichText("\(farmer) has earned \(achHave.count) of the \(achieves.count) relevant achievements.")))
        func achPt(_ id: String, _ name: String) -> StatusLine {
            Fmt.point(1, name.italic + " Achievement", cumulative: false, achHave.contains(id))
        }
        d.append(.achList([achPt("5", "A Complete Collection"), achPt("26", "Master Angler"), achPt("34", "Full Shipment")]))

        if isJojaMember {
            d.append(.result(RichText("\(farmer) has purchased a Joja membership and cannot restore the Community Center")))
            d.append(.achList([Fmt.pointImpossible(1, "complete Community Center"), Fmt.pointImpossible(2, "attend the Community Center re-opening")]))
        } else {
            if ccDone || ccHave >= ccCount {
                d.append(.result(RichText("\(farmer) has completed the Community Center restoration" + (ccDone ? " and attended the re-opening ceremony." : " but has not yet attended the re-opening ceremony."))))
            } else {
                d.append(.result(RichText("\(farmer) has not completed the Community Center restoration.")))
            }
            d.append(.achList([
                Fmt.point(1, "complete Community Center", cumulative: false, ccDone || ccHave >= ccCount),
                Fmt.point(2, "attend the Community Center re-opening", cumulative: false, ccDone),
            ]))
        }
        d.append(.result(RichText("\(farmer) has \(realPlayerLevel) total skill levels.")))
        d.append(.achList([
            playerLevel >= 15 ? Fmt.point(1, "30 total skill levels", cumulative: false, true) : Fmt.point(1, "30 total skill levels", cumulative: false, false) + " -- need \(30 - realPlayerLevel) more",
            playerLevel >= 25 ? Fmt.point(1, "50 total skill levels", cumulative: true, true) : Fmt.point(1, "50 total skill levels", cumulative: true, false) + " -- need \(50 - realPlayerLevel) more",
        ]))
        d.append(.result(RichText("\(farmer) has \(heartCount) relationship(s) of 1975+ friendship points (~8 hearts.)")))
        d.append(.achList([
            heartCount >= 5 ? Fmt.point(1, "~8♥ with 5 people", cumulative: false, true) : Fmt.point(1, "~8♥ with 5 people", cumulative: false, false) + " -- need \(5 - heartCount) more",
            heartCount >= 10 ? Fmt.point(1, "~8♥ with 10 people", cumulative: true, true) : Fmt.point(1, "~8♥ with 10 people", cumulative: true, false) + " -- need \(10 - heartCount) more",
        ]))
        var petNeed: String
        if hasPet {
            d.append(.result(RichText("\(farmer) has a pet with \(petLove) friendship points.")))
            petNeed = "\(999 - petLove) more friendship points"
        } else {
            if petLove > 0 {
                d.append(.result(RichText("\(farmer) previously had a pet with \(petLove) friendship points.")))
            } else {
                d.append(.result(RichText("\(farmer) has not had a pet with any friendship points.")))
            }
            petNeed = "a pet and 999 friendship points"
        }
        d.append(.achList([
            petLove >= 999 ? Fmt.point(1, "pet with at least 999 friendship points", cumulative: false, true)
                : Fmt.point(1, "pet with at least 999 friendship points", cumulative: false, false) + " -- need \(petNeed)",
        ]))
        d.append(.result(RichText("\(farmer)\(hasSpouse ? " is" : " is not") married and has upgraded the farmhouse \(houseUpgrades) time(s).")))
        var needs: [String] = []
        if !hasSpouse { needs.append("a spouse") }
        if houseUpgrades < 2 { needs.append("\(2 - houseUpgrades) more upgrade(s)") }
        d.append(.achList([
            needs.isEmpty ? Fmt.point(1, "married with at least 2 house upgrades", cumulative: false, true)
                : Fmt.point(1, "married with at least 2 house upgrades", cumulative: false, false) + " -- need \(needs.joined(separator: " and "))",
        ]))
        if !hasKeys.isEmpty {
            d.append(.result(RichText("\(farmer) has acquired the \(hasKeys.joined(separator: " and ")).")))
        } else {
            d.append(.result(RichText("\(farmer) has not acquired either the Rusty Key or Skull Key.")))
        }
        d.append(.achList([
            hasRustyKey ? Fmt.point(1, "has the Rusty Key", cumulative: false, true) : Fmt.point(1, "get the Rusty Key", cumulative: false, false) + " -- acquired after 60 museum donations",
            hasSkullKey ? Fmt.point(1, "has the Skull Key", cumulative: false, true) : Fmt.point(1, "get the Skull Key", cumulative: false, false) + " -- acquired on level 120 of the mines",
        ]))
        cell.details = d
        section.globalCells = [cell]
        return section
    }
}
