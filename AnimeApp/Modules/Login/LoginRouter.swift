//
//  LoginRouter.swift
//  AnimeApp
//
//  VIP Router for Login: the only navigation is swapping the root to Home on a
//  successful sign-in.
//

import UIKit

@MainActor
protocol LoginRoutingLogic {
    func routeToHome()
}

@MainActor
final class LoginRouter: LoginRoutingLogic {

    weak var viewController: LoginViewController?

    func routeToHome() {
        SceneDelegate.shared?.switchToHome(animated: true)
    }
}
