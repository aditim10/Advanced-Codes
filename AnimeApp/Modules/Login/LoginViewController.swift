//
//  LoginViewController.swift
//  AnimeApp
//
//  VIP View for Login. It owns presentation only (gradient, theming, entrance
//  animation, validation shake) and forwards the sign-in intent to the
//  Interactor. Auth logic and navigation live in the Interactor and Router.
//

import UIKit

@MainActor
protocol LoginDisplayLogic: AnyObject {
    func displayLoading(_ isLoading: Bool)
    func displayError(_ viewModel: Login.ErrorViewModel)
    func displaySignInSuccess()
}

final class LoginViewController: UIViewController, LoginDisplayLogic {

    // MARK: - IBOutlets
    @IBOutlet weak var logoLabel:        UILabel!
    @IBOutlet weak var taglineLabel:     UILabel!
    @IBOutlet weak var formCard:         UIView!
    @IBOutlet weak var emailField:       UITextField!
    @IBOutlet weak var passwordField:    UITextField!
    @IBOutlet weak var errorLabel:       UILabel!
    @IBOutlet weak var loginButton:      UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var hintLabel:        UILabel!

    // MARK: - VIP collaborators
    var interactor: LoginBusinessLogic?
    var router: LoginRoutingLogic?

    private var gradientLayer: CAGradientLayer?

    // MARK: - Init / VIP setup
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let interactor = LoginInteractor()
        let presenter = LoginPresenter()
        let router = LoginRouter()

        interactor.presenter = presenter
        presenter.viewController = self
        router.viewController = self

        self.interactor = interactor
        self.router = router
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGradient()
        applyTheme()
        animateEntrance()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeManager.shared.current.statusBarStyle
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Gradient background
    private func setupGradient() {
        let g = CAGradientLayer()
        g.locations  = [0, 0.55, 1]
        g.startPoint = CGPoint(x: 0, y: 0)
        g.endPoint   = CGPoint(x: 1, y: 1)
        g.frame      = view.bounds
        view.layer.insertSublayer(g, at: 0)
        gradientLayer = g
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = view.bounds
    }

    // MARK: - Theme
    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current

        gradientLayer?.colors = theme.gradientColors.map { $0.cgColor }

        logoLabel.textColor    = theme.accentPrimary
        logoLabel.font         = .systemFont(ofSize: 42, weight: .black)

        taglineLabel.textColor = theme.secondaryText
        taglineLabel.font      = .systemFont(ofSize: 15, weight: .regular)
        taglineLabel.text      = AppStrings.Login.tagline

        formCard.backgroundColor    = theme.cardBackground
        formCard.layer.cornerRadius = 24
        formCard.layer.shadowColor  = theme.accentPrimary.withAlphaComponent(0.18).cgColor
        formCard.layer.shadowOpacity = 1
        formCard.layer.shadowRadius  = 24
        formCard.layer.shadowOffset  = CGSize(width: 0, height: 8)

        styleTextField(emailField,    placeholder: AppStrings.Login.emailPlaceholder,    icon: "envelope", secure: false, theme: theme)
        styleTextField(passwordField, placeholder: AppStrings.Login.passwordPlaceholder, icon: "lock",     secure: true,  theme: theme)
        emailField.keyboardType     = .emailAddress
        emailField.returnKeyType    = .next
        passwordField.returnKeyType = .done
        emailField.delegate         = self
        passwordField.delegate      = self

        loginButton.setTitle(AppStrings.Login.signIn, for: .normal)
        loginButton.titleLabel?.font      = .systemFont(ofSize: 16, weight: .semibold)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.backgroundColor       = theme.accentPrimary
        loginButton.layer.cornerRadius    = 16
        loginButton.layer.shadowColor     = theme.accentPrimary.cgColor
        loginButton.layer.shadowOpacity   = 0.4
        loginButton.layer.shadowRadius    = 10
        loginButton.layer.shadowOffset    = CGSize(width: 0, height: 4)

        errorLabel.textColor     = theme.accentSecondary
        errorLabel.font          = .systemFont(ofSize: 13)
        errorLabel.numberOfLines = 0

        hintLabel.text      = AppStrings.Login.hint
        hintLabel.textColor = theme.secondaryText.withAlphaComponent(0.7)
        hintLabel.font      = .systemFont(ofSize: 12)

        // Storyboard labels inherit a dynamic default background that turns dark
        // under system Dark Mode; force them transparent so text stays readable.
        [logoLabel, taglineLabel, errorLabel, hintLabel].forEach {
            $0?.backgroundColor = .clear
            $0?.isOpaque = false
        }

        setNeedsStatusBarAppearanceUpdate()

        if view.gestureRecognizers?.isEmpty ?? true {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            // Without this the tap recognizer cancels touches headed for the text
            // fields and the Sign In button, leaving the whole screen unresponsive.
            tap.cancelsTouchesInView = false
            view.addGestureRecognizer(tap)
        }

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color            = .white
    }

    private func styleTextField(_ tf: UITextField, placeholder: String, icon: String,
                                 secure: Bool, theme: AppTheme) {
        tf.placeholder            = placeholder
        tf.isSecureTextEntry      = secure
        tf.backgroundColor        = theme.cardBackground.withAlphaComponent(0.8)
        tf.textColor              = theme.bodyText
        tf.tintColor              = theme.accentPrimary
        tf.layer.cornerRadius     = 14
        tf.layer.borderWidth      = 1.5
        tf.layer.borderColor      = theme.accentPrimary.withAlphaComponent(0.25).cgColor
        tf.autocorrectionType     = .no
        tf.autocapitalizationType = .none
        tf.borderStyle            = .none
        tf.font                   = .systemFont(ofSize: 15)

        let iconImage = UIImage(systemName: icon,
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        let iconView  = UIImageView(image: iconImage)
        iconView.tintColor    = theme.accentPrimary.withAlphaComponent(0.6)
        iconView.contentMode  = .scaleAspectFit
        iconView.frame        = CGRect(x: 0, y: 0, width: 38, height: 20)
        tf.leftView           = iconView
        tf.leftViewMode       = .always

        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: theme.secondaryText.withAlphaComponent(0.5)])

        tf.addTarget(self, action: #selector(fieldFocused(_:)), for: .editingDidBegin)
        tf.addTarget(self, action: #selector(fieldBlurred(_:)), for: .editingDidEnd)
    }

    @objc private func fieldFocused(_ tf: UITextField) {
        let theme = ThemeManager.shared.current
        UIView.animate(withDuration: 0.2) {
            tf.layer.borderColor = theme.accentPrimary.cgColor
            tf.backgroundColor   = theme.cardBackground
        }
    }
    @objc private func fieldBlurred(_ tf: UITextField) {
        let theme = ThemeManager.shared.current
        UIView.animate(withDuration: 0.2) {
            tf.layer.borderColor = theme.accentPrimary.withAlphaComponent(0.25).cgColor
            tf.backgroundColor   = theme.cardBackground.withAlphaComponent(0.8)
        }
    }

    // MARK: - Entrance animation
    private func animateEntrance() {
        let views: [UIView?] = [logoLabel, taglineLabel, formCard, hintLabel]
        views.forEach {
            $0?.alpha     = 0
            $0?.transform = CGAffineTransform(translationX: 0, y: 40)
        }
        views.enumerated().forEach { idx, v in
            UIView.animate(withDuration: 0.65, delay: 0.08 + Double(idx) * 0.1,
                           usingSpringWithDamping: 0.82, initialSpringVelocity: 0) {
                v?.alpha = 1; v?.transform = .identity
            }
        }
    }

    // MARK: - IBActions
    @IBAction func loginTapped(_ sender: UIButton) {
        dismissKeyboard()
        hideError()
        interactor?.signIn(request: Login.SignIn.Request(
            email: emailField.text, password: passwordField.text))
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    // MARK: - LoginDisplayLogic

    func displayLoading(_ isLoading: Bool) {
        loginButton.isEnabled = !isLoading
        loginButton.alpha     = isLoading ? 0.65 : 1.0
        isLoading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    }

    func displayError(_ viewModel: Login.ErrorViewModel) {
        errorLabel.text = viewModel.message
        UIView.animate(withDuration: 0.3) { self.errorLabel.alpha = 1 }
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration = 0.4
        anim.values   = [-8, 8, -6, 6, -4, 4, 0]
        formCard.layer.add(anim, forKey: "shake")
    }

    func displaySignInSuccess() {
        router?.routeToHome()
    }

    private func hideError() {
        UIView.animate(withDuration: 0.2) { self.errorLabel.alpha = 0 }
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField { passwordField.becomeFirstResponder() }
        else { loginTapped(loginButton) }
        return true
    }
}
