import Foundation

extension Checkup {

    static let skillNames = ["Farming", "Fishing", "Foraging", "Mining", "Combat"]

    // MARK: Skills

    func parseSkills() -> Section {
        let nextLevel = [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000]
        return playerSection(title: "Skills", version: "1.2") { player, meta in
            let umid = info.umid(of: player)
            let pd = info.data[umid]!
            let isMale = player.childText("isMale") == "true"
            var count = 0
            var need: [DetailItem] = []
            var level = 10
            for (i, skill) in Checkup.skillNames.enumerated() {
                let n = pd.xp(i)
                if n < 15000 {
                    for j in 0..<10 where nextLevel[j] > n {
                        level = j
                        break
                    }
                    need.append(DetailItem(wikify(skill) + " (level \(level)) -- need \(addCommas(nextLevel[level] - n)) more xp to next level and \(addCommas(15000 - n)) more xp to max"))
                } else {
                    count += 1
                }
            }
            let ptLevel = (num(player.text("farmingLevel")) + num(player.text("miningLevel")) + num(player.text("combatLevel"))
                + num(player.text("foragingLevel")) + num(player.text("fishingLevel")) + num(player.text("luckLevel"))) / 2
            var ptPct = RichText()
            if info.isAtLeast("1.5") {
                ptPct = Fmt.ptLink(jsNum(Double(ptLevel) / 0.25) + "%")
                info.perfection.set(umid, "Skills", CountTotal(count: ptLevel, total: 25))
            }
            let title: String
            switch ptLevel {
            case 0...2: title = "Newcomer"
            case 3...4: title = "Greenhorn"
            case 5...6: title = "Bumpkin"
            case 7...8: title = "Cowpoke"
            case 9...10: title = "Farmhand"
            case 11...12: title = "Tiller"
            case 13...14: title = "Smallholder"
            case 15...16: title = "Sodbuster"
            case 17...18: title = "Farm" + (isMale ? "boy" : "girl")
            case 19...20: title = "Granger"
            case 21...22: title = "Planter"
            case 23...24: title = "Rancher"
            case 25...26: title = "Farmer"
            case 27...28: title = "Agriculturist"
            case 29: title = "Cropmaster"
            default: title = "Farm King"
            }
            if umid == info.farmerId {
                info.overview.farmerLevel = ptLevel
                info.overview.farmerTitle = title
                info.overview.skillXP = (0..<5).map { pd.xp($0) }
            }
            var cell = Cell()
            cell.summary.append(.result("\(info.playerName(umid)) is ".rt + wikify("Farmer Level", "Skills#Skill-Based_Title", noAnchor: true) + " \(ptLevel) with title \(title)." + ptPct))
            cell.summary.append(.result(RichText("\(info.playerName(umid)) has reached level 10 in \(count) of 5 skills.")))
            cell.summary.append(.achList([
                (count >= 1 ? Fmt.achieve("Singular Talent", "level 10 in a skill", true)
                    : Fmt.achieve("Singular Talent", "level 10 in a skill", false) + "\(1 - count) more").progress(count, 1),
                (count >= 5 ? Fmt.achieve("Master of the Five Ways", "level 10 in every skill", true)
                    : Fmt.achieve("Master of the Five Ways", "level 10 in every skill", false) + "\(5 - count) more").progress(count, 5),
            ]))
            if !need.isEmpty {
                meta.hasDetails = true
                cell.details.append(.need(RichText("Skills left:"), Checkup.sortedItems(need), ordered: true))
            }
            return [cell]
        }
    }

    // MARK: Skill Mastery (1.6)

    func parseSkillMastery() -> Section? {
        let version = "1.6"
        if info.isBefore(version) { return nil }
        let nextLevel = [0, 10000, 25000, 45000, 70000, 100000]
        return playerSection(title: "Skill Mastery", version: version) { player, meta in
            let umid = player.childText("UniqueMultiplayerID")
            let pd = info.data[umid]!
            var maxCount = 0
            var perkCount = 0
            var needPerk: [DetailItem] = []
            let masteryXP = pd.stat("MasteryExp")
            var masteryNextLvl = 0
            var masteryNextXP = 0
            if masteryXP < 100000 {
                for i in 1...5 where masteryXP < nextLevel[i] {
                    masteryNextLvl = i
                    break
                }
                masteryNextXP = nextLevel[masteryNextLvl]
            }
            for (i, skill) in Checkup.skillNames.enumerated() {
                if pd.hasStat("mastery_\(i)") {
                    perkCount += 1
                } else {
                    needPerk.append(DetailItem(skill))
                }
                if pd.xp(i) >= 15000 { maxCount += 1 }
            }
            var unchosen = 0
            if masteryXP < 100000 && masteryNextLvl > perkCount + 1 {
                unchosen = masteryNextLvl - perkCount - 1
            }
            let name = info.playerName(umid)
            var cell = Cell()
            cell.summary.append(.result(RichText("\(name) has maxed \(maxCount) of \(Checkup.skillNames.count) skills.")))
            cell.summary.append(.achList([
                (maxCount >= 5 ? Fmt.milestone("Gain access to the Mastery Cave", true)
                    : Fmt.milestone("Gain access to the Mastery Cave", false) + "\(Checkup.skillNames.count - maxCount) more maxed skills -- see Skills above for needs").progress(maxCount, 5),
            ]))
            cell.summary.append(.result(RichText("\(name) has \(addCommas(masteryXP)) mastery xp.")))
            cell.summary.append(.achList([
                (masteryXP >= 100000 ? Fmt.milestone("Reach 100,000 mastery xp", true)
                    : Fmt.milestone("Reach 100,000 mastery xp", false) + "\(addCommas(masteryNextXP - masteryXP)) more xp for next perk unlock and \(addCommas(100000 - masteryXP)) more xp overall").progress(masteryXP, 100000),
            ]))
            cell.summary.append(.result(RichText("\(name) has selected \(perkCount) of \(Checkup.skillNames.count) mastery perks.")))
            var perkLine = perkCount >= 5 ? Fmt.milestone("Acquire all mastery perks", true)
                : Fmt.milestone("Acquire all mastery perks", false) + "\(Checkup.skillNames.count - perkCount) more"
            perkLine += (perkCount < 5 && unchosen > 0) ? " including \(unchosen) available but unselected." : "."
            cell.summary.append(.achList([perkLine.progress(perkCount, Checkup.skillNames.count)]))
            if !needPerk.isEmpty {
                meta.hasDetails = true
                cell.details.append(.need(RichText("Perks left:"), Checkup.sortedItems(needPerk), ordered: true))
            }
            return [cell]
        }
    }

    // MARK: Quests

    func parseQuests() -> Section {
        playerSection(title: "Quests", version: "1.2") { player, _ in
            let count: Int
            if info.isAtLeast("1.6") {
                count = info.data[info.umid(of: player)]?.stat("questsCompleted") ?? 0
            } else if info.isAtLeast("1.3") {
                count = num(player.text("stats > questsCompleted"))
            } else {
                count = num(player.parent?.text("stats > questsCompleted"))
            }
            var cell = Cell()
            cell.summary.append(.result(RichText("\(playerName(player)) has completed \(count) \"Help Wanted\" quest(s).")))
            cell.summary.append(.achList([
                (count >= 10 ? Fmt.achieve("Gofer", "complete 10 quests", true)
                    : Fmt.achieve("Gofer", "complete 10 quests", false) + "\(10 - count) more").progress(count, 10),
                (count >= 40 ? Fmt.achieve("A Big Help", "complete 40 quests", true)
                    : Fmt.achieve("A Big Help", "complete 40 quests", false) + "\(40 - count) more").progress(count, 40),
            ]))
            return [cell]
        }
    }

    // MARK: Monster Hunting

    func parseMonsters() -> Section {
        // Conditions & details from decompiled source StardewValley.Locations.AdventureGuild.gil()
        var goals: [(String, Int)] = [
            ("Slimes", 1000), ("Void Spirits", 150), ("Bats", 200), ("Skeletons", 50),
            ("Cave Insects", 125), ("Duggies", 30), ("Dust Sprites", 500),
        ]
        var categories: [String: String] = [
            "Green Slime": "Slimes", "Frost Jelly": "Slimes", "Sludge": "Slimes",
            "Shadow Brute": "Void Spirits", "Shadow Shaman": "Void Spirits",
            "Shadow Guy": "Void Spirits", "Shadow Girl": "Void Spirits",
            "Bat": "Bats", "Frost Bat": "Bats", "Lava Bat": "Bats",
            "Skeleton": "Skeletons", "Skeleton Mage": "Skeletons",
            "Bug": "Cave Insects", "Fly": "Cave Insects", "Grub": "Cave Insects",
            "Duggy": "Duggies", "Dust Spirit": "Dust Sprites",
        ]
        var monsters: [String: [String]] = [
            "Slimes": ["Green Slime", "Frost Jelly", "Sludge"],
            "Void Spirits": ["Shadow Brute", "Shadow Shaman"],
            "Bats": ["Bat", "Frost Bat", "Lava Bat"],
            "Skeletons": ["Skeleton"],
            "Cave Insects": ["Bug", "Cave Fly", "Grub"],
            "Duggies": ["Duggy"],
            "Dust Sprites": ["Dust Spirit"],
        ]
        if info.isAtLeast("1.4") {
            goals += [("Rock Crabs", 60), ("Mummies", 100), ("Pepper Rex", 50), ("Serpents", 250)]
            categories["Rock Crab"] = "Rock Crabs"; categories["Lava Crab"] = "Rock Crabs"; categories["Iridium Crab"] = "Rock Crabs"
            categories["Mummy"] = "Mummies"; categories["Pepper Rex"] = "Pepper Rex"; categories["Serpent"] = "Serpents"
            monsters["Rock Crabs"] = ["Rock Crab", "Lava Crab", "Iridium Crab"]
            monsters["Mummies"] = ["Mummy"]; monsters["Pepper Rex"] = ["Pepper Rex"]; monsters["Serpents"] = ["Serpent"]
        }
        if info.isAtLeast("1.5") {
            goals.append(("Flame Spirits", 150))
            categories["Magma Sprite"] = "Flame Spirits"; categories["Magma Sparker"] = "Flame Spirits"
            monsters["Flame Spirits"] = ["Magma Sprite", "Magma Sparker"]
            categories["Tiger Slime"] = "Slimes"; monsters["Slimes"]!.append("Tiger Slime")
            categories["Shadow Sniper"] = "Void Spirits"; monsters["Void Spirits"]!.append("Shadow Sniper")
            categories["Magma Duggy"] = "Duggies"; monsters["Duggies"]!.append("Magma Duggy")
            categories["Iridium Bat"] = "Bats"; monsters["Bats"]!.append("Iridium Bat")
            categories["Royal Serpent"] = "Serpents"; monsters["Serpents"]!.append("Royal Serpent")
            monsters["Skeletons"]!.append("Skeleton Mage")
        }
        if info.isAtLeast("1.6") {
            goals = goals.map { $0.0 == "Cave Insects" ? ("Cave Insects", 80) : $0 }
        }

        return playerSection(title: "Monster Hunting", version: "1.2") { player, meta in
            let umid = info.umid(of: player)
            let farmer = playerName(player)
            var mineLevel = num(player.childText("deepestMineLevel"))
            let hasSkullKey = player.childText("hasSkullKey")
            if hasSkullKey == "true" { mineLevel = max(120, mineLevel) }

            var cells: [Cell] = []
            var c1 = Cell()
            if mineLevel <= 0 {
                c1.summary.append(.result(RichText("\(farmer) has not yet explored the mines.")))
            } else {
                c1.summary.append(.result(RichText("\(farmer) has reached level \(min(mineLevel, 120)) of the mines.")))
                c1.summary.append(.result(RichText(farmer + (mineLevel > 120 ? " has reached level \(mineLevel - 120) of the Skull Cavern" : " has not yet explored the Skull Cavern") + ".")))
            }
            cells.append(c1)
            var c2 = Cell()
            c2.summary.append(.achList([
                (mineLevel >= 120 ? Fmt.achieve("The Bottom", "reach mine level 120", true)
                    : Fmt.achieve("The Bottom", "reach mine level 120", false) + "\(120 - mineLevel) more").progress(min(mineLevel, 120), 120),
            ]))
            cells.append(c2)

            if info.isAtLeast("1.6") {
                let total = info.data[umid]?.stat("monstersKilled") ?? 0
                var c3 = Cell()
                c3.summary.append(.result(RichText("\(farmer) has killed \(addCommas(total)) monsters")))
                c3.summary.append(.achList([
                    (total >= 1000 ? Fmt.milestone("Gain access to the Adventure Guild back room", true)
                        : Fmt.milestone("Gain access to the Adventure Guild back room", false) + "to kill \(1000 - total) more monsters").progress(total, 1000),
                ]))
                cells.append(c3)
            }

            let stats: XNode? = info.isAtLeast("1.3") ? player.first("stats > specificMonstersKilled")
                : player.parent?.first("stats > specificMonstersKilled")
            var killed: [String: Int] = [:]
            for item in stats?.children("item") ?? [] {
                let id = item.text("key > string")
                let n = num(item.text("value > int"))
                if let cat = categories[id], n > 0 {
                    killed[cat, default: 0] += n
                }
            }
            var completed = 0
            var need: [DetailItem] = []
            for (goal, target) in goals {
                let have = killed[goal] ?? 0
                if have >= target {
                    completed += 1
                } else {
                    var line = RichText("\(goal) -- kill \(target - have) more of: ")
                    for (i, m) in (monsters[goal] ?? []).enumerated() {
                        if i > 0 { line += ", " }
                        line += wikify(m)
                    }
                    need.append(DetailItem(line))
                }
            }
            var ptPct = RichText()
            if info.isAtLeast("1.5") {
                info.perfection.set(umid, "Monsters", completed >= goals.count)
                ptPct = Fmt.ptLink(completed >= goals.count ? "Yes" : "No")
            }
            var c4 = Cell()
            c4.summary.append(.result("\(farmer) has completed \(completed) of the \(goals.count) Monster Eradication goals.".rt + ptPct))
            c4.summary.append(.achList([
                (completed >= goals.count ? Fmt.achieve("Protector of the Valley", "all monster goals", true)
                    : Fmt.achieve("Protector of the Valley", "all monster goals", false) + "\(goals.count - completed) more").progress(completed, goals.count),
            ]))
            if !need.isEmpty {
                meta.hasDetails = true
                c4.details.append(.need(RichText("Goals left:"), Checkup.sortedItems(need), ordered: true))
            }
            cells.append(c4)
            return cells
        }
    }

    // MARK: Stardrops

    func parseStardrops() -> Section {
        let stardrops: [(String, String)] = [
            ("CF_Fair", "Purchased at the Fair for 2000 star tokens."),
            ("CF_Mines", "Found in the chest on mine level 100."),
            ("CF_Spouse", "Given by NPC spouse at 12.5 hearts (3125 points)."),
            ("CF_Sewer", "Purchased from Krobus in the Sewers for 20,000g."),
            ("CF_Statue", "Received from Old Master Cannoli in the Secret Woods."),
            ("CF_Fish", "Mailed by Willy after Master Angler achievement."),
            ("museumComplete", "Reward for completing the Museum collection."),
        ]
        return playerSection(title: "Stardrops", version: "1.2") { player, meta in
            let umid = info.umid(of: player)
            let pd = info.data[umid]!
            var count = 0
            var need: [DetailItem] = []
            for (id, desc) in stardrops {
                let altTrigger = (id == "CF_Mines" && pd.chestConsumedMineLevels[100] == "true")
                if pd.hasMail(id) || altTrigger {
                    count += 1
                } else {
                    need.append(DetailItem(desc))
                }
            }
            let staminaOverride = pd.hasMail("gotMaxStamina")
            var ptPct = RichText()
            if info.isAtLeast("1.5") {
                info.perfection.set(umid, "Stardrops", count >= stardrops.count)
                ptPct = Fmt.ptLink((staminaOverride || count >= stardrops.count) ? "Yes" : "No")
            }
            let name = info.playerName(umid)
            var cell = Cell()
            cell.summary.append(.result(RichText("\(name) has \(staminaOverride ? "" : "not ")reached 508 max stamina (actual amount \(pd.maxStamina))")))
            if staminaOverride && count < stardrops.count {
                cell.summary.append(.note(RichText("Note: Stamina will override stardrop marker count for achievements and perfection.")))
            }
            cell.summary.append(.result("\(name) has markers for \(count) of \(stardrops.count) stardrops.".rt + ptPct))
            cell.summary.append(.achList([
                (count >= stardrops.count ? Fmt.achieve("Mystery Of The Stardrops", "find every stardrop", true)
                    : Fmt.achieve("Mystery Of The Stardrops", "find every stardrop", false) + "\(stardrops.count - count) more").progress(count, stardrops.count),
            ]))
            if !need.isEmpty {
                meta.hasDetails = true
                cell.details.append(.need(RichText("Stardrops left:"), Checkup.sortedItems(need), ordered: true))
            }
            return [cell]
        }
    }
}
