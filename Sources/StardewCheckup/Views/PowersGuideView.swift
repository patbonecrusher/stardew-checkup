import SwiftUI

/// Where every book and special item/power comes from, with have / missing status.
struct PowersGuideView: View {
    let booksRead: Set<String>
    let powersHave: Set<String>
    let expanded: Bool
    @State private var isOpen: Bool
    @State private var onlyMissing = false
    @State private var filter = ""

    init(booksRead: Set<String>, powersHave: Set<String>, expanded: Bool) {
        self.booksRead = booksRead
        self.powersHave = powersHave
        self.expanded = expanded
        _isOpen = State(initialValue: expanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.caption.weight(.bold))
                    Image(systemName: "map.fill").foregroundStyle(Theme.accent)
                    Text("Where to find them").font(.headline).fontDesign(.rounded)
                    Text("from the wiki").font(.caption).foregroundStyle(Theme.secondaryText)
                }
                .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            if isOpen {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                            TextField("Filter by name or source", text: $filter).textFieldStyle(.plain)
                            if !filter.isEmpty {
                                Button { filter = "" } label: { Image(systemName: "xmark.circle.fill") }
                                    .buttonStyle(.plain).foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                        .frame(maxWidth: 300)
                        Toggle("Only missing", isOn: $onlyMissing).toggleStyle(.checkbox)
                        Spacer()
                    }
                    group("Books", icon: "book.fill", items: ItemSourceData.books, have: booksRead)
                    group("Special Items & Powers", icon: "sparkles", items: ItemSourceData.powers, have: powersHave)
                }
                .padding(12)
                .background(Theme.panelAlt.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .padding(.leading, 4)
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func group(_ title: String, icon: String, items: [ItemSourceData.Entry], have: Set<String>) -> some View {
        let q = filter.trimmingCharacters(in: .whitespaces)
        let list = items.filter { e in
            (!onlyMissing || !have.contains(e.name)) &&
            (q.isEmpty || e.name.localizedCaseInsensitiveContains(q) || e.source.localizedCaseInsensitiveContains(q))
        }
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundStyle(Theme.accent)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                    Text("\(items.filter { have.contains($0.name) }.count)/\(items.count)")
                        .font(.caption2.weight(.semibold)).monospacedDigit()
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Theme.accent.opacity(0.18), in: Capsule())
                        .foregroundStyle(Theme.text)
                }
                VStack(spacing: 2) {
                    ForEach(list) { e in
                        let got = have.contains(e.name)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: got ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(got ? Theme.yes : Theme.no)
                                .font(.system(size: 12)).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    if let url = e.url {
                                        Link(e.name, destination: url).foregroundStyle(Theme.link)
                                    } else {
                                        Text(e.name).foregroundStyle(Theme.text)
                                    }
                                }
                                .font(.callout.weight(.medium))
                                if !e.effect.isEmpty {
                                    Text(e.effect).font(.caption).foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .frame(width: 230, alignment: .leading)
                            Text(e.source)
                                .font(.callout)
                                .foregroundStyle(got ? Theme.secondaryText : Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4).padding(.horizontal, 8)
                        .background(Theme.panelAlt.opacity(got ? 0.3 : 0.6), in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
        }
    }
}
