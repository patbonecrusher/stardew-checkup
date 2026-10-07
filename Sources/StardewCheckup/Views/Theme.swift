import SwiftUI
import AppKit

/// Stardew-inspired palette with light (parchment) and dark (night) variants.
enum Theme {
    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    static let text = dyn(0x5a2e00, 0xf1dfc0)
    static let secondaryText = dyn(0x8a6a48, 0xb59c7c)
    static let panel = dyn(0xfff1d8, 0x2a221a)
    static let panelAlt = dyn(0xf8e3bd, 0x332a20)
    static let border = dyn(0x8a4a10, 0x9c6a38)
    static let link = dyn(0x9a5200, 0xf0b860)
    static let yes = dyn(0x2a7a2a, 0x8ee08e)
    static let no = dyn(0xc23a2a, 0xff8a7a)
    static let impossible = dyn(0x8f8f8f, 0x8c8c8c)
    static let accent = dyn(0xe08a2a, 0xf0a84a)
    static let heart = dyn(0xd63a3a, 0xff6b6b)
    static let barTrack = dyn(0xd8c3a0, 0x4a3d30)
    static let playerBar = dyn(0x5a2e00, 0x1c1610)
    static let playerBarText = dyn(0xf1dfc0, 0xf1dfc0)
    static let playerOn = dyn(0x8a4a10, 0x9c6a38)
    static let playerOff = dyn(0xa07850, 0x6a5848)

    static var background: LinearGradient {
        LinearGradient(colors: [dyn(0x8fb4f2, 0x141b2e), dyn(0xc9f3f3, 0x1a2338), dyn(0x6fcb6f, 0x16281c)],
                       startPoint: .top, endPoint: .bottom)
    }

    static func color(_ c: RunColor?) -> Color {
        switch c {
        case .yes: return yes
        case .no: return no
        case .impossible: return impossible
        case .link: return link
        case nil: return text
        }
    }

    static func color(_ s: StatusLine.State) -> Color {
        switch s {
        case .yes: return yes
        case .no: return no
        case .impossible: return impossible
        }
    }

    static func symbol(_ s: StatusLine.State) -> String {
        switch s {
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .impossible: return "minus.circle.fill"
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

/// Renders a `RichText` as a single SwiftUI `Text` with links and colours.
struct RichTextView: View {
    let text: RichText
    var baseFont: Font = .body

    var body: some View {
        Text(attributed)
            .tint(Theme.link)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .help(tooltip)
    }

    private var tooltip: String {
        text.runs.compactMap(\.tooltip).joined(separator: "\n")
    }

    private var attributed: AttributedString {
        var out = AttributedString()
        for run in text.runs {
            var s = AttributedString(run.text)
            s.foregroundColor = Theme.color(run.color)
            var font = baseFont
            if run.bold { font = font.bold() }
            if run.italic { font = font.italic() }
            s.font = font
            if let url = run.url {
                s.link = url
                s.underlineStyle = .single
            }
            if run.tooltip != nil {
                s.underlineStyle = .patternDot
            }
            out += s
        }
        return out
    }
}
