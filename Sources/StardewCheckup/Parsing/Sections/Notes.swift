import Foundation

extension Checkup {

    // MARK: Secret Notes (1.3)

    func parseSecretNotes() -> Section? {
        let version = "1.3"
        if info.isBefore(version) { return nil }
        var hasStoneJunimo = false
        // Stone Junimo has no confirmation flag so we search the whole save, ignoring the
        // buried one which may reappear at (57, 16) on the Town map.
        if doc.first("Item > name[.='Stone Junimo']") != nil {
            hasStoneJunimo = true
        }
        if !hasStoneJunimo {
            for nameNode in doc.find("Object > name[.='Stone Junimo']") {
                let loc = nameNode.ancestor(named: "GameLocation")?.childText("name") ?? ""
                if loc == "Town" {
                    let item = nameNode.ancestor(named: "item")
                    let x = item?.text("key > Vector2 > X") ?? ""
                    let y = item?.text("key > Vector2 > Y") ?? ""
                    if x != "57" || y != "16" { hasStoneJunimo = true; break }
                } else {
                    hasStoneJunimo = true
                    break
                }
            }
        }

        return playerSection(title: "Secret Notes", version: version) { player, meta in
            let farmer = playerName(player)
            let umid = player.childText("UniqueMultiplayerID")
            let pd = info.data[umid]!
            var notes: Set<Int> = []
            var rewards: Set<Int> = []
            var rewardSkip: Set<Int> = []
            var foundNotes = 0
            var foundRewards = 0
            var noteCount = 23
            var modCount = 0
            let rewardStart = 13
            var rewardCount = noteCount - rewardStart + 1
            var hasMagnifyingGlass = false

            if info.isAtLeast("1.4") {
                noteCount = 25
                rewardCount += 1
                rewardSkip.insert(24)
            }
            if info.isAtLeast("1.6") {
                noteCount = 27
                rewardSkip.insert(26)
                rewardSkip.insert(27)
                hasMagnifyingGlass = pd.hasMail("HasMagnifyingGlass")
            } else {
                hasMagnifyingGlass = player.childText("hasMagnifyingGlass") == "true"
            }
            let hasSeenKrobus = pd.hasEvent("520702")
            if pd.hasEvent("2120303") { rewards.insert(23); foundRewards += 1 }
            let rewardMail: [(String, Int)] = [
                ("gotPearl", 15), ("junimoPlush", 13), ("TH_Tunnel", 22), ("carolinesNecklace", 25),
                ("SecretNote16_done", 16), ("SecretNote17_done", 17), ("SecretNote18_done", 18),
                ("SecretNote19_done", 19), ("SecretNote20_done", 20), ("secretNote21_done", 21),
            ]
            for (id, n) in rewardMail where pd.hasMail(id) { rewards.insert(n); foundRewards += 1 }
            let isJojaMember = pd.hasMail("JojaMember")
            if isJojaMember {
                rewardCount -= 1
                rewardSkip.insert(14)
            } else if hasStoneJunimo {
                rewards.insert(14)
                foundRewards += 1
            }

            var c1 = Cell()
            c1.summary.append(.result(RichText("\(farmer) has \(hasSeenKrobus ? "" : "not ")seen the Shadow Guy at the Bus Stop.")))
            c1.summary.append(.result(RichText("\(farmer) has \(hasMagnifyingGlass ? "" : "not ")found the Magnifying Glass.")))
            for n in player.find("secretNotesSeen > int") {
                let v = num(n.text)
                if v < 1000 {
                    if v > noteCount { modCount += 1 } else { notes.insert(v); foundNotes += 1 }
                }
            }
            c1.summary.append(.result(RichText("\(farmer) has read \(foundNotes) of \(noteCount) secret notes.")))
            if modCount > 0 {
                c1.summary.append(.note(RichText("\(farmer) has read \(modCount) mod secret note(s).")))
            }
            c1.summary.append(.achList([
                (foundNotes >= noteCount ? Fmt.milestone("Read all the secret notes", true) : Fmt.milestone("Read all the secret notes", false) + "\(noteCount - foundNotes) more").progress(foundNotes, noteCount),
            ]))
            if foundNotes < noteCount {
                let need = (1...noteCount).filter { !notes.contains($0) }.map { DetailItem(wikify("Secret Note #\($0)", "Secret Notes")) }
                if !need.isEmpty {
                    meta.hasDetails = true
                    c1.details.append(.need(RichText("Left to read:"), need, ordered: true))
                }
            }

            var c2 = Cell()
            c2.summary.append(.result(RichText("\(farmer) has found the rewards from  \(foundRewards) of \(rewardCount) secret notes.")))
            c2.summary.append(.achList([
                (foundRewards >= rewardCount ? Fmt.milestone("Find all the secret note rewards", true) : Fmt.milestone("Find all the secret note rewards", false) + "\(rewardCount - foundRewards) more").progress(foundRewards, rewardCount),
            ]))
            if foundRewards < rewardCount {
                var need: [DetailItem] = []
                for i in rewardStart...noteCount where !rewardSkip.contains(i) && !rewards.contains(i) {
                    let extra = i == 14 ? " (Note: may be inaccurate if item was collected and destroyed.)" : ""
                    need.append(DetailItem(" Reward from ".rt + wikify("Secret Note #\(i)", "Secret Notes") + extra))
                }
                if !need.isEmpty {
                    meta.hasDetails = true
                    c2.details.append(.need(RichText("Left to find:"), need, ordered: true))
                }
            }
            return [c1, c2]
        }
    }

    // MARK: Journal Scraps (1.5)

    func parseJournalScraps() -> Section? {
        let version = "1.5"
        if info.isBefore(version) { return nil }
        let mermaidDone = doc.find("collectedNutTracker > string").contains { $0.text == "Mermaid" }
        return playerSection(title: "Journal Scraps", version: version) { player, meta in
            let farmer = playerName(player)
            let umid = player.childText("UniqueMultiplayerID")
            let pd = info.data[umid]!
            var notes: Set<Int> = []
            var rewards: [Int: Bool] = [1004: false, 1006: false, 1009: false, 1010: false]
            var foundNotes = 0
            var foundRewards = 0
            let noteCount = 11
            let rewardCount = 4
            var modCount = 0
            let rewardMail: [(String, Int)] = [("Island_W_BuriedTreasure2", 1006), ("Island_W_BuriedTreasure", 1004), ("Island_N_BuriedTreasure", 1010)]
            for (id, n) in rewardMail where pd.hasMail(id) { rewards[n] = true; foundRewards += 1 }
            let hasVisitedIsland = pd.hasMail("Visited_Island")

            var c1 = Cell()
            c1.summary.append(.result(RichText("\(farmer) has \(hasVisitedIsland ? "" : "not ")visited the Island.")))
            c1.summary.append(.achList([
                hasVisitedIsland ? Fmt.achieve("A Distant Shore", "Reach Ginger Island", true) : Fmt.achieve("A Distant Shore", "Reach Ginger Island", false) + " to visit",
            ]))
            for n in player.find("secretNotesSeen > int") {
                let v = num(n.text)
                if v >= 1000 {
                    if v >= 1012 { modCount += 1 } else { notes.insert(v); foundNotes += 1 }
                }
            }
            c1.summary.append(.result(RichText("\(farmer) has read \(foundNotes) of \(noteCount) journal scraps.")))
            if modCount > 0 {
                c1.summary.append(.note(RichText("\(farmer) has read \(modCount) mod journal scrap(s).")))
            }
            c1.summary.append(.achList([
                (foundNotes >= noteCount ? Fmt.milestone("Read all the journal scraps", true) : Fmt.milestone("Read all the journal scraps", false) + "\(noteCount - foundNotes) more").progress(foundNotes, noteCount),
            ]))
            if foundNotes < noteCount {
                let need = (1...noteCount).filter { !notes.contains(1000 + $0) }.map { DetailItem(wikify("Journal Scrap #\($0)", "Journal Scraps")) }
                if !need.isEmpty {
                    meta.hasDetails = true
                    c1.details.append(.need(RichText("Left to read:"), need, ordered: true))
                }
            }
            // Mermaid puzzle is only checked via the walnut award.
            if mermaidDone { rewards[1009] = true; foundRewards += 1 }
            var c2 = Cell()
            c2.summary.append(.result(RichText("\(farmer) has found the rewards from  \(foundRewards) of \(rewardCount) journal scraps.")))
            c2.summary.append(.achList([
                (foundRewards >= rewardCount ? Fmt.milestone("Find all the journal scrap rewards", true) : Fmt.milestone("Find all the journal scrap rewards", false) + "\(rewardCount - foundRewards) more").progress(foundRewards, rewardCount),
            ]))
            if foundRewards < rewardCount {
                let need = rewards.keys.sorted().filter { rewards[$0] == false }.map { DetailItem(" Reward from ".rt + wikify("Journal Scrap #\($0 - 1000)", "Journal Scraps")) }
                if !need.isEmpty {
                    meta.hasDetails = true
                    c2.details.append(.need(RichText("Left to find:"), need, ordered: true))
                }
            }
            return [c1, c2]
        }
    }

    // MARK: Special Orders (1.5)

    func parseSpecialOrders() -> Section? {
        let version = "1.5"
        if info.isBefore(version) { return nil }
        var section = Section(title: "Special Orders", version: version)
        let town: [(String, String)] = [
            ("Caroline", "Island Ingredients"), ("Clint", "Cave Patrol"), ("Demetrius", "Aquatic Overpopulation"), ("Demetrius2", "Biome Balance"),
            ("Emily", "Rock Rejuvenation"), ("Evelyn", "Gifts for George"), ("Gunther", "Fragments of the past"), ("Gus", "Gus' Famous Omelet"),
            ("Lewis", "Crop Order"), ("Linus", "Community Cleanup"), ("Pam", "The Strong Stuff"), ("Pierre", "Pierre's Prime Produce"),
            ("Robin", "Robin's Project"), ("Robin2", "Robin's Resource Rush"), ("Willy", "Juicy Bugs Wanted!"), ("Willy2", "Tropical Fish"),
            ("Wizard", "A Curious Substance"), ("Wizard2", "Prismatic Jelly"),
        ]
        let townIds = Set(town.map(\.0))
        var found: Set<String> = []
        for s in doc.find("completedSpecialOrders > string") where townIds.contains(s.text) {
            found.insert(s.text)
        }
        var cell = Cell()
        cell.summary.append(.result(RichText("\(info.intro) completed \(found.count) of \(town.count) town special orders.")))
        cell.summary.append(.achList([
            (found.count >= town.count ? Fmt.milestone("Complete all Special Orders", true) : Fmt.milestone("Complete all Special Orders", false) + "\(town.count - found.count) more").progress(found.count, town.count),
        ]))
        if found.count < town.count {
            let need = town.filter { !found.contains($0.0) }.map { DetailItem(wikify($0.1, "Quests#List_of_Special_Orders", noAnchor: true)) }
            if !need.isEmpty {
                section.hasDetails = true
                cell.details.append(.need(RichText("Left to complete:"), Checkup.sortedItems(need), ordered: true))
            }
        }
        section.globalCells = [cell]
        return section
    }
}
