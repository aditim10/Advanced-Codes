import UIKit

// MARK: - Theme definition
struct AppTheme {
    let name: String

    // Backgrounds
    let background:       UIColor
    let cardBackground:   UIColor
    let navBarBackground: UIColor

    // Gradient (login screen + banner)
    let gradientColors:   [UIColor]

    // Text
    let bodyText:         UIColor
    let secondaryText:    UIColor

    // Accents
    let accentPrimary:    UIColor   // purple in light, softer violet in dark
    let accentSecondary:  UIColor   // pink

    // Shimmer / placeholder
    let shimmerColor:     UIColor

    // Misc
    let amberScore:       UIColor
    let statusBarStyle:   UIStatusBarStyle
}

extension AppTheme {

    static let pastelLight = AppTheme(
        name: "Light",
        background:       UIColor(red: 0.97, green: 0.96, blue: 1.00, alpha: 1),
        cardBackground:   UIColor.white,
        navBarBackground: UIColor.white,
        gradientColors:   [
            UIColor(red: 0.92, green: 0.87, blue: 1.00, alpha: 1),
            UIColor(red: 1.00, green: 0.88, blue: 0.94, alpha: 1),
            UIColor(red: 1.00, green: 0.93, blue: 0.87, alpha: 1)
        ],
        bodyText:         UIColor(red: 0.10, green: 0.06, blue: 0.20, alpha: 1),  // near-black purple
        secondaryText:    UIColor(red: 0.35, green: 0.28, blue: 0.50, alpha: 1),  // medium purple, still readable
        accentPrimary:    UIColor(red: 0.48, green: 0.28, blue: 0.78, alpha: 1),  // strong purple
        accentSecondary:  UIColor(red: 0.85, green: 0.30, blue: 0.55, alpha: 1),  // strong pink
        shimmerColor:     UIColor(red: 0.88, green: 0.84, blue: 0.96, alpha: 1),
        amberScore:       UIColor(red: 0.80, green: 0.52, blue: 0.05, alpha: 1),  // darker amber — readable on white
        statusBarStyle:   .darkContent
    )

    static let dark = AppTheme(
        name: "Dark",
        background:       UIColor(red: 0.09, green: 0.08, blue: 0.13, alpha: 1),  // deep dark purple
        cardBackground:   UIColor(red: 0.17, green: 0.15, blue: 0.24, alpha: 1),  // lifted surface
        navBarBackground: UIColor(red: 0.13, green: 0.11, blue: 0.19, alpha: 1),
        gradientColors:   [
            UIColor(red: 0.18, green: 0.10, blue: 0.30, alpha: 1),
            UIColor(red: 0.22, green: 0.10, blue: 0.26, alpha: 1),
            UIColor(red: 0.09, green: 0.08, blue: 0.15, alpha: 1)
        ],
        bodyText:         UIColor(red: 0.95, green: 0.93, blue: 1.00, alpha: 1),  // near-white
        secondaryText:    UIColor(red: 0.72, green: 0.67, blue: 0.88, alpha: 1),  // light lavender, clearly visible
        accentPrimary:    UIColor(red: 0.76, green: 0.58, blue: 1.00, alpha: 1),  // bright violet
        accentSecondary:  UIColor(red: 1.00, green: 0.55, blue: 0.75, alpha: 1),  // bright pink
        shimmerColor:     UIColor(red: 0.24, green: 0.20, blue: 0.34, alpha: 1),
        amberScore:       UIColor(red: 1.00, green: 0.80, blue: 0.25, alpha: 1),  // bright gold
        statusBarStyle:   .lightContent
    )

    static let all: [AppTheme] = [.pastelLight, .dark]
}

// MARK: - ThemeMode

/// How the active ``AppTheme`` is chosen.
///
/// `auto` follows the device's Light/Dark setting (so the static launch screen,
/// which also follows the system, always matches the app). `light`/`dark` are
/// explicit user overrides.
enum ThemeMode: String, CaseIterable {
    case auto, light, dark

    var displayName: String {
        switch self {
        case .auto:  return "Auto (System)"
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }

    /// The interface style to force on the app's window. `auto` defers to the
    /// system (`.unspecified`), which is what keeps the launch screen in sync.
    var overrideStyle: UIUserInterfaceStyle {
        switch self {
        case .auto:  return .unspecified
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

// MARK: - ThemeManager

final class ThemeManager {

    static let shared = ThemeManager()

    /// Notification all VCs observe to re-apply colours when the theme changes.
    static let didChangeTheme = Notification.Name("ThemeManagerDidChangeTheme")

    /// The user's chosen mode (persisted). Defaults to `auto`.
    private(set) var mode: ThemeMode

    /// The latest known *system* appearance, fed in from the window's traits.
    private var systemStyle: UIUserInterfaceStyle = .light

    /// The concrete palette currently in effect, resolved from `mode` + system.
    private(set) var current: AppTheme

    private init() {
        let saved = UserDefaults.standard.string(forKey: StorageKey.themeMode)
        mode = saved.flatMap(ThemeMode.init(rawValue:)) ?? .auto
        current = .pastelLight
        current = resolvedTheme()
    }

    /// Interface style the window should adopt for the current mode.
    var overrideStyle: UIUserInterfaceStyle { mode.overrideStyle }

    /// Resolves the concrete palette from the mode and the system appearance.
    private func resolvedTheme() -> AppTheme {
        switch mode {
        case .light: return .pastelLight
        case .dark:  return .dark
        case .auto:  return systemStyle == .dark ? .dark : .pastelLight
        }
    }

    /// Fed by the window whenever the system appearance changes. Re-resolves the
    /// palette when in `auto` mode.
    func updateSystemStyle(_ style: UIUserInterfaceStyle) {
        let resolved: UIUserInterfaceStyle = (style == .unspecified) ? .light : style
        guard systemStyle != resolved else { return }
        systemStyle = resolved
        if mode == .auto { recompute() }
    }

    /// Switches the user-facing theme mode and notifies observers.
    func setMode(_ newMode: ThemeMode) {
        guard newMode != mode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: StorageKey.themeMode)
        recompute()
    }

    private func recompute() {
        current = resolvedTheme()
        NotificationCenter.default.post(name: ThemeManager.didChangeTheme, object: nil)
    }
}
