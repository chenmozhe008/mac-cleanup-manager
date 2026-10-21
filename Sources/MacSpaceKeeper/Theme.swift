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
    static let base = Color.adaptive(light: rgb(0.96, 0.97, 0.99), dark: rgb(0.065, 0.08, 0.12))
    static let ink = Color.adaptive(light: rgb(0.11, 0.11, 0.13), dark: rgb(0.91, 0.93, 0.99))
    static let ink2 = Color.adaptive(light: rgb(0.33, 0.35, 0.41), dark: rgb(0.66, 0.71, 0.84))
    static let ink3 = Color.adaptive(light: rgb(0.36, 0.40, 0.47), dark: rgb(0.68, 0.73, 0.82))
    /// Brighter secondary text used on selected / blue-tinted surfaces.
    static let softInk = Color.adaptive(light: rgb(0.1, 0.32, 0.75), dark: rgb(0.81, 0.88, 1.0))
    static let line = Color.adaptive(light: rgb(0, 0, 0, 0.08), dark: rgb(1, 1, 1, 0.08))
    static let panel = Color.adaptive(light: rgb(1, 1, 1, 0.94), dark: rgb(0.115, 0.14, 0.20, 0.96))
    /// Used space outside the scanned categories in the disk ring.
    static let usedTint = Color.adaptive(light: rgb(0.55, 0.64, 0.93), dark: rgb(0.40, 0.48, 0.80))
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
            Theme.base.opacity(0.84)
            RadialGradient(colors: [Color.adaptive(light: rgb(0.62, 0.74, 1.0, 0.45), dark: rgb(0.11, 0.23, 0.54, 0.7)), .clear],
                           center: UnitPoint(x: 0.3, y: 0), startRadius: 0, endRadius: 760)
            RadialGradient(colors: [Color.adaptive(light: rgb(0.82, 0.72, 1.0, 0.38), dark: rgb(0.23, 0.11, 0.54, 0.6)), .clear],
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
    /// Liquid Glass on macOS 26+; `highlighted` tints the active card blue. Older systems get a frosted panel.
    @ViewBuilder
    func glass(radius: CGFloat = 14, highlighted: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *) {
            self
                .glassEffect(highlighted ? .regular.tint(Theme.blue.opacity(0.22)) : .regular, in: shape)
                .overlay(shape.strokeBorder(highlighted ? Theme.blue.opacity(0.45) : .clear, lineWidth: 1).allowsHitTesting(false))
        } else {
            self
                .background(shape.fill(Theme.panel))
                .overlay(shape.fill(highlighted ? Theme.blue.opacity(0.08) : .clear).allowsHitTesting(false))
                .overlay(shape.strokeBorder(highlighted ? Theme.blue.opacity(0.45) : Theme.line, lineWidth: 1))
        }
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
            .foregroundStyle(Theme.blue.opacity(configuration.isPressed ? 0.6 : 1))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.blue.opacity(0.4)).frame(height: 1).offset(y: 3)
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
            Circle().stroke(Theme.fill(0.08), lineWidth: lineWidth)
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
            .font(.system(size: large ? 14 : 13, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(prominent ? Color.white : Theme.ink)
            .padding(.horizontal, large ? 18 : 12)
            .padding(.vertical, large ? 10 : 7)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(prominent ? Theme.blue : Theme.fill(configuration.isPressed ? 0.12 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(prominent ? .clear : Theme.line))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

/// The app icon at small size, without an extra tile behind it.
struct SidebarBrandMark: View {
    var size: CGFloat = 38
    private static let icon = Bundle.main.url(forResource: "AppIcon-source", withExtension: "png").flatMap(NSImage.init(contentsOf:))

    var body: some View {
        Group {
            if let icon = Self.icon {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Image(systemName: "externaldrive.fill.badge.checkmark").resizable().scaledToFit().padding(size * 0.2).foregroundStyle(Theme.blue)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
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

/// Wraps children onto new lines like text (chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: (indices: [Int], width: CGFloat, height: CGFloat) = ([], 0, 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let next = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if next > width, !current.indices.isEmpty {
                rows.append(current)
                current = ([index], size.width, size.height)
            } else {
                current = (current.indices + [index], next, max(current.height, size.height))
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}


/// Disk space ring: a glass disc with one gradient arc for the share in use.
struct DiskRing: View {
    let usedFraction: Double
    let low: Bool
    let free: String
    let caption: String

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let line = size * 0.075
            let colors = low ? [Theme.amber, Theme.orange, Theme.amber] : [Theme.cyan, Theme.blue, Theme.indigo, Theme.cyan]
            ZStack {
                disc(size)
                Circle()
                    .stroke(Theme.fill(0.08), lineWidth: line)
                    .padding(line / 2 + size * 0.04)
                Circle()
                    .trim(from: 0, to: min(max(usedFraction, 0.01), 1))
                    .stroke(AngularGradient(colors: colors, center: .center), style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (low ? Theme.amber : Theme.blue).opacity(0.35), radius: line * 0.6)
                    .padding(line / 2 + size * 0.04)
                Circle()
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.05), Color.white.opacity(0.35)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .allowsHitTesting(false)
                VStack(spacing: 4) {
                    Text(free)
                        .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(low ? Theme.amber : Theme.ink)
                    Text(caption).font(.system(size: 12.5, weight: .medium)).foregroundStyle(low ? Theme.amber : Theme.ink2).lineLimit(1)
                }
                .padding(.horizontal, size * 0.16)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func disc(_ size: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            Circle().fill(Color.clear).glassEffect(.regular, in: Circle())
        } else {
            Circle().fill(Theme.panel)
        }
    }
}
