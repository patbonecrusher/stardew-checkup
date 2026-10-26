import SwiftUI

struct SectionView: View {
    let section: Section
    let playerNames: [String]
    /// When true the section is shown on its own page (larger title, no anchor needed).
    var standalone = false
    @EnvironmentObject var model: AppModel
    /// Section ids whose page is showing the Planner tab instead of the checkup.
    @AppStorage("planner-tabs") private var plannerTabs = ""

    /// The Planner tab for this section, when it has one.
    private var planner: AnyView? {
        guard let o = model.report?.overview else { return nil }
        switch section.id {
        case "Cooking": return o.cookPlan.map { AnyView(CookingPlannerView(data: $0)) }
        case "Crafting": return o.craftPlan.map { AnyView(CookingPlannerView(data: $0, kind: .crafting)) }
        case "Fishing": return o.fishPlan.map { AnyView(FishPlannerView(data: $0)) }
        case "Basic_Shipping": return o.shipPlan.map { AnyView(ShipPlannerView(data: $0)) }
        case "Crop_Shipping": return o.cropPlan.map { AnyView(CropPlannerView(data: $0)) }
        case "Museum_Collection": return o.museumPlan.map { AnyView(MuseumPlannerView(data: $0)) }
        case "Monster_Hunting": return o.monsterPlan.map { AnyView(MonsterPlannerView(data: $0)) }
        case "Golden_Walnuts": return o.walnutGuide.map { AnyView(WalnutGuideView(data: $0)) }
        case "Community_Center___Joja_Community_Development": return o.bundlePlan.map { AnyView(BundlePlannerView(data: $0)) }
        default: return nil
        }
    }

    private var showPlanner: Bool {
        CommandLine.arguments.contains("--planner") || plannerTabs.split(separator: ",").contains(Substring(section.id))
    }

    private func setPlanner(_ on: Bool) {
        var ids = Set(plannerTabs.split(separator: ",").map(String.init))
        if on { ids.insert(section.id) } else { ids.remove(section.id) }
        plannerTabs = ids.sorted().joined(separator: ",")
    }

    private var showSummary: Bool { model.isSummaryShown(section, standalone: standalone) }
    private var showDetails: Bool { model.isDetailsShown(section, standalone: standalone) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            let planner = planner
            if let planner {
                Picker("", selection: Binding(get: { showPlanner }, set: { setPlanner($0) })) {
                    Label("Checkup", systemImage: SectionGroup.symbol(for: section.id)).tag(false)
                    if section.id == "Golden_Walnuts" {
                        Label("Spoilers", systemImage: "eye").tag(true)
                    } else {
                        Label("Planner", systemImage: "list.bullet.clipboard").tag(true)
                    }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .padding(.leading, 4)
                if showPlanner { planner }
            }
            let onPlanner = planner != nil && showPlanner
            if (showSummary || showDetails) && !onPlanner {
                ForEach(Array(section.globalCells.enumerated()), id: \.offset) { _, cell in
                    CellView(cell: cell, showSummary: showSummary, showDetails: showDetails)
                }
                if !section.columns.isEmpty {
                    playerTable
                }
                ForEach(Array(section.trailingCells.enumerated()), id: \.offset) { _, cell in
                    CellView(cell: cell, showSummary: showSummary, showDetails: showDetails)
                }
            }
            if section.id == "Skills", !onPlanner, let report = model.report {
                SkillXPGuideView(skillXP: report.overview.skillXP, expanded: standalone)
            }
            if section.id == "Books__Special_Items___Powers", let report = model.report {
                PowersGuideView(booksRead: report.overview.booksRead, powersHave: report.overview.powersHave, expanded: standalone)
            }
            if section.id == "Fishing", !onPlanner, let report = model.report {
                FishGuideView(caught: report.overview.fishCaught, currentSeason: report.overview.currentSeason,
                              fishingLevel: FishGuideView.level(forXP: report.overview.skillXP.count > 1 ? report.overview.skillXP[1] : 0),
                              expanded: standalone)
            }
        }
        .padding(.vertical, 6)
    }

    private var header: some View {
        let status = SectionStatus(section: section)
        return HStack(spacing: 10) {
            Image(systemName: SectionGroup.symbol(for: section.id))
                .foregroundStyle(Theme.accent)
                .font(standalone ? .title2 : .title3)
            Text(section.title)
                .font(standalone ? .title.weight(.bold) : .title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Theme.text)
            if section.isNew {
                Text("1.6")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Theme.accent.opacity(0.2), in: Capsule())
                    .foregroundStyle(Theme.accent)
                    .help("Section added for Stardew Valley 1.6 (uses the 'New Sections' output preference)")
            }
            StatusBadge(status: status)
            Spacer()
            Picker("", selection: Binding(get: { visibilityMode }, set: { setVisibility($0) })) {
                Text("Summary").tag(0)
                Text("Details").tag(1)
                Text("Both").tag(2)
                Text("None").tag(3)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()
            .labelsHidden()
            .help(section.hasDetails ? "Choose what to show for this section" : "This section has no details")
        }
    }

    private var visibilityMode: Int {
        switch (showSummary, showDetails) {
        case (true, false): return 0
        case (false, true): return 1
        case (true, true): return 2
        case (false, false): return 3
        }
    }

    private func setVisibility(_ mode: Int) {
        model.setVisibility(section, summary: mode == 0 || mode == 2, details: mode == 1 || mode == 2)
    }

    /// Equivalent of `printTranspose`: one column per player, rows aligned.
    private var playerTable: some View {
        let visible = section.columns.indices.filter { !model.hiddenPlayers.contains($0) }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<section.rowCount, id: \.self) { row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(visible, id: \.self) { p in
                        VStack(alignment: .leading, spacing: 3) {
                            if visible.count > 1 && row == 0 {
                                Label(p < playerNames.count ? playerNames[p] : "Player \(p + 1)", systemImage: "person.fill")
                                    .font(.headline)
                                    .foregroundStyle(Theme.border)
                                    .padding(.leading, 6)
                            }
                            if row < section.columns[p].count {
                                CellView(cell: section.columns[p][row], showSummary: showSummary, showDetails: showDetails)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, visible.count > 1 ? 6 : 0)
                        .overlay(alignment: .leading) {
                            if p != visible.first {
                                Rectangle().fill(Theme.border.opacity(0.4)).frame(width: 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Small pill summarising a section's goals: "3/5", a check when complete, a dash when blocked.
struct StatusBadge: View {
    let status: SectionStatus
    var compact = false

    var body: some View {
        if status.total == 0 {
            EmptyView()
        } else if status.isComplete {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.yes)
                .help("All \(status.total) goals complete")
        } else if status.isBlocked {
            Image(systemName: "minus.circle.fill").foregroundStyle(Theme.impossible)
                .help("Remaining goals are impossible on this save")
        } else {
            Text("\(status.done)/\(status.total)")
                .font(.caption.weight(.semibold)).monospacedDigit()
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Theme.accent.opacity(compact ? 0.25 : 0.18), in: Capsule())
                .foregroundStyle(compact ? .primary : Theme.text)
                .help("\(status.done) of \(status.total) goals complete" + (status.impossible > 0 ? ", \(status.impossible) impossible" : ""))
        }
    }
}
