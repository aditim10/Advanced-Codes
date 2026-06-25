//
//  HomeRouter.swift
//  AnimeApp
//
//  The VIP **Router** for Home: it owns all navigation and screen-to-screen data
//  passing, keeping the View free of "where do I go next" logic. It reads the
//  module's `HomeDataStore` to resolve the domain object behind a tapped id, so
//  the View only ever passes lightweight identifiers.
//

import UIKit
import AdSDK

@MainActor
protocol HomeRoutingLogic {
    func routeToDetail(animeID: Int)
    func routeToSeeAll(genreID: Int)
    func routeToSearch()
    func presentProfileMenu(from sender: UIButton)
}

@MainActor
protocol HomeDataPassing {
    var dataStore: HomeDataStore? { get }
}

@MainActor
final class HomeRouter: HomeRoutingLogic, HomeDataPassing {

    weak var viewController: HomeViewController?
    var dataStore: HomeDataStore?

    // MARK: - Routing

    func routeToDetail(animeID: Int) {
        guard let anime = dataStore?.anime(withID: animeID) else { return }
        let storyboard = UIStoryboard(name: StoryboardID.main, bundle: nil)
        guard let detail = storyboard.instantiateViewController(
            withIdentifier: StoryboardID.animeDetail) as? AnimeDetailViewController else { return }
        detail.configure(with: anime)
        viewController?.navigationController?.pushViewController(detail, animated: true)
    }

    func routeToSeeAll(genreID: Int) {
        guard let section = dataStore?.section(withGenreID: genreID) else { return }
        let seeAll = SeeAllViewController(title: section.title, genreID: section.genreID)
        viewController?.navigationController?.pushViewController(seeAll, animated: true)
    }

    func routeToSearch() {
        viewController?.navigationController?.pushViewController(SearchViewController(), animated: true)
    }

    // MARK: - Profile / theme menu

    func presentProfileMenu(from sender: UIButton) {
        guard let viewController else { return }
        let sheet = UIAlertController(
            title: "👤 \(Session.displayName)",
            message: Session.email,
            preferredStyle: .actionSheet)
        sheet.popoverPresentationController?.sourceView = sender

        sheet.addAction(UIAlertAction(title: "🎨 Change Theme", style: .default) { [weak self] _ in
            self?.presentThemePicker(from: sender)
        })
        sheet.addAction(UIAlertAction(title: "📺 Ad Preferences", style: .default) { [weak self] _ in
            self?.presentAdTierPicker(from: sender)
        })
        sheet.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            Session.logout()
            SceneDelegate.shared?.switchToLogin()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        viewController.present(sheet, animated: true)
    }

    private func presentThemePicker(from sender: UIButton) {
        guard let viewController else { return }
        let picker = UIAlertController(title: "Choose Theme", message: nil, preferredStyle: .actionSheet)
        for mode in ThemeMode.allCases {
            let isCurrent = mode == ThemeManager.shared.mode
            let title = isCurrent ? "✓ \(mode.displayName)" : mode.displayName
            picker.addAction(UIAlertAction(title: title, style: .default) { [weak viewController] _ in
                ThemeManager.shared.setMode(mode)
                SceneDelegate.shared?.applyThemeStyle()
                viewController?.refreshTheme()
            })
        }
        picker.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = picker.popoverPresentationController {
            pop.sourceView = sender
            pop.sourceRect = sender.bounds
        }
        viewController.present(picker, animated: true)
    }

    /// Lets the viewer pick their advertising tier (persisted to `Session`). The
    /// choice takes effect the next time the custom player opens.
    private func presentAdTierPicker(from sender: UIButton) {
        guard let viewController else { return }
        let picker = UIAlertController(
            title: AppStrings.Ads.preferencesTitle,
            message: AppStrings.Ads.preferencesMessage,
            preferredStyle: .actionSheet)
        for tier in AdTier.allCases {
            let isCurrent = tier == Session.adTier
            let label = AppStrings.Ads.tierName(tier)
            let title = isCurrent ? "✓ \(label)" : label
            picker.addAction(UIAlertAction(title: title, style: .default) { _ in
                Session.adTier = tier
            })
        }
        picker.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = picker.popoverPresentationController {
            pop.sourceView = sender
            pop.sourceRect = sender.bounds
        }
        viewController.present(picker, animated: true)
    }
}
