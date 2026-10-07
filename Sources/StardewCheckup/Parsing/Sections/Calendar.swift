import Foundation

extension Checkup {

    /// Festivals and seasonal events (stardewvalleywiki.com/Calendar, 1.6).
    private static let festivals: [(season: String, start: Int, end: Int, name: String, page: String)] = [
        ("Spring", 13, 13, "Egg Festival", "Egg_Festival"),
        ("Spring", 15, 17, "Desert Festival", "Desert_Festival"),
        ("Spring", 24, 24, "Flower Dance", "Flower_Dance"),
        ("Summer", 11, 11, "Luau", "Luau"),
        ("Summer", 20, 21, "Trout Derby", "Trout_Derby"),
        ("Summer", 28, 28, "Dance of the Moonlight Jellies", "Dance_of_the_Moonlight_Jellies"),
        ("Fall", 16, 16, "Stardew Valley Fair", "Stardew_Valley_Fair"),
        ("Fall", 27, 27, "Spirit's Eve", "Spirit's_Eve"),
        ("Winter", 8, 8, "Festival of Ice", "Festival_of_Ice"),
        ("Winter", 12, 13, "SquidFest", "SquidFest"),
        ("Winter", 15, 17, "Night Market", "Night_Market"),
        ("Winter", 25, 25, "Feast of the Winter Star", "Feast_of_the_Winter_Star"),
    ]
    private static let otherEvents: [(season: String, start: Int, end: Int, name: String, page: String)] = [
        ("Spring", 15, 18, "Salmonberry season", "Salmonberry"),
        ("Summer", 12, 14, "Extra beach forage", "The_Beach"),
        ("Fall", 8, 11, "Blackberry season", "Blackberry"),
    ]
    /// The game's mail flag for having attended a festival at least once.
    private static let festivalFlag: [String: String] = [
        "Egg Festival": "eventSeen_festival_spring13", "Flower Dance": "eventSeen_festival_spring24",
        "Luau": "eventSeen_festival_summer11", "Dance of the Moonlight Jellies": "eventSeen_festival_summer28",
        "Stardew Valley Fair": "eventSeen_festival_fall16", "Spirit's Eve": "eventSeen_festival_fall27",
        "Festival of Ice": "eventSeen_festival_winter8", "Feast of the Winter Star": "eventSeen_festival_winter25",
    ]

    // MARK: Calendar

    func parseCalendar() -> Section {
        var section = Section(title: "Calendar", version: "1.2")
        let season = capitalize(doc.text("currentSeason"))
        let day = num(doc.text("dayOfMonth"))
        let year = num(doc.text("year"))
        let host = info.host
        let ignore: Set<String> = ["Horse", "Cat", "Dog", "Fly", "Grub", "GreenSlime", "Gunther", "Marlon", "Bouncer", "Mister Qi",
                                   "Henchman", "Birdie", "Fizz", "Pet", "Raccoon", "Bat", "Truffle Crab"]

        // Last gift date per villager for the host, to mark birthday gifts given this year.
        var lastGift: [String: (year: Int, season: String, day: Int)] = [:]
        for item in hostPlayer.find("friendshipData > item") {
            let who = item.text("key > string")
            guard let d = item.first("value > Friendship > LastGiftDate") else { continue }
            lastGift[who] = (num(d.childText("Year")), capitalize(d.childText("Season")), num(d.childText("DayOfMonth")))
        }

        var events: [String: [CalendarEvent]] = [:]
        var seen: Set<String> = []
        for loc in doc.find("locations > GameLocation") {
            for npc in loc.find("characters > NPC") {
                let type = npc.attr("\(info.nsPrefix):type") ?? ""
                let who = npc.text("name")
                if ignore.contains(type) || ignore.contains(who) || type == "Child" || seen.contains(who) { continue }
                let bSeason = capitalize(npc.childText("birthday_Season"))
                let bDay = num(npc.childText("birthday_Day"))
                guard CalendarData.seasons.contains(bSeason), bDay >= 1, bDay <= 28 else { continue }
                seen.insert(who)
                var gifted = false
                if let g = lastGift[who], g.year == year, g.season == bSeason, g.day == bDay { gifted = true }
                events[bSeason, default: []].append(CalendarEvent(kind: .birthday, name: who, startDay: bDay, endDay: bDay,
                                                                  url: wikify(who).runs.first?.url, done: gifted))
            }
        }
        for f in Checkup.festivals {
            let attended = Checkup.festivalFlag[f.name].map { host.hasMail($0) } ?? false
            events[f.season, default: []].append(CalendarEvent(kind: .festival, name: f.name, startDay: f.start, endDay: f.end,
                                                               url: wikify(f.name, f.page, noAnchor: true).runs.first?.url, done: attended))
        }
        for o in Checkup.otherEvents {
            events[o.season, default: []].append(CalendarEvent(kind: .other, name: o.name, startDay: o.start, endDay: o.end,
                                                               url: wikify(o.name, o.page, noAnchor: true).runs.first?.url))
        }
        for k in events.keys { events[k]!.sort { $0.startDay == $1.startDay ? $0.name < $1.name : $0.startDay < $1.startDay } }

        // Summary: today plus what is coming up (this season, then the next).
        var cell = Cell()
        cell.summary.append(.result(RichText("Today is day \(day) of \(season), year \(year) (\(28 - day) day(s) left in the season).")))
        var upcoming: [(String, CalendarEvent)] = []
        if let idx = CalendarData.seasons.firstIndex(of: season) {
            for offset in 0..<2 {
                let s = CalendarData.seasons[(idx + offset) % 4]
                for e in events[s] ?? [] where offset > 0 || e.endDay >= day {
                    upcoming.append((s, e))
                }
                if upcoming.count >= 6 { break }
            }
        }
        var lines: [DetailItem] = []
        for (s, e) in upcoming.prefix(6) {
            let when = s == season ? (e.startDay == day ? "today" : e.startDay > day ? "in \(e.startDay - day) day(s)" : "ongoing") : "\(s) \(e.startDay)"
            var t = RichText(e.kind == .birthday ? "\(e.name)'s birthday" : e.name)
            t += " — \(when)"
            if e.done { t += RichText(runs: [Run(text: e.kind == .birthday ? "  gift given" : "  attended before", color: .yes)]) }
            lines.append(DetailItem(t))
        }
        if !lines.isEmpty {
            cell.summary.append(.result(RichText("Coming up:")))
            cell.summary.append(.list(lines, ordered: false))
        }
        let birthdaysThisYear = events.values.flatMap { $0 }.filter { $0.kind == .birthday }
        let giftedCount = birthdaysThisYear.filter(\.done).count
        if giftedCount > 0 {
            cell.summary.append(.result(RichText("\(giftedCount) birthday gift(s) given on the day so far this year.")))
        }
        cell.details.append(.calendar(CalendarData(season: season, day: day, year: year, events: events)))
        section.hasDetails = true
        section.globalCells = [cell]
        return section
    }
}
