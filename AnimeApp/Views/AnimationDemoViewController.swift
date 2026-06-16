import UIKit

final class AnimationDemoViewController: UIViewController {

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.register(DemoCell.self, forCellReuseIdentifier: DemoCell.id)
        tv.dataSource = self; tv.delegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let demos: [AnimationDemo] = [
        AnimationDemo(title: "Spring Animation",   subtitle: "UIView.animate with spring damping",            icon: "🌀", color: UIColor(red: 0.60, green: 0.45, blue: 0.90, alpha: 1)),
        AnimationDemo(title: "Keyframe Animation", subtitle: "Multi-step path with CAKeyframeAnimation",      icon: "🔑", color: UIColor(red: 0.91, green: 0.60, blue: 0.75, alpha: 1)),
        AnimationDemo(title: "Shake / Error",      subtitle: "Horizontal keyframe shake",                     icon: "📳", color: UIColor(red: 0.95, green: 0.50, blue: 0.55, alpha: 1)),
        AnimationDemo(title: "Pulse / Scale",      subtitle: "Repeating scale with CABasicAnimation",         icon: "💓", color: UIColor(red: 0.90, green: 0.55, blue: 0.80, alpha: 1)),
        AnimationDemo(title: "Flip Transition",    subtitle: "UIView.transition .transitionFlipFromRight",    icon: "🔄", color: UIColor(red: 0.45, green: 0.75, blue: 0.88, alpha: 1)),
        AnimationDemo(title: "Particle Burst",     subtitle: "CAEmitterLayer confetti effect",                icon: "🎉", color: UIColor(red: 0.95, green: 0.78, blue: 0.40, alpha: 1)),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Animation Demo"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        applyTheme()
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: ThemeManager.didChangeTheme, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeManager.shared.current.statusBarStyle
    }

    @objc private func themeChanged() { applyTheme() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current

        view.backgroundColor      = theme.background
        tableView.backgroundColor = theme.background
        tableView.separatorColor  = theme.accentPrimary.withAlphaComponent(0.18)

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor     = theme.navBarBackground
        navBarAppearance.titleTextAttributes = [.foregroundColor: theme.bodyText]
        navBarAppearance.shadowColor         = theme.accentPrimary.withAlphaComponent(0.2)
        navigationController?.navigationBar.standardAppearance   = navBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
        navigationController?.navigationBar.tintColor = theme.accentPrimary

        setNeedsStatusBarAppearanceUpdate()
        tableView.reloadData()
    }

    @objc private func doneTapped() { dismiss(animated: true) }

    // MARK: - Demos

    private func runDemo(index: Int, sourceView: UIView) {
        switch index {
        case 0: presentSpringDemo()
        case 1: presentKeyframeDemo()
        case 2: presentShakeDemo(on: sourceView)
        case 3: presentPulseDemo()
        case 4: presentFlipDemo()
        case 5: presentParticleDemo()
        default: break
        }
    }

    private func presentSpringDemo() {
        let overlay = makeOverlay()
        let box = makeBox(color: UIColor(red: 0.60, green: 0.45, blue: 0.90, alpha: 1), size: 90)
        box.center = CGPoint(x: view.bounds.midX, y: -60)
        overlay.addSubview(box)
        view.addSubview(overlay)
        let label = makeDemoLabel("Spring\nusingSpringWithDamping: 0.5")
        overlay.addSubview(label)
        label.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY + 90)
        UIView.animate(withDuration: 1.0, delay: 0,
                       usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
            box.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY - 20)
        }
        dismissOverlayAfter(2.5, overlay: overlay)
    }

    private func presentKeyframeDemo() {
        let overlay = makeOverlay()
        let box = makeBox(color: UIColor(red: 0.91, green: 0.60, blue: 0.75, alpha: 1), size: 70)
        box.center = CGPoint(x: 60, y: overlay.bounds.midY)
        overlay.addSubview(box); view.addSubview(overlay)
        let label = makeDemoLabel("Keyframe\nrelativeStartTime per step")
        overlay.addSubview(label)
        label.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY + 100)
        UIView.animateKeyframes(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse]) {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.25) {
                box.center = CGPoint(x: overlay.bounds.width - 60, y: overlay.bounds.midY - 80)
                box.transform = CGAffineTransform(rotationAngle: .pi / 2)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                box.center = CGPoint(x: overlay.bounds.width - 60, y: overlay.bounds.midY + 80)
                box.transform = CGAffineTransform(rotationAngle: .pi)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.25) {
                box.center = CGPoint(x: 60, y: overlay.bounds.midY + 80)
                box.transform = CGAffineTransform(rotationAngle: .pi * 1.5)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                box.center = CGPoint(x: 60, y: overlay.bounds.midY)
                box.transform = .identity
            }
        }
        dismissOverlayAfter(3.5, overlay: overlay)
    }

    private func presentShakeDemo(on sourceView: UIView) {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration = 0.5; anim.values = [-14, 14, -10, 10, -7, 7, -4, 4, 0]
        sourceView.layer.add(anim, forKey: "shake")
        let flash = CABasicAnimation(keyPath: "borderColor")
        flash.fromValue = UIColor(red: 0.91, green: 0.50, blue: 0.63, alpha: 1).cgColor
        flash.toValue   = UIColor.clear.cgColor; flash.duration = 0.5
        sourceView.layer.borderWidth = 2; sourceView.layer.cornerRadius = 12
        sourceView.layer.add(flash, forKey: "flash")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { sourceView.layer.borderWidth = 0 }
    }

    private func presentPulseDemo() {
        let overlay = makeOverlay()
        let circle = makeBox(color: UIColor(red: 0.90, green: 0.55, blue: 0.80, alpha: 1), size: 90)
        circle.layer.cornerRadius = 45
        circle.center = overlay.center
        overlay.addSubview(circle); view.addSubview(overlay)
        let label = makeDemoLabel("Pulse\nCABasicAnimation scale")
        overlay.addSubview(label)
        label.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY + 90)
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0; pulse.toValue = 1.35; pulse.duration = 0.55
        pulse.autoreverses = true; pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        circle.layer.add(pulse, forKey: "pulse")
        dismissOverlayAfter(3.0, overlay: overlay)
    }

    private func presentFlipDemo() {
        let overlay = makeOverlay(); view.addSubview(overlay)
        let card = UIView(frame: CGRect(x: 0, y: 0, width: 160, height: 220))
        card.layer.cornerRadius = 20; card.clipsToBounds = true
        card.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY - 20)
        let front = UIView(frame: card.bounds)
        front.backgroundColor = UIColor(red: 0.80, green: 0.70, blue: 0.98, alpha: 1)
        let fl = UILabel()
        fl.text = "FRONT\n🎌"; fl.font = .systemFont(ofSize: 22, weight: .bold)
        fl.textColor = UIColor(red: 0.35, green: 0.25, blue: 0.55, alpha: 1)
        fl.textAlignment = .center; fl.numberOfLines = 2; fl.frame = front.bounds
        front.addSubview(fl); card.addSubview(front); overlay.addSubview(card)
        let label = makeDemoLabel("UIView.transition\n.transitionFlipFromRight")
        overlay.addSubview(label)
        label.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY + 120)
        var showing = true
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { timer in
            count += 1; if count > 3 { timer.invalidate(); return }
            let toView = UIView(frame: card.bounds)
            toView.backgroundColor = showing
                ? UIColor(red: 0.98, green: 0.85, blue: 0.92, alpha: 1)
                : UIColor(red: 0.80, green: 0.70, blue: 0.98, alpha: 1)
            let lbl = UILabel()
            lbl.text = showing ? "BACK\n🌸" : "FRONT\n🎌"
            lbl.font = .systemFont(ofSize: 22, weight: .bold)
            lbl.textColor = UIColor(red: 0.35, green: 0.25, blue: 0.55, alpha: 1)
            lbl.textAlignment = .center; lbl.numberOfLines = 2; lbl.frame = toView.bounds
            toView.addSubview(lbl); showing.toggle()
            UIView.transition(with: card, duration: 0.6,
                              options: [.transitionFlipFromRight, .showHideTransitionViews]) {
                card.subviews.forEach { $0.removeFromSuperview() }
                card.addSubview(toView)
            }
        }
        dismissOverlayAfter(4.5, overlay: overlay)
    }

    private func presentParticleDemo() {
        let overlay = makeOverlay(); view.addSubview(overlay)
        let label = makeDemoLabel("CAEmitterLayer\nParticle burst")
        label.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY + 80)
        overlay.addSubview(label)
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY - 40)
        emitter.emitterShape = .circle; emitter.emitterSize = CGSize(width: 10, height: 10)
        let colors: [UIColor] = [
            UIColor(red: 0.60, green: 0.45, blue: 0.90, alpha: 1),
            UIColor(red: 0.91, green: 0.60, blue: 0.75, alpha: 1),
            UIColor(red: 0.45, green: 0.75, blue: 0.88, alpha: 1),
            UIColor(red: 0.95, green: 0.78, blue: 0.40, alpha: 1),
            UIColor(red: 0.55, green: 0.88, blue: 0.68, alpha: 1),
        ]
        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 12; cell.lifetime = 2.5; cell.velocity = 180
            cell.velocityRange = 80; cell.emissionRange = .pi * 2
            cell.scale = 0.3; cell.scaleRange = 0.2; cell.scaleSpeed = -0.08
            cell.spin = 3; cell.spinRange = 6; cell.alphaSpeed = -0.35
            cell.color = color.cgColor
            cell.contents = makeConfettiImage().cgImage
            return cell
        }
        overlay.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { emitter.birthRate = 0 }
        dismissOverlayAfter(3.5, overlay: overlay)
    }

    // MARK: - Helpers

    private func makeOverlay() -> UIView {
        let v = UIView(frame: view.bounds)
        v.backgroundColor = ThemeManager.shared.current.background.withAlphaComponent(0.94)
        v.alpha = 0
        let tap = UITapGestureRecognizer(target: self, action: #selector(overlayTapped(_:)))
        v.addGestureRecognizer(tap)
        UIView.animate(withDuration: 0.2) { v.alpha = 1 }
        return v
    }

    @objc private func overlayTapped(_ gr: UITapGestureRecognizer) {
        guard let v = gr.view else { return }
        v.layer.removeAllAnimations(); v.subviews.forEach { $0.layer.removeAllAnimations() }
        UIView.animate(withDuration: 0.2, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
    }

    private func dismissOverlayAfter(_ delay: TimeInterval, overlay: UIView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard overlay.superview != nil else { return }
            overlay.layer.removeAllAnimations()
            overlay.subviews.forEach { $0.layer.removeAllAnimations() }
            UIView.animate(withDuration: 0.3, animations: { overlay.alpha = 0 }) { _ in
                overlay.removeFromSuperview()
            }
        }
    }

    private func makeBox(color: UIColor, size: CGFloat) -> UIView {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        v.backgroundColor    = color
        v.layer.cornerRadius = 18
        v.layer.shadowColor  = color.cgColor
        v.layer.shadowRadius = 14; v.layer.shadowOpacity = 0.5; v.layer.shadowOffset = .zero
        return v
    }

    private func makeDemoLabel(_ text: String) -> UILabel {
        let theme = ThemeManager.shared.current
        let l = UILabel()
        l.text = text
        l.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        l.textColor = theme.bodyText
        l.textAlignment = .center; l.numberOfLines = 0
        l.backgroundColor = theme.cardBackground
        l.layer.cornerRadius = 10; l.clipsToBounds = true
        l.sizeToFit(); l.bounds = l.bounds.insetBy(dx: -14, dy: -10)
        return l
    }

    private func makeConfettiImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 6)).image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 10, height: 6))
        }
    }
}

extension AnimationDemoViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int { demos.count }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: DemoCell.id, for: ip) as! DemoCell
        cell.configure(with: demos[ip.row]); return cell
    }

    func tableView(_ tv: UITableView, heightForRowAt ip: IndexPath) -> CGFloat { 72 }

    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        runDemo(index: ip.row, sourceView: tv.cellForRow(at: ip) ?? tv)
    }

    func tableView(_ tv: UITableView, titleForHeaderInSection s: Int) -> String? {
        "Tap a demo to run it — tap the overlay to dismiss"
    }
}

final class DemoCell: UITableViewCell {
    static let id = "DemoCell"

    private let colorBar   = UIView()
    private let iconLabel  = UILabel()
    private let titleLabel = UILabel()
    private let subLabel   = UILabel()
    private let chevron    = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default

        colorBar.layer.cornerRadius = 3
        iconLabel.font = .systemFont(ofSize: 26)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        subLabel.font = .systemFont(ofSize: 11)

        [colorBar, iconLabel, titleLabel, subLabel, chevron].forEach {
            ($0 as UIView).translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0 as UIView)
        }
        NSLayoutConstraint.activate([
            colorBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            colorBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            colorBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            colorBar.widthAnchor.constraint(equalToConstant: 4),

            iconLabel.leadingAnchor.constraint(equalTo: colorBar.trailingAnchor, constant: 14),
            iconLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 34),

            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),

            subLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private func applyTheme() {
        let theme = ThemeManager.shared.current
        backgroundColor      = theme.cardBackground
        titleLabel.textColor = theme.bodyText
        subLabel.textColor   = theme.secondaryText
        chevron.tintColor    = theme.accentPrimary.withAlphaComponent(0.4)
        let sel = UIView(); sel.backgroundColor = theme.accentPrimary.withAlphaComponent(0.08)
        selectedBackgroundView = sel
    }

    func configure(with demo: AnimationDemo) {
        applyTheme()
        iconLabel.text = demo.icon; titleLabel.text = demo.title; subLabel.text = demo.subtitle
        colorBar.backgroundColor = demo.color
    }
}

struct AnimationDemo {
    let title: String; let subtitle: String; let icon: String; let color: UIColor
}
