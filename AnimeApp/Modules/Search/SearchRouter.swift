//
//  SearchRouter.swift
//  AnimeApp
//
//  VIP Router for Search: detail navigation + dismissal.
//

import UIKit

@MainActor
protocol SearchRoutingLogic {
    func routeToDetail(animeID: Int)
    func dismiss()
}

@MainActor
protocol SearchDataPassing {
    var dataStore: SearchDataStore? { get }
}

@MainActor
final class SearchRouter: SearchRoutingLogic, SearchDataPassing {

    weak var viewController: SearchViewController?
    var dataStore: SearchDataStore?

    func routeToDetail(animeID: Int) {
        guard let anime = dataStore?.anime(withID: animeID) else { return }
        let storyboard = UIStoryboard(name: StoryboardID.main, bundle: nil)
        guard let detail = storyboard.instantiateViewController(
            withIdentifier: StoryboardID.animeDetail) as? AnimeDetailViewController else { return }
        detail.configure(with: anime)
        viewController?.view.endEditing(true)
        viewController?.navigationController?.pushViewController(detail, animated: true)
    }

    func dismiss() {
        viewController?.navigationController?.popViewController(animated: true)
    }
}
