import Foundation

extension Checkup {

    // MARK: Event Planner

    /// What is left to do for every villager's heart events, and what it takes.
    func parseEventPlanner() -> Section {
        var section = Section(title: "Event Planner", version: "1.3")
        let spouse = hostPlayer.child("spouse")?.text ?? ""
        var data = EventPlanData(spouse: spouse.isEmpty ? nil : spouse)
        var readyTotal = 0, lockedTotal = 0, seenTotal = 0, trackedTotal = 0, impossibleTotal = 0

        for info in CharacterData.all {
            var st = hostCharacterStatus[info.name] ?? CharacterStatus(name: info.name)
            st.eventStates = hostEventStates
            st.eventsSeen = self.info.host.eventsSeen
            var row = EventPlanRow(name: info.name)
            row.hearts = st.hearts
            row.points = st.points
            row.maxHearts = st.maxHearts
            row.lockedFrom = st.lockedFrom
            row.status = st.status
            row.isMet = st.isMet
            row.isMarriageCandidate = info.isMarriageCandidate
            let ideas = hostGiftSuggestions[info.name] ?? GiftSuggestions()
            let best = ideas.loves.first ?? ideas.likes.first
            let bestPoints = best?.points() ?? 80

            for event in info.heartEvents where !event.isMail {
                guard let state = st.state(of: event) else { continue }
                row.totalTracked += 1
                if state == .yes { row.seenCount += 1; continue }
                let need = event.hearts ?? 0
                var step = EventStep(kind: .ready, hearts: event.hearts, title: event.title, trigger: event.trigger, anchor: event.anchor)
                if state == .imp {
                    // Social marks dating-only and marriage-only events impossible; say what would unlock them instead.
                    if need == 10, st.isDatable, st.status == "Friendly" || st.status == "Unmet" {
                        step.kind = .bouquet
                    } else if need >= 14, spouse.isEmpty, info.isMarriageCandidate || info.marriage == "roommate" {
                        step.kind = .marriage
                    } else {
                        step.kind = .impossible
                    }
                } else if st.hearts < need || (need == 0 && st.points < 50) {
                    step.kind = .locked
                    let target = need == 0 ? 50 : need * 250
                    step.pointsNeeded = max(0, target - st.points)
                    step.giftsNeeded = Int((Double(step.pointsNeeded) / Double(bestPoints)).rounded(.up))
                    step.bestGift = best?.name
                    step.bestGiftPoints = bestPoints
                    // Hearts above 8 need a bouquet for datable villagers.
                    if let lock = st.lockedFrom, need > lock, st.isDatable, st.status == "Friendly" {
                        step.kind = .bouquet
                    }
                }
                switch step.kind {
                case .ready: readyTotal += 1
                case .locked, .bouquet, .marriage: lockedTotal += 1
                case .impossible: impossibleTotal += 1
                }
                row.steps.append(step)
            }
            row.steps.sort { a, b in
                func rank(_ k: EventStep.Kind) -> Int {
                    switch k { case .ready: return 0; case .locked: return 1; case .bouquet: return 2; case .marriage: return 3; case .impossible: return 4 }
                }
                if rank(a.kind) != rank(b.kind) { return rank(a.kind) < rank(b.kind) }
                return (a.hearts ?? 0) < (b.hearts ?? 0)
            }
            seenTotal += row.seenCount
            trackedTotal += row.totalTracked
            data.rows.append(row)
        }

        var cell = Cell()
        let farmer = info.playerName(info.farmerId)
        cell.summary.append(.result(RichText("\(farmer) has seen \(seenTotal) of \(trackedTotal) tracked heart events.")))
        cell.summary.append(.result(RichText("\(readyTotal) event(s) can be triggered at the current heart levels; \(lockedTotal) need more hearts, a bouquet or a wedding; \(impossibleTotal) can no longer happen.")))
        let ready = data.rows.filter { $0.readyCount > 0 }.map { "\($0.name) (\($0.readyCount))" }
        if !ready.isEmpty {
            cell.summary.append(.result(RichText("Ready now: " + ready.joined(separator: ", "))))
        }
        cell.summary.append(.explain(RichText("Friendship: 250 points per heart. Talking gives +20 a day, a loved gift +80 (×8 on a birthday), a liked gift +45; gift estimates use the best item you own for that villager.")))
        cell.details.append(.eventPlan(data))
        section.hasDetails = true
        section.globalCells = [cell]
        return section
    }
}
