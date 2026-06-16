//
//  CharacterDetailRouter.swift
//  AnimeApp
//
//  VIP Router for Character Detail: back navigation only (leaf screen).
//

import UIKit

@MainActor
protocol CharacterDetailRoutingLogic {
    func dismiss()
}

@MainActor
final class CharacterDetailRouter: CharacterDetailRoutingLogic {

    weak var viewController: CharacterDetailViewController?

    func dismiss() {
        viewController?.navigationController?.popViewController(animated: true)
    }
}
