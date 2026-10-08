import Foundation

extension Checkup {

    // MARK: Characters

    /// Villager reference pages: static wiki facts combined with the host's friendship data.
    func parseCharacters() -> Section {
        var section = Section(title: "Characters", version: "1.3")
        let season = capitalize(doc.text("currentSeason"))
        let day = num(doc.text("dayOfMonth"))
        let year = num(doc.text("year"))
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var data = CharactersData(season: season, day: day, year: year, weekday: weekdays[max(0, (day - 1) % 7)])

        // Weather: 1.6 keeps it per location context, older saves have a flat flag.
        if let item = doc.find("locationWeather > item").first(where: { $0.text("key > string") == "Default" }) ?? doc.find("locationWeather > item").first {
            data.isRaining = item.text("value > LocationWeather > isRaining > boolean") == "true"
        } else {
            data.isRaining = doc.text("isRaining") == "true"
        }
        let spouse = hostPlayer.child("spouse")?.text ?? ""
        if !spouse.isEmpty { data.spouse = spouse }

        var lastGift: [String: (year: Int, season: String, day: Int)] = [:]
        for item in hostPlayer.find("friendshipData > item") {
            let who = item.text("key > string")
            guard let d = item.first("value > Friendship > LastGiftDate") else { continue }
            lastGift[who] = (num(d.childText("Year")), capitalize(d.childText("Season")), num(d.childText("DayOfMonth")))
        }

        var met = 0
        var maxed = 0
        var birthdaysToday: [String] = []
        var birthdaysSoon: [(String, Int)] = []
        for info in CharacterData.all {
            var st = hostCharacterStatus[info.name] ?? CharacterStatus(name: info.name)
            st.eventStates = hostEventStates
            if let g = lastGift[info.name], g.year == year, g.season == info.birthday.season, g.day == info.birthday.day {
                st.birthdayGiftedThisYear = true
            }
            data.statuses[info.name] = st
            if st.isMet { met += 1 }
            if st.need.plain.hasPrefix("MAX") { maxed += 1 }
            if info.birthday.season == season {
                if info.birthday.day == day { birthdaysToday.append(info.name) }
                else if info.birthday.day > day && info.birthday.day - day <= 7 { birthdaysSoon.append((info.name, info.birthday.day - day)) }
            }
        }

        var cell = Cell()
        let weather = data.isRaining ? "raining" : "not raining"
        cell.summary.append(.result(RichText("Today is \(data.weekday), \(season) \(day) of year \(year), and it is \(weather).")))
        cell.summary.append(.result(RichText("\(info.playerName(info.farmerId)) has met \(met) of \(CharacterData.all.count) villagers and maxed hearts with \(maxed).")))
        if !birthdaysToday.isEmpty {
            var t = RichText("Birthday today: ")
            for (i, who) in birthdaysToday.enumerated() {
                if i > 0 { t += ", " }
                t += wikify(who)
                let gifted = data.statuses[who]?.birthdayGiftedThisYear ?? false
                t += RichText(runs: [Run(text: gifted ? " (gift given)" : " (no gift yet)", color: gifted ? .yes : .no)])
            }
            cell.summary.append(.result(t))
        }
        if !birthdaysSoon.isEmpty {
            let parts = birthdaysSoon.sorted { $0.1 < $1.1 }.map { "\($0.0) in \($0.1) day(s)" }
            cell.summary.append(.result(RichText("Birthdays this week: " + parts.joined(separator: ", "))))
        }
        cell.summary.append(.explain(RichText("Details show one page per villager: where to find them, what they like, and their heart events.")))
        cell.details.append(.characters(data))
        section.hasDetails = true
        section.globalCells = [cell]
        return section
    }
}
