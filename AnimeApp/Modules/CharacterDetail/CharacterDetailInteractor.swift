//
//  CharacterDetailInteractor.swift
//  AnimeApp
//
//  VIP Interactor for Character Detail: fetches the full character profile.
//  UIKit-free.
//

import Foundation

@MainActor
protocol CharacterDetailBusinessLogic {
    func load(request: CharacterDetail.Load.Request)
}

@MainActor
final class CharacterDetailInteractor: CharacterDetailBusinessLogic {

    var presenter: CharacterDetailPresentationLogic?

    private let characterID: Int
    private let service: CharacterServicing
    private var task: Task<Void, Never>?

    init(characterID: Int, service: CharacterServicing = CharacterService()) {
        self.characterID = characterID
        self.service = service
    }

    func load(request: CharacterDetail.Load.Request) {
        presenter?.presentLoading(true)
        task?.cancel()
        task = Task { await fetch() }
    }

    private func fetch() async {
        do {
            let character = try await service.characterFull(id: characterID)
            if Task.isCancelled { return }
            presenter?.presentLoading(false)
            presenter?.presentCharacter(response: CharacterDetail.Load.Response(character: character))
        } catch {
            if Task.isCancelled { return }
            presenter?.presentLoading(false)
            presenter?.presentError(error.localizedDescription)
        }
    }
}
