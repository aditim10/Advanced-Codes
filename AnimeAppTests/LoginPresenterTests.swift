//
//  LoginPresenterTests.swift
//  AnimeAppTests
//
//  Verifies the Login Presenter's UI logic: it translates the Interactor's
//  sign-in outcome into the right View calls (loading flag, success route,
//  error view model).
//

import XCTest
@testable import AnimeApp

@MainActor
final class SpyLoginDisplay: LoginDisplayLogic {
    private(set) var loadingStates: [Bool] = []
    private(set) var didSignInSuccess = false
    private(set) var lastError: Login.ErrorViewModel?

    func displayLoading(_ isLoading: Bool) { loadingStates.append(isLoading) }
    func displayError(_ viewModel: Login.ErrorViewModel) { lastError = viewModel }
    func displaySignInSuccess() { didSignInSuccess = true }
}

@MainActor
final class LoginPresenterTests: XCTestCase {

    private func makePresenter() -> (LoginPresenter, SpyLoginDisplay) {
        let presenter = LoginPresenter()
        let display = SpyLoginDisplay()
        presenter.viewController = display
        return (presenter, display)
    }

    func testPresentLoadingForwardsFlag() {
        let (presenter, display) = makePresenter()
        presenter.presentLoading(true)
        presenter.presentLoading(false)
        XCTAssertEqual(display.loadingStates, [true, false])
    }

    func testSuccessOutcomeRoutesToSuccess() {
        let (presenter, display) = makePresenter()
        presenter.presentResult(response: Login.SignIn.Response(outcome: .success(email: "a@b.com")))
        XCTAssertTrue(display.didSignInSuccess)
        XCTAssertNil(display.lastError)
    }

    func testFailureOutcomeForwardsErrorMessage() {
        let (presenter, display) = makePresenter()
        presenter.presentResult(response: Login.SignIn.Response(outcome: .failure(reason: "Bad email")))
        XCTAssertFalse(display.didSignInSuccess)
        XCTAssertEqual(display.lastError?.message, "Bad email")
    }
}
