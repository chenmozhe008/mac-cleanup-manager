import AppKit
import SwiftUI

extension Color {
    /// Resolves per appearance, so one palette serves light and dark mode.
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

private func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

/// Brand palette (mockup B, 2026-10-20), with a light variant (2026-10-21).
enum Theme {
    static let base = Color.adaptive(light: rgb(0.93, 0.94, 0.97), dark: rgb(0.043, 0.071, 0.149))
    static let ink = Color.adaptive(light: rgb(0.11, 0.11, 0.13), dark: rgb(0.91, 0.93, 0.99))
    static let ink2 = Color.adaptive(light: rgb(0.33, 0.35, 0.41), dark: rgb(0.66, 0.71, 0.84))
    static let ink3 = Color.adaptive(light: rgb(0.52, 0.54, 0.6), dark: rgb(0.44, 0.49, 0.64))
    /// Brighter secondary text used on selected / blue-tinted surfaces.
    static let softInk = Color.adaptive(light: rgb(0.1, 0.32, 0.75), dark: rgb(0.81, 0.88, 1.0))
    static let line = Color.adaptive(light: rgb(0, 0, 0, 0.08), dark: rgb(1, 1, 1, 0.08))
    static let panel = Color.adaptive(light: rgb(1, 1, 1, 0.75), dark: rgb(1, 1, 1, 0.05))
    static let track = Color.adaptive(light: rgb(0.78, 0.79, 0.83), dark: rgb(0.36, 0.43, 0.62))
    static let blue = Color.adaptive(light: rgb(0.04, 0.45, 1.0), dark: rgb(0.31, 0.55, 1.0))
    static let cyan = Color.adaptive(light: rgb(0.0, 0.55, 0.85), dark: rgb(0.22, 0.84, 1.0))
    static let indigo = Color(red: 0.49, green: 0.36, blue: 1.0)
    static let violet = Color.adaptive(light: rgb(0.55, 0.3, 0.95), dark: rgb(0.65, 0.55, 0.98))
    static let amber = Color.adaptive(light: rgb(0.85, 0.5, 0.0), dark: rgb(1.0, 0.71, 0.28))
    static let orange = Color(red: 1.0, green: 0.42, blue: 0.24)
    static let slate = Color(red: 0.51, green: 0.57, blue: 0.71)
    static let pink = Color.adaptive(light: rgb(0.95, 0.2, 0.42), dark: rgb(1.0, 0.48, 0.71))
    static let green = Color.adaptive(light: rgb(0.13, 0.62, 0.32), dark: rgb(0.2, 0.83, 0.6))

    /// Neutral overlay: white on dark, black on light.
    static func fill(_ opacity: Double) -> Color {
        Color.adaptive(light: rgb(0, 0, 0, CGFloat(opacity * 0.75)), dark: rgb(1, 1, 1, CGFloat(opacity)))
    }

    static let accent = LinearGradient(colors: [blue, cyan], startPoint: .leading, endPoint: .trailing)
    static let warning = LinearGradient(colors: [amber, orange], startPoint: .leading, endPoint: .trailing)
    static let cta = LinearGradient(colors: [blue, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func symbol(_ category: ItemFilter) -> String {
        switch category {
        case .caches: "sparkles"
        case .creative: "film.fill"
        case .chat: "bubble.left.and.bubble.right.fill"
        case .review: "hand.raised.fill"
        case .large: "shippingbox.fill"
        }
    }

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
            // The desktop shows through faintly behind the brand gradient (macOS 26 Liquid Glass look).
            WindowBlur()
            Theme.base.opacity(0.78)
            RadialGradient(colors: [Color.adaptive(light: rgb(0.72, 0.8, 1.0, 0.6), dark: rgb(0.11, 0.23, 0.54, 0.85)), .clear],
                           center: UnitPoint(x: 0.3, y: 0), startRadius: 0, endRadius: 760)
            RadialGradient(colors: [Color.adaptive(light: rgb(0.85, 0.78, 1.0, 0.55), dark: rgb(0.23, 0.11, 0.54, 0.75)), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 620)
        }
        .ignoresSafeArea()
    }
}

/// Behind-window blur so the window itself reads as glass.
struct WindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

extension View {
    /// Frosted panel; `highlighted` gives the blue glow used for the active card.
    @ViewBuilder
    func glass(radius: CGFloat = 14, highlighted: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *) {
            // Liquid Glass on macOS 26+; the active card gets a blue tint.
            self
                .glassEffect(highlighted ? .regular.tint(Theme.blue.opacity(0.35)) : .regular, in: shape)
                .shadow(color: highlighted ? Theme.blue.opacity(0.4) : .clear, radius: 18, y: 10)
        } else {
            legacyGlass(shape: shape, highlighted: highlighted)
        }
    }

    private func legacyGlass(shape: RoundedRectangle, highlighted: Bool) -> some View {
        self
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
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fill(configuration.isPressed ? 0.12 : 0.07)))
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
                Capsule().fill(Theme.fill(0.08))
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
            Circle().stroke(Theme.fill(0.07), lineWidth: lineWidth)
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
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 14.5 : 13, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(prominent ? Color.white : Theme.ink)
            .padding(.horizontal, large ? 20 : 14)
            .padding(.vertical, large ? 10 : 7)
            .background(
                Capsule()
                    .fill(prominent ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.29, green: 0.64, blue: 1.0), Color(red: 0.04, green: 0.42, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Theme.fill(configuration.isPressed ? 0.16 : 0.1)))
            )
            .overlay(Capsule().strokeBorder(prominent ? Color.white.opacity(0.3) : Theme.fill(0.2)))
            .overlay(alignment: .top) {
                // Specular top edge, like system glass buttons.
                Capsule().fill(LinearGradient(colors: [Color.white.opacity(prominent ? 0.35 : 0.18), .clear], startPoint: .top, endPoint: .center))
                    .allowsHitTesting(false)
            }
            .shadow(color: prominent ? Theme.indigo.opacity(0.55) : .clear, radius: 10, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}

/// System Settings–style rounded icon tile with a white SF Symbol.
struct IconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.75)], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
            )
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.5, weight: .bold)).foregroundStyle(.white))
            .frame(width: size, height: size)
    }
}
