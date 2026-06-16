//
//  DetailRouter.swift
//  AnimeApp
//
//  VIP Router for Anime Detail: back navigation and the (placeholder) watch flow.
//

import UIKit

@MainActor
protocol DetailRoutingLogic {
    func dismiss()
    func presentWatch(title: String)
    func routeToCharacter(id: Int, name: String, imageURL: URL?)
}

@MainActor
final class DetailRouter: DetailRoutingLogic {

    weak var viewController: AnimeDetailViewController?

    func dismiss() {
        viewController?.navigationController?.popViewController(animated: true)
    }

    func presentWatch(title: String) {
        let alert = UIAlertController(
            title: "▶ Watch Now",
            message: "Would launch player for \(title).",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppStrings.Common.ok, style: .default))
        viewController?.present(alert, animated: true)
    }

    /// Pushes the Character Detail screen, seeded with the name/image we already
    /// have so it renders instantly while the full profile loads.
    func routeToCharacter(id: Int, name: String, imageURL: URL?) {
        let characterVC = CharacterDetailViewController(characterID: id, name: name, imageURL: imageURL)
        viewController?.navigationController?.pushViewController(characterVC, animated: true)
    }
}
