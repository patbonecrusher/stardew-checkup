import SwiftUI

/// Characters section details: a roster on the left and one reference page per villager on the right.
struct CharactersView: View {
    let data: CharactersData
    @State private var selected: String
    @State private var filter = ""
    @State private var onlyCandidates = false

    init(data: CharactersData) {
        self.data = data
        var initial = CharacterData.all.first { $0.birthday.season == data.season && $0.birthday.day == data.day }?.name
            ?? CharacterData.all.first?.name ?? ""
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--character"), i + 1 < args.count, CharacterData.info(for: args[i + 1]) != nil {
            initial = args[i + 1]
        }
        _selected = State(initialValue: initial)
    }

    /// Seen/not seen/impossible for a wiki heart event, from the Social section's event table.
    static func state(of event: CharacterInfo.HeartEvent, in status: CharacterStatus) -> MarkState? {
        guard !event.idKeys.isEmpty else { return nil }
        let states = event.idKeys.compactMap { status.eventStates[$0] }
        guard states.count == event.idKeys.count else { return nil }
        if states.allSatisfy({ $0 == .yes }) { return .yes }
        if states.contains(.imp) { return .imp }
        return .no
    }

    private var roster: [CharacterInfo] {
        CharacterData.all.filter { info in
            (!onlyCandidates || info.isMarriageCandidate) &&
            (filter.isEmpty || info.name.localizedCaseInsensitiveContains(filter))
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            rosterColumn
                .frame(width: 230)
            Rectangle().fill(Theme.border.opacity(0.3)).frame(width: 1)
            if let info = CharacterData.info(for: selected) {
                CharacterPage(info: info, status: data.status(of: info.name), data: data) { selected = $0 }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                Text("Choose a villager").foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.leading, 22)
        .padding(.bottom, 4)
    }

    private var rosterColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search villagers", text: $filter)
                .textFieldStyle(.roundedBorder)
            Toggle("Marriage candidates only", isOn: $onlyCandidates)
                .toggleStyle(.checkbox).font(.caption).foregroundStyle(Theme.secondaryText)
            let candidates = roster.filter(\.isMarriageCandidate)
            let others = roster.filter { !$0.isMarriageCandidate }
            if !candidates.isEmpty { rosterGroup("Marriage Candidates", candidates) }
            if !others.isEmpty { rosterGroup("Townspeople", others) }
        }
    }

    private func rosterGroup(_ title: String, _ list: [CharacterInfo]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                .padding(.top, 6).padding(.leading, 4)
            ForEach(list) { info in
                RosterRow(info: info, status: data.status(of: info.name), isSelected: info.name == selected,
                          isBirthday: info.birthday.season == data.season && info.birthday.day == data.day)
                    .onTapGesture { selected = info.name }
            }
        }
    }
}

private struct RosterRow: View {
    let info: CharacterInfo
    let status: CharacterStatus
    let isSelected: Bool
    let isBirthday: Bool

    var body: some View {
        HStack(spacing: 6) {
            Avatar(name: info.name, size: 22)
            Text(info.name).font(.body.weight(isSelected ? .semibold : .regular)).lineLimit(1)
            if isBirthday {
                Image(systemName: "birthday.cake.fill").font(.caption).foregroundStyle(Theme.heart)
                    .help("Birthday today")
            }
            Spacer(minLength: 2)
            if status.isMet {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill").font(.system(size: 9)).foregroundStyle(Theme.heart)
                    Text("\(status.hearts)").font(.caption).monospacedDigit()
                }
                .foregroundStyle(Theme.secondaryText)
            } else {
                Text("unmet").font(.caption2).foregroundStyle(Theme.secondaryText.opacity(0.7))
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(isSelected ? Theme.accent.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .foregroundStyle(Theme.text)
    }
}

/// Initial-letter badge standing in for the villager portrait.
private struct Avatar: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
            .frame(width: size, height: size)
            .background(Theme.accent.opacity(0.85), in: Circle())
            .foregroundStyle(.white)
    }
}

// MARK: - Page

private struct CharacterPage: View {
    let info: CharacterInfo
    let status: CharacterStatus
    let data: CharactersData
    let select: (String) -> Void
    @State private var scheduleGroup = ""

    private var isBirthdayToday: Bool { info.birthday.season == data.season && info.birthday.day == data.day }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            friendship
            schedule
            gifts.id("Characters_gifts")
            heartEvents.id("Characters_events")
            footer
        }
        .onAppear { scheduleGroup = defaultScheduleGroup }
        .onChange(of: info.name) { _, _ in scheduleGroup = defaultScheduleGroup }
    }

    // Header -----------------------------------------------------------------

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(name: info.name, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let url = info.wikiURL {
                        Link(info.name, destination: url).foregroundStyle(Theme.text)
                    } else {
                        Text(info.name)
                    }
                    if info.isMarriageCandidate {
                        tag("Marriage candidate", "heart.circle.fill", Theme.heart)
                    } else if info.marriage == "roommate" {
                        tag("Can be a roommate", "house.circle.fill", Theme.heart)
                    }
                    if let spouse = data.spouse, spouse == info.name {
                        tag("Your spouse", "rings.fill", Theme.yes)
                    }
                }
                .font(.title.weight(.bold)).fontDesign(.rounded)
                Text(info.role).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Label {
                        Text("\(info.birthday.season) \(info.birthday.day)")
                        if isBirthdayToday {
                            Text("today!").font(.caption.weight(.bold)).foregroundStyle(Theme.heart)
                        }
                    } icon: {
                        Image(systemName: "birthday.cake.fill").foregroundStyle(Theme.heart)
                    }
                    Label(info.address + (info.livesIn.isEmpty ? "" : " · \(info.livesIn)"), systemImage: "house.fill")
                    if !info.clinic.isEmpty {
                        Label(info.clinic, systemImage: "stethoscope").help("Annual check-up at Harvey's Clinic")
                    }
                }
                .font(.callout).foregroundStyle(Theme.text)
                if !info.family.isEmpty {
                    HStack(spacing: 6) {
                        Text("Family:").font(.callout).foregroundStyle(Theme.secondaryText)
                        ForEach(info.family) { rel in
                            Button {
                                if CharacterData.info(for: rel.name) != nil { select(rel.name) }
                            } label: {
                                Text("\(rel.name) (\(rel.relation))").font(.callout)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Theme.panelAlt, in: Capsule())
                                    .overlay(Capsule().stroke(Theme.border.opacity(0.4), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .help("Open \(rel.name)")
                        }
                    }
                }
            }
        }
    }

    private func tag(_ text: String, _ symbol: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    // Friendship -------------------------------------------------------------

    private var friendship: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Your friendship", "person.2.fill")
            if status.isMet {
                HStack(spacing: 14) {
                    Text(status.status).font(.body.weight(.semibold)).foregroundStyle(statusColor)
                    HeartMeter(filled: status.hearts, total: status.maxHearts, lockedFrom: status.lockedFrom)
                    Text("\(status.hearts)♥ · \(status.points) pts").font(.callout).monospacedDigit().foregroundStyle(Theme.secondaryText)
                    RichTextView(text: status.need, baseFont: .callout)
                }
                HStack(spacing: 16) {
                    let giftCap = isBirthdayToday ? 2 : 2
                    Label {
                        Text("\(status.giftsThisWeek)/\(giftCap) gifts this week")
                    } icon: {
                        Image(systemName: status.giftsThisWeek >= giftCap ? "gift.fill" : "gift")
                            .foregroundStyle(status.giftsThisWeek >= giftCap ? Theme.secondaryText : Theme.yes)
                    }
                    .help("Villagers accept two gifts per week (Monday to Sunday), plus one on their birthday")
                    Label {
                        Text(status.talkedToday ? "Talked today" : "Not talked to today")
                    } icon: {
                        Image(systemName: status.talkedToday ? "bubble.left.fill" : "bubble.left")
                            .foregroundStyle(status.talkedToday ? Theme.yes : Theme.secondaryText)
                    }
                    if isBirthdayToday {
                        Label {
                            Text(status.birthdayGiftedThisYear ? "Birthday gift given" : "Birthday gift not given yet (8× friendship)")
                        } icon: {
                            Image(systemName: status.birthdayGiftedThisYear ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(status.birthdayGiftedThisYear ? Theme.yes : Theme.heart)
                        }
                    }
                }
                .font(.callout).foregroundStyle(Theme.text)
            } else {
                Text("Not met yet.").foregroundStyle(Theme.no)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelAlt.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch status.status {
        case "Married", "Roommate", "Dating", "Engaged": return Theme.yes
        case "Unmet", "Divorced": return Theme.no
        default: return Theme.text
        }
    }

    // Schedule ---------------------------------------------------------------

    private var defaultScheduleGroup: String {
        let titles = info.schedule.map(\.title)
        if data.spouse == info.name, titles.contains("Marriage") { return "Marriage" }
        if titles.contains(data.season) { return data.season }
        return titles.first ?? ""
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Where to find \(info.name)", "map.fill")
            ForEach(info.scheduleNotes, id: \.self) { note in
                Text(note).font(.callout).italic().foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if info.schedule.count > 1 {
                Picker("", selection: $scheduleGroup) {
                    ForEach(info.schedule) { g in Text(g.title).tag(g.title) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
            if let group = info.schedule.first(where: { $0.title == scheduleGroup }) ?? info.schedule.first {
                let likely = likelyCondition(in: group)
                if group.conditions.count > 1 {
                    Text("Schedules are listed from highest to lowest priority: the first one whose conditions hold is the one in effect.")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                }
                ForEach(group.conditions) { cond in
                    ScheduleConditionView(condition: cond, isLikely: cond.id == likely?.id,
                                          isForToday: group.title == data.season || group.title == "All" || group.title == "Marriage")
                }
            }
        }
    }

    /// First schedule whose title matches today's weekday, date or weather; falls back to the regular one.
    private func likelyCondition(in group: CharacterInfo.ScheduleGroup) -> CharacterInfo.ScheduleCondition? {
        guard group.title == data.season || group.title == "All" || group.title == "Marriage" else { return nil }
        for cond in group.conditions where matchesToday(cond.title) { return cond }
        return group.conditions.first { $0.title.lowercased().hasPrefix("regular") } ?? (group.conditions.count == 1 ? group.conditions.first : nil)
    }

    private func matchesToday(_ title: String) -> Bool {
        var t = title.lowercased()
        t = t.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
        if t.contains("green rain") { return false }
        if t.contains("rain") { return data.isRaining }
        if t.contains(data.weekday.lowercased()) { return true }
        if t.contains(data.season.lowercased()) {
            let numbers = t.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            return numbers.contains(data.day)
        }
        return false
    }

    // Gifts ------------------------------------------------------------------

    private var gifts: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Gift tastes", "gift.fill")
            GiftTierView(title: "Loves", symbol: "heart.fill", color: Theme.heart, tier: info.gifts.love, expanded: true)
            GiftTierView(title: "Likes", symbol: "hand.thumbsup.fill", color: Theme.yes, tier: info.gifts.like, expanded: true)
            GiftTierView(title: "Neutral", symbol: "minus.circle.fill", color: Theme.secondaryText, tier: info.gifts.neutral, expanded: false)
            GiftTierView(title: "Dislikes", symbol: "hand.thumbsdown.fill", color: Theme.accent, tier: info.gifts.dislike, expanded: false)
            GiftTierView(title: "Hates", symbol: "xmark.octagon.fill", color: Theme.no, tier: info.gifts.hate, expanded: false)
            HStack(spacing: 4) {
                Text("Every villager also follows the").font(.caption).foregroundStyle(Theme.secondaryText)
                Link("universal gift tastes", destination: URL(string: "https://stardewvalleywiki.com/Friendship#Gifts")!).font(.caption)
                Text("unless listed as an exception above.").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    // Heart events -----------------------------------------------------------

    private var heartEvents: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Heart events", "sparkles")
            if info.heartEvents.isEmpty {
                Text("No heart events.").font(.callout).foregroundStyle(Theme.secondaryText)
            }
            ForEach(info.heartEvents) { event in
                HeartEventRow(event: event, state: CharactersView.state(of: event, in: status), wikiPage: info.name)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle").foregroundStyle(Theme.secondaryText)
            Text("Facts from the Stardew Valley Wiki (CC BY-NC-SA 3.0).").foregroundStyle(Theme.secondaryText)
            if let url = info.wikiURL {
                Link("Open \(info.name)'s wiki page", destination: url)
            }
        }
        .font(.caption)
    }

    private func sectionTitle(_ text: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
            Text(text).font(.headline).fontDesign(.rounded)
        }
        .foregroundStyle(Theme.text)
    }
}

// MARK: - Pieces

private struct ScheduleConditionView: View {
    let condition: CharacterInfo.ScheduleCondition
    let isLikely: Bool
    let isForToday: Bool
    @State private var isOpen = false
    @State private var didInit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.caption.weight(.bold)).frame(width: 10)
                    Text(condition.title).font(.body.weight(isLikely ? .semibold : .regular))
                    if isLikely {
                        Text(isForToday ? "LIKELY TODAY" : "DEFAULT").font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Theme.yes.opacity(0.2), in: Capsule())
                            .foregroundStyle(Theme.yes)
                    }
                    Spacer()
                    Text("\(condition.rows.count) stops").font(.caption).foregroundStyle(Theme.secondaryText)
                }
                .foregroundStyle(Theme.text)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(condition.rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(row.first ?? "").font(.callout.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                                .frame(width: 70, alignment: .trailing)
                            Text(row.count > 1 ? row[1] : "").font(.callout).foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 16).padding(.bottom, 4)
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(isLikely ? Theme.yes.opacity(0.08) : Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(isLikely ? Theme.yes.opacity(0.5) : Color.clear, lineWidth: 1))
        .onAppear { if !didInit { isOpen = isLikely; didInit = true } }
        .onChange(of: condition.id) { _, _ in isOpen = isLikely }
    }
}

private struct GiftTierView: View {
    let title: String
    let symbol: String
    let color: Color
    let tier: CharacterInfo.GiftTier
    let expanded: Bool
    @State private var isOpen = false
    @State private var didInit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.caption.weight(.bold)).frame(width: 10)
                    Image(systemName: symbol).foregroundStyle(color)
                    Text(title).font(.subheadline.weight(.semibold))
                    Text("\(tier.items.count)").font(.caption).monospacedDigit().foregroundStyle(Theme.secondaryText)
                    Spacer()
                }
                .foregroundStyle(Theme.text)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                ForEach(tier.notes, id: \.self) { note in
                    Text(note).font(.caption).italic().foregroundStyle(Theme.secondaryText).padding(.leading, 16)
                }
                if !tier.items.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 4) {
                        ForEach(tier.items, id: \.self) { item in
                            HStack(spacing: 4) {
                                Circle().fill(color).frame(width: 6, height: 6)
                                if let url = wikify(item).runs.first?.url {
                                    Link(item, destination: url).foregroundStyle(Theme.text)
                                } else {
                                    Text(item)
                                }
                            }
                            .font(.callout).lineLimit(1)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(color.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.leading, 16)
                }
            }
        }
        .onAppear { if !didInit { isOpen = expanded; didInit = true } }
    }
}

private struct HeartEventRow: View {
    let event: CharacterInfo.HeartEvent
    let state: MarkState?
    let wikiPage: String

    private var color: Color {
        switch state {
        case .yes: return Theme.yes
        case .no: return Theme.no
        case .imp: return Theme.impossible
        case nil: return Theme.secondaryText
        }
    }

    private var label: String {
        if event.isMail { return "✉︎" }
        if let h = event.hearts { return "\(h)♥" }
        return "♥"
    }

    private var stateText: String {
        switch state {
        case .yes: return "seen"
        case .no: return "not seen yet"
        case .imp: return "no longer possible"
        case nil: return event.isMail ? "mail" : "not tracked by the save"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption.weight(.bold)).monospacedDigit()
                .frame(width: 42)
                .padding(.vertical, 2)
                .background(color.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
                .foregroundStyle(color)
                .help(stateText)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.title).font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                    if event.isGroup {
                        Text("group").font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                    if let state {
                        Image(systemName: state == .yes ? "checkmark.circle.fill" : (state == .imp ? "minus.circle.fill" : "circle"))
                            .font(.caption).foregroundStyle(color)
                    }
                    Text(stateText).font(.caption).foregroundStyle(color)
                    Spacer()
                    if let url = URL(string: "https://stardewvalleywiki.com/\(wikiPage)#\(event.anchor)") {
                        Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                            .font(.caption).help("Full description on the wiki")
                    }
                }
                Text(event.trigger).font(.callout).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
    }
}
