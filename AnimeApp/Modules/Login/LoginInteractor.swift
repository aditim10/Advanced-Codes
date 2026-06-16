//
//  LoginInteractor.swift
//  AnimeApp
//
//  VIP Interactor for Login: owns validation + the (simulated) auth flow and
//  publishes analytics for each outcome. UIKit-free.
//

import Foundation

@MainActor
protocol LoginBusinessLogic {
    func signIn(request: Login.SignIn.Request)
}

@MainActor
final class LoginInteractor: LoginBusinessLogic {

    var presenter: LoginPresentationLogic?

    private let analytics: AnalyticsManager
    private var task: Task<Void, Never>?

    init(analytics: AnalyticsManager = .shared) {
        self.analytics = analytics
    }

    func signIn(request: Login.SignIn.Request) {
        let email = request.email ?? ""
        analytics.publish(LoginAnalyticsEvent.attempt(email: email))

        if let reason = validate(email: request.email, password: request.password) {
            analytics.publish(LoginAnalyticsEvent.invalidCredentials(reason: reason))
            presenter?.presentResult(response: Login.SignIn.Response(outcome: .failure(reason: reason)))
            return
        }

        task?.cancel()
        task = Task { await performSignIn(email: email) }
    }

    // MARK: - Work

    /// Simulated auth. A real implementation would call an auth endpoint here and
    /// emit `LoginAnalyticsEvent.failure` on a rejected response.
    private func performSignIn(email: String) async {
        presenter?.presentLoading(true)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        presenter?.presentLoading(false)

        Session.signIn(email: email)
        analytics.publish(LoginAnalyticsEvent.success(email: email))
        presenter?.presentResult(response: Login.SignIn.Response(outcome: .success(email: email)))
    }

    /// Returns a user-facing error message if the input is invalid, else `nil`.
    private func validate(email: String?, password: String?) -> String? {
        guard let email, !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            return AppStrings.Login.errorEmptyEmail
        }
        guard email.contains("@"), email.contains(".") else {
            return AppStrings.Login.errorInvalidEmail
        }
        guard let password, !password.isEmpty else {
            return AppStrings.Login.errorEmptyPassword
        }
        guard password.count >= 6 else {
            return AppStrings.Login.errorShortPassword
        }
        return nil
    }
}
