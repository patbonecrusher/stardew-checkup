import Foundation

extension Checkup {

    // MARK: populateData

    @discardableResult
    func populateData(_ player: XNode) -> String {
        var id = "0"
        let name = player.childText("name")
        if info.isAtLeast("1.3") {
            id = player.childText("UniqueMultiplayerID")
        }
        let pd = PlayerData()
        pd.name = name
        pd.umid = id
        let newStatFormat = info.isAtLeast("1.6")
        let statBase: XNode = info.isAtLeast("1.3") ? player : (player.parent ?? player)
        if newStatFormat {
            for item in statBase.find("stats > Values > item") {
                let key = item.text("key > string")
                let value = item.first("value")?.allChildren.first?.text ?? ""
                pd.stats[key] = value
            }
        } else {
            if let stats = statBase.child("stats") {
                for child in stats.allChildren {
                    pd.stats[child.name] = child.text
                }
            }
        }
        for m in player.find("mailReceived > string") { pd.mailReceived.insert(m.text) }
        if let ev = player.child("eventsSeen") {
            for e in ev.allChildren { pd.eventsSeen.insert(e.text) }
        }
        for x in player.find("experiencePoints > int") { pd.experiencePoints.append(num(x.text)) }
        for item in player.find("chestConsumedLevels > item") {
            let key = num(item.text("key > int"))
            let value = item.first("value")?.allChildren.first?.text ?? ""
            pd.chestConsumedMineLevels[key] = value
        }
        pd.maxStamina = num(player.text("maxStamina"))
        info.data[id] = pd
        return id
    }

    // MARK: Summary

    func parseSummary() -> Section {
        var section = Section(title: "Summary", version: "1.2")
        let farmTypes: [String: String] = [
            "0": "Standard", "1": "Riverland", "2": "Forest", "3": "Hill-top", "4": "Wilderness",
            "5": "Four Corners", "6": "Beach", "MeadowlandsFarm": "Meadowlands",
        ]
        let playTime = num(doc.text("player > millisecondsPlayed"))
        let playHr = playTime / 3_600_000
        let playMin = (playTime % 3_600_000) / 60_000

        // Versioning has changed from bools to numbers, to now a semver string.
        info.version = doc.find("gameVersion").first?.text ?? ""
        if info.version.isEmpty {
            info.version = "1.2"
            if doc.text("hasApplied1_4_UpdateChanges") == "true" {
                info.version = "1.4"
            } else if doc.text("hasApplied1_3_UpdateChanges") == "true" {
                info.version = "1.3"
            }
        }
        let versionLabel = doc.find("gameVersionLabel").first?.text ?? ""
        info.versionLabel = versionLabel.isEmpty ? "" : "(\(versionLabel))"

        // Namespace prefix varies by platform; iOS saves use 'p3' and PC saves use 'xsi'.
        info.nsPrefix = (doc.attr("xmlns:xsi") != nil) ? "xsi" : "p3"

        let player = hostPlayer
        let id = populateData(player)
        info.farmerId = id
        let farmer = info.data[id]!.name
        info.players[id] = farmer
        info.playerOrder = [id]
        info.children[id] = []
        for child in doc.find("[@\(info.nsPrefix):type='FarmHouse'] NPC\(info.typeIs("Child"))") {
            info.children[id]!.append(child.text("name"))
        }
        info.numPlayers = 1
        info.farmName = doc.text("player > farmName")

        var summary: [Block] = []
        let farmTypeKey = doc.text("whichFarm")
        summary.append(.result(RichText("\(info.farmName) Farm (\(farmTypes[farmTypeKey] ?? farmTypeKey))")))

        var farmerLine = "Farmer \(farmer)"
        var farmhands: [String] = []
        for fh in info.farmhands(in: doc) {
            info.numPlayers += 1
            let fid = populateData(fh)
            farmhands.append(info.data[fid]!.name)
            info.players[fid] = info.data[fid]!.name
            info.playerOrder.append(fid)
            info.children[fid] = []
        }
        for child in doc.find("indoors\(info.typeIs("Cabin")) NPC\(info.typeIs("Child"))") {
            let pid = child.childText("idOfParent")
            info.children[pid, default: []].append(child.text("name"))
        }
        if info.numPlayers > 1 {
            farmerLine += " and Farmhand(s) " + farmhands.joined(separator: ", ")
        }
        summary.append(.result(RichText(farmerLine)))

        // Marriage between players
        for item in doc.find("farmerFriendships > item") {
            if item.text("value > Friendship > Status") == "Married" {
                let id1 = item.text("key > FarmerPair > Farmer1")
                let id2 = item.text("key > FarmerPair > Farmer2")
                info.partners[id1] = id2
                info.partners[id2] = id1
            }
        }

        info.overview.currentSeason = capitalize(doc.text("currentSeason"))
        summary.append(.result(RichText("Day \(num(doc.text("dayOfMonth"))) of \(capitalize(doc.text("currentSeason"))), Year \(num(doc.text("year")))")))
        var played = "Played for "
        if playHr == 0 && playMin == 0 {
            played += "less than 1 minute"
        } else {
            if playHr > 0 { played += "\(playHr) hr " }
            if playMin > 0 { played += "\(playMin) min " }
        }
        summary.append(.result(RichText(played.trimmingCharacters(in: .whitespaces))))
        summary.append(.result(RichText("Save is from version \(info.version) \(info.versionLabel)".trimmingCharacters(in: .whitespaces))))
        section.globalCells = [Cell(summary: summary)]
        return section
    }

    // MARK: Money

    func parseMoney() -> Section {
        var section = Section(title: "Money", version: "1.2")
        let separateWallets = doc.text("SaveGame > player > useSeparateWallets") == "true"
        let money = num(doc.text("SaveGame > player > totalMoneyEarned"))
        var left = money
        info.overview.money = money

        var cell = Cell()
        cell.summary.append(.result(RichText("\(doc.text("SaveGame > player > farmName")) Farm has earned \(addCommas(money))g.")))
        func ach(_ name: String, _ goal: Int, _ label: String) -> StatusLine {
            (money >= goal ? Fmt.achieve(name, "earn \(label)", true)
                : Fmt.achieve(name, "earn \(label)", false) + "\(addCommas(goal - money))g more").progress(money, goal, label: "\(addCommas(money))g / \(label)")
        }
        cell.summary.append(.achList([
            ach("Greenhorn", 15_000, "15,000g"),
            ach("Cowpoke", 50_000, "50,000g"),
            ach("Homesteader", 250_000, "250,000g"),
            ach("Millionaire", 1_000_000, "1,000,000g"),
            ach("Legend", 10_000_000, "10,000,000g"),
        ]))

        if separateWallets {
            section.hasDetails = true
            var items: [DetailItem] = []
            for id in info.playerOrder {
                let m = info.data[id]?.stat("individualMoneyEarned") ?? 0
                items.append(DetailItem("\(addCommas(m))g earned by \(info.playerName(id))"))
                left -= m
            }
            if left > 0 {
                items.append(DetailItem("(\(addCommas(left))g surplus unexplained)"))
            } else if left < 0 {
                items.append(DetailItem("(\(addCommas(-left))g deficit unexplained)"))
            }
            cell.details.append(.result(RichText("Earnings Breakdown:")))
            cell.details.append(.list(items, ordered: false))
        }
        section.globalCells = [cell]
        return section
    }
}
