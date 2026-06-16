//
//  LoginPresenter.swift
//  AnimeApp
//
//  VIP Presenter for Login: translates the Interactor's outcome into simple
//  display calls (loading flag, error message, success).
//

import Foundation

@MainActor
protocol LoginPresentationLogic {
    func presentLoading(_ isLoading: Bool)
    func presentResult(response: Login.SignIn.Response)
}

@MainActor
final class LoginPresenter: LoginPresentationLogic {

    weak var viewController: LoginDisplayLogic?

    func presentLoading(_ isLoading: Bool) {
        viewController?.displayLoading(isLoading)
    }

    func presentResult(response: Login.SignIn.Response) {
        switch response.outcome {
        case .success:
            viewController?.displaySignInSuccess()
        case .failure(let reason):
            viewController?.displayError(Login.ErrorViewModel(message: reason))
        }
    }
}
