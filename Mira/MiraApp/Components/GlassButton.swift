import SwiftUI

/// Reusable Liquid Glass button component
/// Follows iOS 26 design language with proper glass effects
struct GlassButton: View {
    let title: String
    let icon: String?
    let style: GlassButtonStyle
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    init(
        _ title: String,
        icon: String? = nil,
        style: GlassButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .frame(minWidth: style.minWidth, minHeight: style.minHeight)
        }
        .buttonStyle(GlassButtonStyleModifier(style: style, isEnabled: isEnabled))
    }
}

// MARK: - Button Styles

enum GlassButtonStyle {
    case primary    // Tinted glass, main CTA
    case secondary  // Clear glass, secondary actions
    case compact    // Smaller, for toolbars
    case large      // Full-width, prominent actions

    var horizontalPadding: CGFloat {
        switch self {
        case .primary, .secondary: return 20
        case .compact: return 12
        case .large: return 24
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .primary, .secondary: return 12
        case .compact: return 8
        case .large: return 16
        }
    }

    var minWidth: CGFloat? {
        switch self {
        case .large: return nil // Full width handled by frame
        default: return 44
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .compact: return 36
        default: return 44
        }
    }
}

// MARK: - Button Style Modifier

private struct GlassButtonStyleModifier: ButtonStyle {
    let style: GlassButtonStyle
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .background {
                glassBackground(isPressed: configuration.isPressed)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .compact, .large:
            return isPressed ? .primary.opacity(0.7) : .primary
        }
    }

    @ViewBuilder
    private func glassBackground(isPressed: Bool) -> some View {
        switch style {
        case .primary:
            Capsule()
                .fill(.tint)
                .glassEffect()
        case .secondary:
            Capsule()
                .fill(.clear)
                .glassEffect()
        case .compact:
            Capsule()
                .fill(.clear)
                .glassEffect(.regular, in: .capsule)
        case .large:
            RoundedRectangle(cornerRadius: 16)
                .fill(.clear)
                .glassEffect()
        }
    }
}

// MARK: - Icon-Only Glass Button

struct GlassIconButton: View {
    let icon: String
    let size: GlassIconSize
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    init(_ icon: String, size: GlassIconSize = .regular, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(size.font)
                .frame(width: size.dimension, height: size.dimension)
        }
        .buttonStyle(GlassIconButtonStyle(size: size, isEnabled: isEnabled))
    }
}

enum GlassIconSize {
    case small
    case regular
    case large

    var dimension: CGFloat {
        switch self {
        case .small: return 32
        case .regular: return 44
        case .large: return 56
        }
    }

    var font: Font {
        switch self {
        case .small: return .body
        case .regular: return .title3
        case .large: return .title2
        }
    }
}

private struct GlassIconButtonStyle: ButtonStyle {
    let size: GlassIconSize
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background {
                Circle()
                    .fill(.clear)
                    .glassEffect(.regular, in: .circle)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(.tint)
                        .glassEffect(.regular.tint(Color.accentColor), in: .circle)
                }
        }
        .buttonStyle(FloatingButtonStyle())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

private struct FloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Glass Buttons") {
    VStack(spacing: 20) {
        GlassButton("Primary Action", icon: "plus", style: .primary) {}

        GlassButton("Secondary", icon: "arrow.right", style: .secondary) {}

        GlassButton("Compact", style: .compact) {}

        HStack(spacing: 12) {
            GlassIconButton("heart") {}
            GlassIconButton("square.and.arrow.up") {}
            GlassIconButton("ellipsis") {}
        }

        FloatingActionButton(icon: "plus") {}
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
