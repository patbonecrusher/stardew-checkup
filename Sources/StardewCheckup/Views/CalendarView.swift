import SwiftUI

/// Stardew-style season calendar: 4 weeks of 7 days, Monday first, with birthdays and festivals.
struct CalendarView: View {
    let data: CalendarData
    @State private var season: String

    init(data: CalendarData) {
        self.data = data
        _season = State(initialValue: CalendarData.seasons.contains(data.season) ? data.season : "Spring")
    }

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Picker("", selection: $season) {
                    ForEach(CalendarData.seasons, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                if season != data.season {
                    Button("Today") { season = data.season }.controlSize(.small)
                }
                Spacer()
                legend
            }
            grid
        }
        .padding(.leading, 22)
        .padding(.bottom, 4)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Label("birthday", systemImage: "birthday.cake.fill").foregroundStyle(Theme.heart)
            Label("festival", systemImage: "star.fill").foregroundStyle(Theme.accent)
            Label("gift given / attended", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.yes)
        }
        .font(.callout).foregroundStyle(Theme.secondaryText)
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 130), spacing: 8), count: 7)
        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { d in
                    Text(d).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...28, id: \.self) { day in
                    DayCell(day: day, events: data.events(on: day, in: season),
                            isToday: season == data.season && day == data.day,
                            isPast: season == data.season && day < data.day)
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Int
    let events: [CalendarEvent]
    let isToday: Bool
    let isPast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(day)")
                    .font(.title2.weight(isToday ? .bold : .semibold)).monospacedDigit()
                    .foregroundStyle(isToday ? Theme.accent : Theme.secondaryText)
                Spacer()
                if isToday {
                    Text("TODAY").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.2), in: Capsule())
                }
            }
            ForEach(events) { e in
                HStack(spacing: 5) {
                    Image(systemName: icon(e)).font(.system(size: 13)).foregroundStyle(color(e))
                    if let url = e.url {
                        Link(e.name, destination: url).foregroundStyle(Theme.text)
                    } else {
                        Text(e.name).foregroundStyle(Theme.text)
                    }
                    if e.done {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.yes)
                    }
                }
                .font(.body.weight(e.kind == .festival ? .semibold : .regular))
                .lineLimit(2)
                .help(tooltip(e))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isToday ? Theme.accent : Theme.border.opacity(0.25), lineWidth: isToday ? 3 : 1))
        .opacity(isPast ? 0.6 : 1)
    }

    private var background: Color {
        if events.contains(where: { $0.kind == .festival }) { return Theme.accent.opacity(0.15) }
        return Theme.panelAlt.opacity(0.55)
    }

    private func icon(_ e: CalendarEvent) -> String {
        switch e.kind {
        case .birthday: return "birthday.cake.fill"
        case .festival: return "star.fill"
        case .other: return "leaf.fill"
        }
    }

    private func color(_ e: CalendarEvent) -> Color {
        switch e.kind {
        case .birthday: return Theme.heart
        case .festival: return Theme.accent
        case .other: return Theme.yes
        }
    }

    private func tooltip(_ e: CalendarEvent) -> String {
        switch e.kind {
        case .birthday: return e.done ? "\(e.name)'s birthday — gift already given this year" : "\(e.name)'s birthday — a loved gift gives 8× friendship today"
        case .festival: return e.done ? "\(e.name) — attended before" : "\(e.name) — not attended yet"
        case .other: return e.name
        }
    }
}
