import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: Binding(get: { model.autoReload }, set: { model.autoReload = $0 })) {
                    Label("Auto-reload", systemImage: "arrow.triangle.2.circlepath")
                }
                .toggleStyle(.button)
                .help(model.autoReload ? "Reloading automatically whenever the game saves (click to pause)" : "Auto-reload paused (click to resume)")
                Button {
                    model.reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(model.report == nil)
                .help("Reload the current save (⌘R)")
                savesMenu
                Button {
                    model.presentOpenPanel()
                } label: {
                    Label("Open Save…", systemImage: "folder")
                }
                .help("Choose a save file (⌘O)")
            }
        }
        .navigationTitle(model.report.map { "\($0.farmName) Farm" } ?? "Checkup for Stardew Valley")
        .navigationSubtitle(subtitle)
        .sheet(isPresented: Binding(get: { model.showAcknowledgements }, set: { model.showAcknowledgements = $0 })) {
            AcknowledgementsView()
        }
        .alert("Save Parse Error", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var subtitle: String {
        guard let report = model.report else { return "" }
        var parts = [report.summaryLine]
        if let t = model.lastLoaded { parts.append("loaded \(t.formatted(date: .omitted, time: .shortened))") }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: Binding(get: { model.selectedSection }, set: { model.selectedSection = $0 })) {
            if let report = model.report {
                Label("Overview", systemImage: "square.grid.2x2")
                    .tag(AppModel.overviewID)
                Label("All Sections", systemImage: "list.bullet.rectangle.portrait")
                    .tag(AppModel.allSectionsID)
                ForEach(SectionGroup.allCases) { group in
                    let sections = report.sections.filter { SectionGroup.group(for: $0.id) == group }
                    if !sections.isEmpty {
                        SwiftUI.Section {
                            ForEach(sections) { section in
                                HStack {
                                    Label {
                                        Text(section.title).lineLimit(1)
                                    } icon: {
                                        Image(systemName: SectionGroup.symbol(for: section.id))
                                    }
                                    Spacer()
                                    StatusBadge(status: SectionStatus(section: section), compact: true)
                                }
                                .tag(section.id)
                            }
                        } header: {
                            Label(group.rawValue, systemImage: group.symbol)
                        }
                    }
                }
            }
            SwiftUI.Section("Output Preferences") {
                prefPicker("Old Sections", selection: Binding(get: { model.prefOld }, set: { model.prefOld = $0 }))
                prefPicker("New Sections (1.6)", selection: Binding(get: { model.prefNew }, set: { model.prefNew = $0 }))
            }
        }
        .listStyle(.sidebar)
    }

    private func prefPicker(_ title: String, selection: Binding<OutputPref>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(OutputPref.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private var savesMenu: some View {
        Menu {
            if model.saves.isEmpty {
                Text(model.needsFolderGrant ? "Grant access to your Saves folder first" : "No saves found in ~/.config/StardewValley/Saves")
            }
            if SaveAccess.isSandboxed {
                Button(model.needsFolderGrant ? "Grant Access to Saves Folder…" : "Change Saves Folder…") { model.grantSavesFolder() }
            }
            ForEach(model.saves) { save in
                Button(save.name) { model.load(url: save.url) }
            }
            Divider()
            Button("Refresh List") { model.refreshSaves() }
        } label: {
            Label("Saves", systemImage: "list.bullet.rectangle")
        }
        .help("Saves found in the default Stardew Valley save folder")
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if model.isLoading {
                ProgressView("Working…").padding(30).background(Theme.panel, in: RoundedRectangle(cornerRadius: 15))
            } else if let report = model.report {
                reportView(report)
            } else {
                welcome
            }
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Panel {
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.circle.fill").font(.system(size: 42)).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Checkup for Stardew Valley").font(.largeTitle.bold()).fontDesign(.rounded)
                            Text("Achievement and completion report for a Stardew Valley save").foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Text("This app checks a Stardew Valley save file for various achievements and milestones and lets you know what is missing. It checks progress on 46 achievements as well as other progression and completion mechanics including Grandpa's evaluation, Ginger Island upgrades, Perfection, and social relationships.")
                    Text("If you load a 1.6 save, expect to see spoilers. The Output Preferences in the sidebar can hide the summary and/or details of sections; \"New Sections\" are those added for Stardew 1.6.")
                        .italic()
                    HStack(spacing: 10) {
                        Text("Based on MouseyPounds' Stardew Checkup web app. An independent fan project, not affiliated with ConcernedApe.")
                            .font(.callout).foregroundStyle(Theme.secondaryText)
                        Button("Acknowledgements") { model.showAcknowledgements = true }
                            .buttonStyle(.link).font(.callout)
                    }
                }
                Panel {
                    Text("Choose Save File").font(.title2.bold()).fontDesign(.rounded)
                    Text("Please use the full save file named with your farmer's name (or farm name) and an ID number (e.g. Fred_148093307); do not use the SaveGameInfo file as it does not contain all the necessary information.")
                    Text("Default save file location on macOS: ~/.config/StardewValley/Saves/").font(.system(.body, design: .monospaced))
                    HStack(spacing: 10) {
                        Button("Open Save File…") { model.presentOpenPanel() }
                            .keyboardShortcut(.defaultAction)
                        if SaveAccess.isSandboxed {
                            Button(model.needsFolderGrant ? "Grant Access to Saves Folder…" : "Change Saves Folder…") { model.grantSavesFolder() }
                        }
                    }
                    if model.needsFolderGrant {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lock.shield").foregroundStyle(Theme.accent)
                            Text("To list your saves automatically and reload them while you play, grant the app access to your Saves folder once. Nothing is uploaded or modified; the app only reads save files.")
                                .font(.callout)
                        }
                    }
                    if !model.saves.isEmpty {
                        Text("Saves found on this Mac").font(.headline).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(model.saves) { save in
                                Button {
                                    model.load(url: save.url)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text(save.name)
                                        Spacer()
                                        Text(save.modified, style: .date).foregroundStyle(Theme.secondaryText)
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.panelAlt, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private func reportView(_ report: Report) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if model.selectedSection == AppModel.overviewID || model.selectedSection == nil {
                        Panel {
                            DashboardView(report: report)
                        }
                        .id(AppModel.overviewID)
                    } else if model.selectedSection == AppModel.allSectionsID {
                        Panel {
                            ForEach(Array(report.sections.enumerated()), id: \.element.id) { i, section in
                                if i > 0 { Divider().overlay(Theme.border.opacity(0.35)) }
                                SectionView(section: section, playerNames: report.playerNames)
                                    .id(section.id)
                            }
                        }
                    } else if let section = report.sections.first(where: { $0.id == model.selectedSection }) {
                        Panel {
                            SectionView(section: section, playerNames: report.playerNames, standalone: true)
                        }
                        .id(section.id)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: model.scrollTarget) { _, target in
                guard let target else { return }
                withAnimation { proxy.scrollTo(target, anchor: .top) }
                model.scrollTarget = nil
            }
            .safeAreaInset(edge: .bottom) {
                if report.playerNames.count > 1 {
                    playerBar(report)
                }
            }
        }
    }

    /// Bottom bar for toggling player columns on multiplayer saves.
    private func playerBar(_ report: Report) -> some View {
        HStack(spacing: 6) {
            Text("Toggle Player Display:").foregroundStyle(Theme.playerBarText).bold()
            ForEach(Array(report.playerNames.enumerated()), id: \.offset) { i, name in
                let on = !model.hiddenPlayers.contains(i)
                Button(name) { model.togglePlayer(i) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(on ? Theme.playerOn : Theme.playerBar)
                    .foregroundStyle(on ? Theme.playerBarText : Theme.playerOff)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.playerBarText, lineWidth: 2))
            }
        }
        .padding(6)
        .background(Theme.playerBar)
    }
}

/// Parchment panel with a wood-brown rounded border.
struct Panel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .foregroundStyle(Theme.text)
            .padding(.vertical, 14).padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 3))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            .padding(2)
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Picker("Old sections", selection: Binding(get: { model.prefOld }, set: { model.prefOld = $0 })) {
                ForEach(OutputPref.allCases) { Text($0.label).tag($0) }
            }
            Picker("New sections (1.6)", selection: Binding(get: { model.prefNew }, set: { model.prefNew = $0 })) {
                ForEach(OutputPref.allCases) { Text($0.label).tag($0) }
            }
            Text("The summary lists whether an achievement/goal has been met; the details are things like the NPC event checklist or the full list of still-needed items.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }
}
