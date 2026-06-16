//
//  SeeAllRouter.swift
//  AnimeApp
//
//  VIP Router for the "See all" grid: detail navigation.
//

import UIKit

@MainActor
protocol SeeAllRoutingLogic {
    func routeToDetail(animeID: Int)
}

@MainActor
protocol SeeAllDataPassing {
    var dataStore: SeeAllDataStore? { get }
}

@MainActor
final class SeeAllRouter: SeeAllRoutingLogic, SeeAllDataPassing {

    weak var viewController: SeeAllViewController?
    var dataStore: SeeAllDataStore?

    func routeToDetail(animeID: Int) {
        guard let anime = dataStore?.anime(withID: animeID) else { return }
        let storyboard = UIStoryboard(name: StoryboardID.main, bundle: nil)
        guard let detail = storyboard.instantiateViewController(
            withIdentifier: StoryboardID.animeDetail) as? AnimeDetailViewController else { return }
        detail.configure(with: anime)
        viewController?.navigationController?.pushViewController(detail, animated: true)
    }
}
