import SwiftUI

/// Every chest, fridge and auto-grabber with its contents; search to find which one holds an item.
struct StorageView: View {
    let data: StorageData
    @AppStorage("storage-by-item") private var byItem = false
    @State private var filter = ""
    @State private var hideEmpty = true

    private func matches(_ item: StoredItem) -> Bool {
        filter.isEmpty || item.name.localizedCaseInsensitiveContains(filter)
    }

    private var boxes: [StorageBox] {
        data.boxes.filter { box in
            if filter.isEmpty { return !(hideEmpty && box.items.isEmpty && box.name != "Backpack") }
            return box.label.localizedCaseInsensitiveContains(filter) || box.items.contains(where: matches)
        }
    }

    /// Item name → (total, [(box, count)]), for the by-item view.
    private var itemRows: [(name: String, total: Int, places: [(StorageBox, Int)])] {
        var map: [String: [(StorageBox, Int)]] = [:]
        for box in data.boxes {
            var counts: [String: Int] = [:]
            for i in box.items where matches(i) { counts[i.name, default: 0] += i.count }
            for (n, c) in counts { map[n, default: []].append((box, c)) }
        }
        return map.map { (name: $0.key, total: $0.value.reduce(0) { $0 + $1.1 }, places: $0.value.sorted { $0.1 > $1.1 }) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Picker("", selection: $byItem) {
                    Label("By container", systemImage: "archivebox").tag(false)
                    Label("By item", systemImage: "list.bullet").tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                PlanSearchField(prompt: "Find an item or a chest", text: $filter)
                if !byItem { Toggle("Hide empty containers", isOn: $hideEmpty).toggleStyle(.checkbox) }
                Spacer()
            }
            .font(.callout)
            if byItem { itemList } else { boxGrid }
        }
        .padding(.leading, 22).padding(.bottom, 4)
    }

    private var boxGrid: some View {
        let list = boxes
        return Group {
            if list.isEmpty {
                Text("Nothing matches “\(filter)”.").foregroundStyle(Theme.secondaryText)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 460), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
                ForEach(list) { box in
                    StorageBoxCard(box: box, filter: filter)
                }
            }
        }
    }

    private var itemList: some View {
        let rows = itemRows
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(rows.count) different items").font(.caption).foregroundStyle(Theme.secondaryText)
            ForEach(rows, id: \.name) { row in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    WikiName(name: row.name).font(.callout.weight(.semibold)).frame(width: 210, alignment: .leading)
                    Text("×\(row.total)").font(.callout).monospacedDigit().foregroundStyle(Theme.secondaryText).frame(width: 56, alignment: .trailing)
                    FlowChips(places: row.places)
                }
                .padding(.vertical, 2)
                Divider().opacity(0.3)
            }
        }
    }
}

private struct FlowChips: View {
    let places: [(StorageBox, Int)]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 360), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 4) {
            ForEach(Array(places.enumerated()), id: \.offset) { _, p in
                HStack(spacing: 5) {
                    ChestSwatch(box: p.0)
                    Text(p.0.label).lineLimit(1)
                    Text("×\(p.1)").monospacedDigit().foregroundStyle(Theme.secondaryText)
                }
                .font(.caption)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Theme.panelAlt.opacity(0.6), in: Capsule())
                .fixedSize()
            }
        }
    }
}

/// Small square in the chest's colour (wood brown when uncoloured), or an icon for non-chests.
struct ChestSwatch: View {
    let box: StorageBox
    var body: some View {
        switch box.name {
        case "Backpack": Image(systemName: "backpack.fill").foregroundStyle(Theme.accent)
        case "Fridge", "Mini-Fridge": Image(systemName: "refrigerator.fill").foregroundStyle(Theme.link)
        case "Auto-Grabber": Image(systemName: "tray.and.arrow.down.fill").foregroundStyle(Theme.secondaryText)
        default:
            RoundedRectangle(cornerRadius: 3)
                .fill(box.color.map { Color(red: Double($0.r) / 255, green: Double($0.g) / 255, blue: Double($0.b) / 255) }
                      ?? (box.name.contains("Stone") ? Color.gray : Color(red: 0.62, green: 0.40, blue: 0.20)))
                .frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.border.opacity(0.6), lineWidth: 1))
        }
    }
}

private struct StorageBoxCard: View {
    let box: StorageBox
    let filter: String
    @State private var expanded = false

    var body: some View {
        let shown = filter.isEmpty || box.label.localizedCaseInsensitiveContains(filter)
            ? box.items : box.items.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        let limit = 14
        let visible = expanded || !filter.isEmpty ? shown : Array(shown.prefix(limit))
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ChestSwatch(box: box)
                Text(box.name).font(.body.weight(.semibold))
                Text(box.tile.map { "\(box.location) · (\($0.x), \($0.y))" } ?? box.location).font(.caption).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(box.usedSlots)/\(box.capacity)").font(.caption).monospacedDigit()
                    .foregroundStyle(box.usedSlots >= box.capacity ? Theme.no : Theme.secondaryText)
                    .help("Slots used")
            }
            if box.items.isEmpty {
                Text("Empty").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            ForEach(visible) { item in
                HStack(spacing: 5) {
                    WikiName(name: item.name)
                    if item.quality > 0 {
                        Image(systemName: "star.fill").font(.system(size: 8))
                            .foregroundStyle(item.quality >= 4 ? Color.purple : item.quality >= 2 ? Theme.accent : Color.gray)
                    }
                    if item.kind != "Item" { Text(item.kind.lowercased()).font(.caption2).foregroundStyle(Theme.secondaryText) }
                    Spacer()
                    if item.count > 1 { Text("×\(item.count)").monospacedDigit().foregroundStyle(Theme.secondaryText) }
                }
                .font(.callout)
                .padding(.vertical, 1)
                .background(!filter.isEmpty && item.name.localizedCaseInsensitiveContains(filter) ? Theme.accent.opacity(0.15) : .clear)
            }
            if visible.count < shown.count {
                Button("+\(shown.count - visible.count) more") { expanded = true }.buttonStyle(.link).font(.caption)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 1))
    }
}
