import Foundation

extension Checkup {

    // MARK: Gift Planner

    /// Who can still take gifts this week, and which loved / liked items the host already owns for them.
    func parseGiftPlanner() -> Section {
        var section = Section(title: "Gift Planner", version: "1.3")
        let season = capitalize(doc.text("currentSeason"))
        let day = num(doc.text("dayOfMonth"))
        let year = num(doc.text("year"))
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let dow = max(0, (day - 1) % 7)
        var data = GiftPlanData(weekday: weekdays[dow], daysUntilReset: 7 - dow)
        data.ownedCount = hostOwnedItems.count
        let spouse = hostPlayer.child("spouse")?.text ?? ""
        let seasons = CalendarData.seasons
        let seasonIdx = seasons.firstIndex(of: season) ?? 0

        var lastGift: [String: (year: Int, season: String, day: Int)] = [:]
        for item in hostPlayer.find("friendshipData > item") {
            let who = item.text("key > string")
            guard let d = item.first("value > Friendship > LastGiftDate") else { continue }
            lastGift[who] = (num(d.childText("Year")), capitalize(d.childText("Season")), num(d.childText("DayOfMonth")))
        }

        for info in CharacterData.all {
            let st = hostCharacterStatus[info.name] ?? CharacterStatus(name: info.name)
            var row = GiftPlanRow(name: info.name)
            row.hearts = st.hearts
            row.maxHearts = st.maxHearts
            row.lockedFrom = st.lockedFrom
            row.isMet = st.isMet
            row.isMaxed = st.need.plain.hasPrefix("MAX")
            row.isSpouse = info.name == spouse
            row.giftsThisWeek = st.giftsThisWeek
            row.talkedToday = st.talkedToday
            // Birthday within the next 7 days (wrapping into next season).
            let bIdx = seasons.firstIndex(of: info.birthday.season) ?? 0
            let offset = ((bIdx - seasonIdx + 4) % 4) * 28 + (info.birthday.day - day)
            if offset >= 0 && offset <= 7 { row.birthdayIn = offset }
            if let g = lastGift[info.name], g.year == year, g.season == info.birthday.season, g.day == info.birthday.day {
                row.birthdayGifted = true
            }
            if let g = lastGift[info.name], g.year == year, g.season == season, g.day == day { row.giftedToday = true }
            row.suggestions = hostGiftSuggestions[info.name] ?? GiftSuggestions()
            row.lovedItems = info.gifts.love.items
            data.rows.append(row)
        }

        let met = data.rows.filter(\.isMet)
        let open = met.filter { $0.slotsLeft > 0 && !$0.isMaxed }
        let withLove = open.filter { !$0.suggestions.loves.isEmpty }
        let withLike = open.filter { $0.suggestions.loves.isEmpty && !$0.suggestions.likes.isEmpty }
        var cell = Cell()
        cell.summary.append(.result(RichText("It is \(data.weekday): the gift week resets in \(data.daysUntilReset) day(s) (gifts given reset every Monday).")))
        cell.summary.append(.result(RichText("\(open.count) villager(s) below max hearts can still take a gift this week; \(met.count - open.count) are done or maxed.")))
        if !open.isEmpty {
            cell.summary.append(.result(RichText("From what you own, \(withLove.count) could get a loved gift and another \(withLike.count) a liked gift (\(hostOwnedItems.count) distinct giftable items found in your inventory, chests, fridges and on the ground).")))
        }
        let birthdays = data.rows.filter { $0.birthdayIn != nil }.sorted { $0.birthdayIn! < $1.birthdayIn! }
        if !birthdays.isEmpty {
            let parts = birthdays.map { r -> String in
                let when = r.birthdayIn == 0 ? "today" : "in \(r.birthdayIn!) day(s)"
                return "\(r.name) (\(when)\(r.birthdayGifted ? ", gift given" : ""))"
            }
            cell.summary.append(.result(RichText("Birthdays this week (loved gift = 8× friendship): " + parts.joined(separator: ", "))))
        }
        cell.details.append(.giftPlan(data))
        section.hasDetails = true
        section.globalCells = [cell]
        return section
    }
}
