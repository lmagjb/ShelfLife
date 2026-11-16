import SwiftUI

// MARK: - Palette
/// Glass only reads as glass when there is colour behind it to refract.
/// These tokens drive both the ambient backdrop and the translucent
/// panels that float on top of it.
enum AppTheme {

    // Brand
    static let sage   = Color(red: 0.29, green: 0.67, blue: 0.56)
    static let mint   = Color(red: 0.44, green: 0.86, blue: 0.74)
    static let teal   = Color(red: 0.22, green: 0.56, blue: 0.66)
    static let amber  = Color(red: 0.97, green: 0.71, blue: 0.31)
    static let coral  = Color(red: 0.96, green: 0.44, blue: 0.42)
    static let violet = Color(red: 0.56, green: 0.49, blue: 0.86)

    // Semantic
    static let warning = amber
    static let danger  = coral

    /// Neutral fills. `Color.primary` flips with the colour scheme, so
    /// these stay legible in both light and dark without a second set.
    static let cardBackground = Color.primary.opacity(0.06)
    static let chipBackground = Color.primary.opacity(0.10)

    // Geometry
    static let cardRadius: CGFloat = 24
    static let chipRadius: CGFloat = 14
}

// MARK: - Aurora backdrop
/// Soft colour fields behind everything else. Built from radial
/// gradients rather than blurred circles — same look, far cheaper to
/// draw, and it never shows banding on a large surface.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme

    /// Slow drift. Worth it on the sign-in screen; left off elsewhere so
    /// the app is not repainting the background behind every scroll.
    var animated: Bool = false

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            base

            orb(AppTheme.mint,   at: UnitPoint(x: 0.12 + drift(0.05), y: 0.06),
                radius: 420, opacity: scheme == .dark ? 0.40 : 0.55)

            orb(AppTheme.teal,   at: UnitPoint(x: 0.92, y: 0.20 + drift(0.04)),
                radius: 380, opacity: scheme == .dark ? 0.34 : 0.40)

            orb(AppTheme.amber,  at: UnitPoint(x: 0.88 - drift(0.06), y: 0.74),
                radius: 400, opacity: scheme == .dark ? 0.22 : 0.34)

            orb(AppTheme.violet, at: UnitPoint(x: 0.08, y: 0.92 - drift(0.05)),
                radius: 440, opacity: scheme == .dark ? 0.30 : 0.30)
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private var base: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.05, green: 0.08, blue: 0.10),
                   Color(red: 0.07, green: 0.10, blue: 0.13)]
                : [Color(red: 0.96, green: 0.98, blue: 0.97),
                   Color(red: 0.93, green: 0.95, blue: 0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func orb(_ color: Color, at center: UnitPoint,
                     radius: CGFloat, opacity: Double) -> some View {
        RadialGradient(
            colors: [color.opacity(opacity), color.opacity(0)],
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    }

    private func drift(_ amount: CGFloat) -> CGFloat {
        animated ? amount * phase : 0
    }
}

// MARK: - Glass surface
/// One frosted pane: blurred material, an optional colour wash, a
/// highlight along the top edge where light would catch, and a hairline
/// border that keeps the panel from dissolving into its background.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cardRadius
    var material: Material = .ultraThinMaterial
    var tint: Color = .clear
    var tintOpacity: Double = 0.16
    var highlight: Double = 0.26
    var border: Double = 0.40
    var shadowRadius: CGFloat = 18
    var shadowOpacity: Double = 0.10

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(material)
                    shape.fill(tint.opacity(tintOpacity))
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(highlight), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(border),
                            Color.white.opacity(border * 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius, x: 0, y: shadowRadius * 0.45)
    }
}

extension View {

    /// A frosted panel. Pass a `tint` to wash it with a brand colour.
    func glass(cornerRadius: CGFloat = AppTheme.cardRadius,
               material: Material = .ultraThinMaterial,
               tint: Color = .clear,
               tintOpacity: Double = 0.16,
               shadowRadius: CGFloat = 18,
               shadowOpacity: Double = 0.10) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius,
                              material: material,
                              tint: tint,
                              tintOpacity: tintOpacity,
                              shadowRadius: shadowRadius,
                              shadowOpacity: shadowOpacity))
    }

    /// Padded glass card — the default container for a block of content.
    func glassCard(cornerRadius: CGFloat = AppTheme.cardRadius,
                   tint: Color = .clear,
                   padding: CGFloat = 18) -> some View {
        self.padding(padding)
            .glass(cornerRadius: cornerRadius, tint: tint)
    }

    /// Kept under its original name so existing call sites still read well.
    func cardStyle() -> some View { glassCard() }

    /// Small frosted pill for chips, badges and inline controls.
    func glassChip(cornerRadius: CGFloat = AppTheme.chipRadius,
                   tint: Color = .clear) -> some View {
        glass(cornerRadius: cornerRadius,
              material: .ultraThinMaterial,
              tint: tint,
              tintOpacity: 0.22,
              shadowRadius: 6,
              shadowOpacity: 0.06)
    }

    /// Drops the opaque backgrounds SwiftUI puts behind scrolling
    /// containers and nav bars, and lays the aurora behind the screen.
    /// Sheets and pushed screens don't inherit the root backdrop, so
    /// each screen brings its own.
    func transparentChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .toolbarBackground(.hidden, for: .navigationBar)
            .background { AuroraBackground() }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = AppTheme.sage

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                Capsule().fill(
                    LinearGradient(colors: [color, color.opacity(0.76)],
                                   startPoint: .top, endPoint: .bottom)
                )
                Capsule().fill(
                    LinearGradient(colors: [Color.white.opacity(0.32), Color.white.opacity(0)],
                                   startPoint: .top, endPoint: .center)
                )
            }
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: color.opacity(configuration.isPressed ? 0.18 : 0.38),
                    radius: configuration.isPressed ? 6 : 14, y: configuration.isPressed ? 3 : 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .glass(cornerRadius: 28, shadowRadius: 8, shadowOpacity: 0.06)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Circular frosted button for toolbars and overlays.
struct GlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = 38

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .glass(cornerRadius: size / 2, shadowRadius: 6, shadowOpacity: 0.08)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Glass form row
/// `Form` paints its own opaque rows, so settings-style lists are built
/// by hand from these instead.
struct GlassSection<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.caption2).fontWeight(.semibold)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
            VStack(spacing: 0) { content }
                .glass(cornerRadius: AppTheme.cardRadius)
        }
    }
}

/// Hairline divider that reads correctly on top of a frosted panel.
struct GlassDivider: View {
    var inset: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, inset)
    }
}
