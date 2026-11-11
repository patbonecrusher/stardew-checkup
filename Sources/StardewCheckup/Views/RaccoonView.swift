import SwiftUI

/// The forest neighbors' current request: the two items, how many you own and where.
struct RaccoonRequestView: View {
    let data: RaccoonPlanData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill").foregroundStyle(Theme.accent)
                Text("Request #\(data.requestNumber)").font(.headline).fontDesign(.rounded)
                Text(data.seasonName).font(.caption.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Theme.accent.opacity(0.2), in: Capsule())
                Spacer()
            }
            if data.waitDays > 0 {
                Label("They are busy for \(data.waitDays) more day\(data.waitDays == 1 ? "" : "s"); this is what they will ask for next.",
                      systemImage: "hourglass").font(.callout)
            } else {
                Label(data.seasonLocked ? "Waiting for you at the stump in Cindersap Forest." : "Ready: talk to Mr. Raccoon at the stump in Cindersap Forest.",
                      systemImage: "checkmark.circle").font(.callout).foregroundStyle(Theme.yes)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
                ForEach(data.rows) { RaccoonItemCard(row: $0) }
            }
            if let note = data.seasonNote {
                Text(note).font(.caption).italic().foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.text)
        .padding(.leading, 22)
        .padding(.vertical, 4)
    }
}

private struct RaccoonItemCard: View {
    let row: RaccoonItemRow

    private var color: Color { row.delivered || row.enough ? Theme.yes : Theme.no }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: row.delivered ? "checkmark.seal.fill" : row.enough ? "checkmark.circle.fill" : "circle").foregroundStyle(color)
                Text("\(row.want.name) ×\(row.want.count)").font(.body.weight(.semibold))
                Spacer()
                if row.delivered {
                    Text("delivered").font(.caption.weight(.semibold)).foregroundStyle(Theme.yes)
                } else {
                    Text("have \(row.have)").font(.caption).monospacedDigit().foregroundStyle(row.enough ? Theme.secondaryText : Theme.no)
                }
            }
            if !row.delivered {
                if !row.places.isEmpty {
                    Label(row.places, systemImage: "shippingbox").font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                if let recipe = row.want.recipe, !row.enough {
                    Label("Make it: " + recipe, systemImage: "gearshape").font(.callout).fixedSize(horizontal: false, vertical: true)
                    let base = RaccoonData.itemName(row.want.preserveOf ?? "")
                    Label("\(base): have \(row.baseHave)" + (row.basePlaces.isEmpty ? "" : " (\(row.basePlaces))"),
                          systemImage: row.baseHave >= row.want.baseNeeded ? "checkmark.circle" : "xmark.circle")
                        .font(.callout).foregroundStyle(row.baseHave >= row.want.baseNeeded ? Theme.text : Theme.no)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !row.enough, let hint = RaccoonData.whereToGet(row.want.preserveOf ?? row.want.itemId) {
                    Label(hint, systemImage: "map").font(.callout).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.35), lineWidth: 1))
    }
}
