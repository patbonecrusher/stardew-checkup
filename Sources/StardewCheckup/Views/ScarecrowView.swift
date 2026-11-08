import SwiftUI

/// Rarecrow collection plus a farm map of scarecrow coverage over your crops.
struct ScarecrowView: View {
    let data: ScarecrowData
    @AppStorage("scarecrow-show-map") private var showMap = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rarecrows").font(.headline).fontDesign(.rounded).foregroundStyle(Theme.text)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
                ForEach(data.rarecrows) { RarecrowCard(row: $0) }
            }
            deluxeLine
            if !data.scarecrows.filter(\.onFarm).isEmpty || !data.crops.isEmpty {
                HStack(spacing: 14) {
                    Text("Crop coverage").font(.headline).fontDesign(.rounded).foregroundStyle(Theme.text)
                    Toggle("Farm map", isOn: $showMap).toggleStyle(.checkbox).font(.callout)
                    Spacer()
                }
                .padding(.top, 4)
                if showMap {
                    legend
                    ScarecrowMapView(data: data)
                }
                let away = data.scarecrows.filter { !$0.onFarm }
                if !away.isEmpty {
                    Text("Not on the farm map (crows never visit these places): " + away.map { "\($0.name) in \($0.location)" }.joined(separator: ", "))
                        .font(.caption).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                Text("A Scarecrow or Rarecrow protects crops within 8 tiles, a Deluxe Scarecrow within 16. Crows only come to the farm map, and only when you have at least 16 crops there; the greenhouse, Ginger Island and garden pots are always safe.")
                    .font(.caption).italic().foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 22).padding(.bottom, 4)
    }

    private var deluxeLine: some View {
        let have = data.rarecrows.filter(\.have).count
        let text: String
        if data.deluxeCrafted > 0 { text = "Deluxe Scarecrow recipe known, crafted ×\(data.deluxeCrafted)." }
        else if data.knowsDeluxe || data.hasLetter { text = "You know the Deluxe Scarecrow recipe (50 Wood, 40 Fiber, 1 Iridium Ore) but haven't crafted one yet." }
        else if have == 8 { text = "You have all 8: place them on your farm at the same time and the Rarecrow Society sends the Deluxe Scarecrow recipe the next morning." }
        else { text = "\(8 - have) Rarecrow\(8 - have == 1 ? "" : "s") to go before the Rarecrow Society sends the Deluxe Scarecrow recipe (radius 16)." }
        return Label(text, systemImage: data.knowsDeluxe ? "checkmark.seal.fill" : "envelope")
            .font(.callout).foregroundStyle(data.knowsDeluxe ? Theme.yes : Theme.text)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(ScarecrowMapView.safe, "crop covered")
            legendDot(ScarecrowMapView.open, "crop not covered (\(data.unprotected))")
            legendDot(ScarecrowMapView.crowColor, "scarecrow, with its range")
        }
        .font(.caption).foregroundStyle(Theme.secondaryText)
    }

    private func legendDot(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 10, height: 10); Text(s) }
    }
}

private struct RarecrowCard: View {
    let row: RarecrowStatus

    var body: some View {
        let color = row.have ? Theme.yes : Theme.no
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: row.have ? "checkmark.circle.fill" : "circle").foregroundStyle(color)
                Text("Rarecrow #\(row.number)").font(.body.weight(.semibold))
                Spacer()
                if row.placed.count + row.stored.count > 1 {
                    Text("you have \(row.placed.count + row.stored.count)").font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            ForEach(row.placed, id: \.self) { Label("Placed: " + $0, systemImage: "mappin.and.ellipse").font(.callout) }
            ForEach(row.stored, id: \.self) { Label("In " + $0, systemImage: "shippingbox").font(.callout) }
            if !row.have {
                Label(row.source, systemImage: "cart").font(.callout).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(row.source).font(.caption).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.text)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.35), lineWidth: 1))
    }
}

struct ScarecrowMapView: View {
    let data: ScarecrowData
    static let safe = Color(red: 0.35, green: 0.75, blue: 0.35)
    static let open = Color(red: 0.90, green: 0.25, blue: 0.20)
    static let crowColor = Color(red: 0.95, green: 0.75, blue: 0.25)

    private var crows: [PlacedScarecrow] { data.scarecrows.filter(\.onFarm) }

    private var bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int) {
        var xs = data.buildings.flatMap { [$0.x, $0.x + $0.w] } + data.crops.map(\.x) + crows.map(\.tile.x)
        var ys = data.buildings.flatMap { [$0.y, $0.y + $0.h] } + data.crops.map(\.y) + crows.map(\.tile.y)
        if let d = data.frontDoor { xs.append(d.x); ys.append(d.y) }
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return (0, 0, 80, 65) }
        return (max(0, x0 - 3), max(0, y0 - 3), x1 + 3, y1 + 3)
    }

    var body: some View {
        let b = bounds
        let cols = CGFloat(b.maxX - b.minX + 1), rows = CGFloat(b.maxY - b.minY + 1)
        GeometryReader { geo in
            let tile = min(geo.size.width / cols, 12)
            let ox = (geo.size.width - tile * cols) / 2
            let pt = { (x: Int, y: Int) in CGPoint(x: ox + CGFloat(x - b.minX) * tile, y: CGFloat(y - b.minY) * tile) }
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    ctx.fill(Path(roundedRect: CGRect(x: ox, y: 0, width: tile * cols, height: tile * rows), cornerRadius: 8),
                             with: .color(Color(red: 0.36, green: 0.52, blue: 0.27).opacity(0.35)))
                    for c in crows {
                        let p = pt(c.tile.x, c.tile.y), r = CGFloat(c.radius) * tile + tile / 2
                        let rect = CGRect(x: p.x + tile / 2 - r, y: p.y + tile / 2 - r, width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(Self.crowColor.opacity(0.10)))
                        ctx.stroke(Path(ellipseIn: rect), with: .color(Self.crowColor.opacity(0.5)), lineWidth: 1)
                    }
                    for bld in data.buildings {
                        let p = pt(bld.x, bld.y)
                        let rect = CGRect(x: p.x, y: p.y, width: CGFloat(bld.w) * tile, height: CGFloat(bld.h) * tile)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(bld.name == "Farmhouse" ? Theme.accent.opacity(0.55) : Theme.barTrack.opacity(0.9)))
                        ctx.draw(Text(bld.name).font(.system(size: max(8, min(10, tile))).weight(.semibold)).foregroundColor(Theme.text),
                                 in: rect.insetBy(dx: 2, dy: 2))
                    }
                    for c in data.crops {
                        let p = pt(c.x, c.y)
                        ctx.fill(Path(CGRect(x: p.x + 1, y: p.y + 1, width: tile - 2, height: tile - 2)),
                                 with: .color(c.protected ? Self.safe : Self.open))
                    }
                }
                if let d = data.frontDoor {
                    let p = pt(d.x, d.y)
                    Image(systemName: "door.left.hand.open").font(.system(size: tile * 1.1)).foregroundStyle(Theme.no)
                        .frame(width: tile * 1.6, height: tile * 1.6)
                        .offset(x: p.x - tile * 0.3, y: p.y - tile * 0.3)
                        .help("Your front door")
                }
                ForEach(crows) { c in
                    let p = pt(c.tile.x, c.tile.y)
                    let size = tile * 1.5
                    ZStack {
                        Circle().fill(Self.crowColor).overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1))
                        if c.name.hasPrefix("Rarecrow #") {
                            Text(c.name.replacingOccurrences(of: "Rarecrow #", with: "")).font(.system(size: tile * 0.9, weight: .bold)).foregroundStyle(.black)
                        } else if c.radius > 8 {
                            Image(systemName: "star.fill").font(.system(size: tile * 0.8)).foregroundStyle(.black)
                        }
                    }
                    .frame(width: size, height: size)
                    .offset(x: p.x + (tile - size) / 2, y: p.y + (tile - size) / 2)
                    .help("\(c.name) (\(c.tile.x), \(c.tile.y))" + (c.directions.map { "\n" + $0 } ?? ""))
                }
            }
        }
        .frame(height: min(rows * 12, 560))
    }
}
