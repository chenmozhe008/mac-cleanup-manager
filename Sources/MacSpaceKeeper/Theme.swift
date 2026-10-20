import SwiftUI

/// Dark "immersive brand" palette (mockup B, 2026-10-20).
enum Theme {
    static let base = Color(red: 0.043, green: 0.071, blue: 0.149)
    static let ink = Color(red: 0.91, green: 0.93, blue: 0.99)
    static let ink2 = Color(red: 0.66, green: 0.71, blue: 0.84)
    static let ink3 = Color(red: 0.44, green: 0.49, blue: 0.64)
    static let line = Color.white.opacity(0.08)
    static let panel = Color.white.opacity(0.05)
    static let track = Color(red: 0.165, green: 0.208, blue: 0.341)
    static let blue = Color(red: 0.31, green: 0.55, blue: 1.0)
    static let cyan = Color(red: 0.22, green: 0.84, blue: 1.0)
    static let indigo = Color(red: 0.49, green: 0.36, blue: 1.0)
    static let violet = Color(red: 0.65, green: 0.55, blue: 0.98)
    static let amber = Color(red: 1.0, green: 0.71, blue: 0.28)
    static let orange = Color(red: 1.0, green: 0.42, blue: 0.24)
    static let slate = Color(red: 0.51, green: 0.57, blue: 0.71)
    static let pink = Color(red: 1.0, green: 0.48, blue: 0.71)
    static let green = Color(red: 0.2, green: 0.83, blue: 0.6)

    static let accent = LinearGradient(colors: [blue, cyan], startPoint: .leading, endPoint: .trailing)
    static let warning = LinearGradient(colors: [amber, orange], startPoint: .leading, endPoint: .trailing)
    static let cta = LinearGradient(colors: [blue, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func color(_ category: ItemFilter) -> Color {
        switch category {
        case .caches: cyan
        case .creative: pink
        case .chat: green
        case .review: amber
        case .large: violet
        }
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            Theme.base
            RadialGradient(colors: [Color(red: 0.11, green: 0.23, blue: 0.54), .clear],
                           center: UnitPoint(x: 0.3, y: 0), startRadius: 0, endRadius: 760)
            RadialGradient(colors: [Color(red: 0.23, green: 0.11, blue: 0.54).opacity(0.9), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 620)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Frosted panel; `highlighted` gives the blue glow used for the active card.
    func glass(radius: CGFloat = 14, highlighted: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(
                shape.fill(highlighted
                           ? AnyShapeStyle(LinearGradient(colors: [Theme.blue.opacity(0.35), Theme.cyan.opacity(0.12)],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                           : AnyShapeStyle(Theme.panel))
            )
            .overlay(shape.strokeBorder(highlighted ? Theme.blue.opacity(0.5) : Theme.line, lineWidth: 1))
            .shadow(color: highlighted ? Theme.blue.opacity(0.45) : .clear, radius: 18, y: 10)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.ink2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
            .contentShape(Rectangle())
    }
}

struct CTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cta))
            .shadow(color: Theme.indigo.opacity(0.7), radius: 14, y: 8)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.81, green: 0.88, blue: 1.0).opacity(configuration.isPressed ? 0.6 : 1))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(red: 0.81, green: 0.88, blue: 1.0).opacity(0.4)).frame(height: 1).offset(y: 3)
            }
    }
}

/// Thin capsule bar with a glowing fill.
struct GlowBar: View {
    let fraction: Double
    var fill: LinearGradient = Theme.accent
    var glow: Color = Theme.cyan

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(fill)
                    .frame(width: max(3, proxy.size.width * min(max(fraction, 0), 1)))
                    .shadow(color: glow.opacity(0.55), radius: 4)
            }
        }
    }
}

struct GlowDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8).shadow(color: color.opacity(0.9), radius: 5)
    }
}

/// Disk usage ring: segments are fractions of total capacity, drawn clockwise from 12 o'clock.
struct UsageRing: View {
    struct Segment {
        let fraction: Double
        let style: AnyShapeStyle
        var glow: Color = .clear
    }

    let segments: [Segment]
    var lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
            ForEach(Array(placed.enumerated()), id: \.offset) { _, item in
                Circle()
                    .trim(from: item.start, to: item.end)
                    .stroke(item.segment.style, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .shadow(color: item.segment.glow, radius: 6)
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2)
    }

    private var placed: [(segment: Segment, start: Double, end: Double)] {
        var start = 0.0
        return segments.compactMap { segment in
            guard segment.fraction > 0 else { return nil }
            // Keep tiny but non-zero categories visible.
            let length = min(max(segment.fraction, 0.012), 1 - start)
            defer { start += length }
            return (segment, start, start + length)
        }
    }
}

/// Top-bar actions: `prominent` is the primary (rescan), otherwise a clear secondary button.
struct ToolbarButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(prominent ? Color.white : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(Theme.cta) : AnyShapeStyle(Color.white.opacity(configuration.isPressed ? 0.16 : 0.1)))
            )
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(prominent ? Color.white.opacity(0.18) : Color.white.opacity(0.2)))
            .shadow(color: prominent ? Theme.indigo.opacity(0.55) : .clear, radius: 10, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}
