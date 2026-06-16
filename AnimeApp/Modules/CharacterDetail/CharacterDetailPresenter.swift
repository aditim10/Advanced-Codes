//
//  CharacterDetailPresenter.swift
//  AnimeApp
//
//  VIP Presenter for Character Detail: maps the domain character into a dumb,
//  render-ready snapshot.
//

import Foundation

@MainActor
protocol CharacterDetailPresentationLogic {
    func presentLoading(_ isLoading: Bool)
    func presentCharacter(response: CharacterDetail.Load.Response)
    func presentError(_ message: String)
}

@MainActor
final class CharacterDetailPresenter: CharacterDetailPresentationLogic {

    weak var viewController: CharacterDetailDisplayLogic?

    func presentLoading(_ isLoading: Bool) {
        viewController?.displayLoading(isLoading)
    }

    func presentCharacter(response: CharacterDetail.Load.Response) {
        let character = response.character

        let nicknames = character.nicknames.isEmpty
            ? nil
            : character.nicknames.joined(separator: ", ")

        let favorites = character.favorites > 0
            ? AppStrings.Character.favorites(
                NumberFormatter.localizedString(from: NSNumber(value: character.favorites), number: .decimal))
            : nil

        let about = character.about?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Voice actors grouped with Japanese first, then alphabetically by language.
        let voiceActors = character.voices
            .sorted {
                let lhs = ($0.language == "Japanese" ? 0 : 1, $0.language)
                let rhs = ($1.language == "Japanese" ? 0 : 1, $1.language)
                return lhs < rhs
            }
            .map {
                CharacterDetail.VoiceActor(
                    name: $0.person.name,
                    language: $0.language,
                    imageURL: $0.person.imageURL)
            }

        let viewModel = CharacterDetail.ViewModel(
            name: character.name,
            kanji: (character.nameKanji?.isEmpty == false) ? character.nameKanji : nil,
            favorites: favorites,
            nicknames: nicknames,
            about: (about?.isEmpty == false) ? about : nil,
            imageURL: character.imageURL,
            voiceActors: voiceActors)

        viewController?.displayCharacter(viewModel)
    }

    func presentError(_ message: String) {
        viewController?.displayError(message)
    }
}
