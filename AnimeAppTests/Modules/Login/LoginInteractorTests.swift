//
//  LoginInteractorTests.swift
//  AnimeAppTests
//
//  Covers the Login VIP Interactor: validation outcomes (emitted synchronously),
//  the analytics fired on an invalid attempt, and the simulated happy path.
//

import XCTest
import AnalyticsKit
@testable import AnimeApp

@MainActor
final class SpyLoginPresenter: LoginPresentationLogic {
    private(set) var loadingStates: [Bool] = []
    private(set) var lastResponse: Login.SignIn.Response?
    var onResult: ((Login.SignIn.Response) -> Void)?

    func presentLoading(_ isLoading: Bool) { loadingStates.append(isLoading) }
    func presentResult(response: Login.SignIn.Response) {
        lastResponse = response
        onResult?(response)
    }
}

private extension Login.SignIn.Response.Outcome {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}

@MainActor
final class LoginInteractorTests: XCTestCase {

    private func makeInteractor() -> (LoginInteractor, SpyLoginPresenter, SpyAnalyticsProvider) {
        let bus = AnalyticsManager(delivery: .synchronous)
        let spy = SpyAnalyticsProvider()
        bus.register(spy)
        let interactor = LoginInteractor(analytics: bus)
        let presenter = SpyLoginPresenter()
        interactor.presenter = presenter
        return (interactor, presenter, spy)
    }

    func testRejectsEmptyName() {
        let (interactor, presenter, _) = makeInteractor()
        interactor.signIn(request: .init(email: "a@b.com", password: "secret123", name: "  "))
        XCTAssertEqual(presenter.lastResponse?.outcome.isFailure, true)
    }

    func testRejectsEmptyEmail() {
        let (interactor, presenter, _) = makeInteractor()
        interactor.signIn(request: .init(email: "", password: "secret123", name: "Aditi"))
        XCTAssertEqual(presenter.lastResponse?.outcome.isFailure, true)
    }

    func testRejectsMalformedEmail() {
        let (interactor, presenter, _) = makeInteractor()
        interactor.signIn(request: .init(email: "not-an-email", password: "secret123", name: "Aditi"))
        XCTAssertEqual(presenter.lastResponse?.outcome.isFailure, true)
    }

    func testRejectsShortPassword() {
        let (interactor, presenter, _) = makeInteractor()
        interactor.signIn(request: .init(email: "a@b.com", password: "123", name: "Aditi"))
        XCTAssertEqual(presenter.lastResponse?.outcome.isFailure, true)
    }

    func testInvalidLoginFiresAttemptAndInvalidCredentials() {
        let (interactor, _, spy) = makeInteractor()
        interactor.signIn(request: .init(email: "bad", password: "1", name: "Aditi"))
        XCTAssertTrue(spy.contains("login_attempt"))
        XCTAssertTrue(spy.contains("login_invalid_credentials"))
        XCTAssertFalse(spy.contains("login_success"))
    }

    func testValidCredentialsCompleteSignIn() async {
        let (interactor, presenter, spy) = makeInteractor()
        let exp = expectation(description: "signed in")
        exp.assertForOverFulfill = false
        presenter.onResult = { response in
            if case .success = response.outcome { exp.fulfill() }
        }

        interactor.signIn(request: .init(email: "a@b.com", password: "secret123", name: "Aditi"))
        await fulfillment(of: [exp], timeout: 3)

        XCTAssertTrue(spy.contains("login_success"))
        XCTAssertEqual(Session.email, "a@b.com")
        XCTAssertEqual(Session.name, "Aditi")
        Session.logout()   // clean up shared UserDefaults state
    }
}
