import SwiftUI

/// The site's "Left to …" lists. Long flat lists become a filterable grid;
/// grouped lists (Known / Unknown recipes) become one grid per group.
struct NeedListView: View {
    let items: [DetailItem]
    let ordered: Bool
    @State private var filter = ""

    private static let gridThreshold = 8

    private var isGroupedLeafList: Bool {
        !items.isEmpty && items.allSatisfy { !$0.children.isEmpty && $0.children.allSatisfy { $0.children.isEmpty } }
    }
    private var isFlatLeafList: Bool {
        items.allSatisfy { $0.children.isEmpty && $0.value == nil }
    }
    private var totalLeaves: Int {
        isGroupedLeafList ? items.reduce(0) { $0 + $1.children.count } : items.count
    }

    var body: some View {
        if isFlatLeafList && items.count >= Self.gridThreshold {
            VStack(alignment: .leading, spacing: 6) {
                filterField
                ItemGrid(items: filtered(items))
            }
        } else if isGroupedLeafList && totalLeaves >= Self.gridThreshold {
            VStack(alignment: .leading, spacing: 8) {
                filterField
                ForEach(Array(items.enumerated()), id: \.offset) { _, group in
                    let rows = filtered(group.children)
                    if !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                RichTextView(text: group.text.bolded(), baseFont: .subheadline)
                                Text("\(rows.count)")
                                    .font(.caption2.weight(.semibold)).monospacedDigit()
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Theme.accent.opacity(0.18), in: Capsule())
                                    .foregroundStyle(Theme.text)
                            }
                            ItemGrid(items: rows)
                        }
                    }
                }
            }
        } else {
            DetailListView(items: items, ordered: ordered)
        }
    }

    @ViewBuilder
    private var filterField: some View {
        if totalLeaves >= 15 {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                TextField("Filter \(totalLeaves) items", text: $filter)
                    .textFieldStyle(.plain)
                if !filter.isEmpty {
                    Button { filter = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.4), lineWidth: 1))
            .frame(maxWidth: 320)
        }
    }

    private func filtered(_ list: [DetailItem]) -> [DetailItem] {
        let q = filter.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return list }
        return list.filter { $0.text.plain.localizedCaseInsensitiveContains(q) }
    }
}

struct ItemGrid: View {
    let items: [DetailItem]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 320), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                HStack(spacing: 5) {
                    Image(systemName: "circle").font(.system(size: 6)).foregroundStyle(Theme.accent)
                    RichTextView(text: item.text, baseFont: .callout)
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
