//  AppDelegate.swift

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Wire up analytics providers and fire the app-launch event.
        AnalyticsManager.shared.bootstrap()

        // Apply the current theme to the global navigation-bar appearance, and
        // keep it in sync whenever the theme (or system appearance) changes.
        configureNavigationBarAppearance(for: ThemeManager.shared.current)
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @objc private func themeChanged() {
        configureNavigationBarAppearance(for: ThemeManager.shared.current)
    }

    /// Styles the shared `UINavigationBar` appearance to match `theme`.
    private func configureNavigationBarAppearance(for theme: AppTheme) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme.navBarBackground
        appearance.titleTextAttributes = [.foregroundColor: theme.bodyText]
        appearance.shadowColor = theme.accentPrimary.withAlphaComponent(0.2)

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = theme.accentPrimary
    }
}

// MARK: - ThemeWindow

/// A window that forwards system appearance (Light/Dark) changes to
/// ``ThemeManager`` so the app can re-theme itself live when in Auto mode.
final class ThemeWindow: UIWindow {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else { return }
        ThemeManager.shared.updateSystemStyle(traitCollection.userInterfaceStyle)
    }
}

// MARK: - SceneDelegate

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Build the window ourselves.
        let window = ThemeWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = ThemeManager.shared.overrideStyle
        // Seed the manager with the real system appearance before the first render.
        ThemeManager.shared.updateSystemStyle(window.traitCollection.userInterfaceStyle)

        let rootID = Session.isLoggedIn ? StoryboardID.homeNavigation
                                        : StoryboardID.loginNavigation
        let storyboard = UIStoryboard(name: StoryboardID.main, bundle: nil)
        window.rootViewController = storyboard.instantiateViewController(withIdentifier: rootID)

        self.window = window
        window.makeKeyAndVisible()
    }

    /// Swaps the root to the home flow.
    func switchToHome(animated: Bool) {
        let storyboard = UIStoryboard(name: StoryboardID.main, bundle: nil)
        guard let nav = storyboard.instantiateViewController(
            withIdentifier: StoryboardID.homeNavigation) as? UINavigationController else { return }
        window?.rootViewController = nav
        if animated, let window {
            UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: nil)
        }
    }

    /// Swaps the root back to the login flow (after sign out).
    func switchToLogin() {
        let storyboard = UIStoryboard(name: StoryboardID.main, bundle: nil)
        guard let nav = storyboard.instantiateViewController(
            withIdentifier: StoryboardID.loginNavigation) as? UINavigationController else { return }
        window?.rootViewController = nav
        if let window {
            UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: nil)
        }
    }

    /// Re-applies the window's interface style after a theme-mode change.
    func applyThemeStyle() {
        window?.overrideUserInterfaceStyle = ThemeManager.shared.overrideStyle
    }

    /// Convenience accessor for the active scene delegate.
    static var shared: SceneDelegate? {
        UIApplication.shared.connectedScenes
            .compactMap { $0.delegate as? SceneDelegate }.first
    }
}
