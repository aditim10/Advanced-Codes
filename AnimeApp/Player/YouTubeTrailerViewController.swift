//
//  YouTubeTrailerViewController.swift
//  AnimeApp
//
//  A client-side host controller for playing real YouTube trailers. It lives in
//  the app (not PlayerSDK) because it has nothing to do with the AVPlayer engine:
//  YouTube serves protected, ad-supported streams that AVPlayer can't open, so we
//  embed YouTube's official IFrame Player API in a `WKWebView`. Keeping it here
//  also means it carries no dependency on PlayerSDK.
//
//  Why the IFrame API + a fake-but-real-looking `baseURL` (instead of just
//  loading the bare `/embed/<id>` page): YouTube now requires embeds to carry a
//  valid HTTP `Referer`/origin, which a WKWebView doesn't supply on its own. The
//  embed must live in an iframe whose PARENT has a distinct, real-looking https
//  origin. Empirically:
//    • top-level load of /embed       → error 153 (no Referer)
//    • baseURL = https://youtube.com  → error 152-4 (same-origin parent rejected)
//    • baseURL = nil (about:blank)    → restricted permissions, also fails
//    • baseURL = https://animeapp.local/ (fake host) → works
//  We also spoof a Safari User-Agent because YouTube's embed fingerprints
//  WKWebView's default UA and rejects it with 152-4 as well.
//
//  Why this also solves rotation: tapping the player's fullscreen button hands
//  off to iOS's *native* fullscreen video presentation, which rotates with the
//  device automatically — the OTT behaviour you'd expect. The popup itself also
//  supports landscape so it rotates inline.
//

import UIKit
import WebKit

// MARK: - State

/// Lifecycle of the YouTube trailer player. Independent of PlayerSDK so this
/// client component carries no SDK dependency.
public enum YouTubeTrailerState: Equatable {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case ended
    case failed(String)
}

// MARK: - Delegate

/// Callbacks for the YouTube trailer player. All methods are optional.
public protocol YouTubeTrailerDelegate: AnyObject {
    func youTubeTrailerDidBecomeReady(_ controller: YouTubeTrailerViewController)
    func youTubeTrailer(_ controller: YouTubeTrailerViewController, didChangeState state: YouTubeTrailerState)
    func youTubeTrailer(_ controller: YouTubeTrailerViewController, didFailWithError error: Error)
}

public extension YouTubeTrailerDelegate {
    func youTubeTrailerDidBecomeReady(_ controller: YouTubeTrailerViewController) {}
    func youTubeTrailer(_ controller: YouTubeTrailerViewController, didChangeState state: YouTubeTrailerState) {}
    func youTubeTrailer(_ controller: YouTubeTrailerViewController, didFailWithError error: Error) {}
}

// MARK: - View controller

public final class YouTubeTrailerViewController: UIViewController {

    private let videoID: String
    private let titleText: String?
    public weak var delegate: YouTubeTrailerDelegate?

    private var webView: WKWebView!
    private let closeButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .large)

    /// - Parameters:
    ///   - videoID: the YouTube video id (e.g. `"NlJZ-YgAt-c"`).
    ///   - title: optional accessibility/label text.
    public init(videoID: String, title: String? = nil) {
        self.videoID = videoID
        self.titleText = title
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Let the trailer rotate freely (OTT-style); the rest of the app stays
    // portrait via the app's orientation gate.
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }
    public override var prefersStatusBarHidden: Bool { true }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        setupChrome()
        loadVideo()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true                 // play inside the page…
        config.mediaTypesRequiringUserActionForPlayback = []    // …and allow autoplay

        // JS → native bridge for the IFrame player's onReady/onStateChange/onError.
        // A weak proxy avoids the userContentController → handler → webView retain cycle.
        let controller = WKUserContentController()
        controller.add(WeakScriptMessageProxy(self), name: Self.messageName)
        config.userContentController = controller

        webView = WKWebView(frame: .zero, configuration: config)
        // YouTube's embed player fingerprints WKWebView's default User-Agent
        // (it lacks the Version/… Safari/… tokens) and rejects it with error
        // 152-4. Presenting a standard mobile Safari UA avoids that.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupChrome() {
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        closeButton.layer.cornerRadius = 18
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func loadVideo() {
        delegate?.youTubeTrailer(self, didChangeState: .loading)
        // The embed must live in an iframe whose PARENT has a distinct, real-looking
        // https origin (not youtube.com, not about:blank). That gives the iframe a
        // genuine cross-origin parent and a valid Referer — the combination the
        // IFrame player accepts. Using youtube.com here yields error 152-4; a
        // top-level load yields 153 (see file header).
        webView.loadHTMLString(Self.embedHTML(videoID: videoID),
                               baseURL: URL(string: "https://\(Self.parentHost)/"))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop playback/audio and drop the message handler when leaving.
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageName)
        webView.loadHTMLString("", baseURL: nil)
        // Returning from a possibly-landscape trailer to a portrait-only app: nudge
        // the system to re-evaluate orientations so it rotates back to portrait.
        if #available(iOS 16.0, *) {
            presentingViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    // MARK: IFrame player HTML

    private static let messageName = "ytbridge"

    /// A fake-but-real-looking https host used as the WebView's `baseURL` and the
    /// iframe `origin`. It must NOT be youtube.com (same-origin parent → 152-4)
    /// and must be a real-looking https host (not about:blank).
    private static let parentHost = "animeapp.local"

    /// A minimal page that loads the YouTube IFrame Player API and forwards its
    /// events back to native via `window.webkit.messageHandlers.ytbridge`.
    private static func embedHTML(videoID: String) -> String {
        // Build the embed URL ourselves so we can attach `YT.Player` to an
        // *existing* iframe that carries `referrerpolicy`. Letting the IFrame API
        // generate its own iframe drops that attribute, and recent YouTube
        // security checks then reject the request with error 152/153.
        //
        // Use `youtube-nocookie.com` to mirror MyAnimeList's own embed exactly
        // (their iframe src is `youtube-nocookie.com/embed/<id>?enablejsapi=1…`);
        // the privacy domain is also typically more permissive for embedding.
        let src = "https://www.youtube-nocookie.com/embed/\(videoID)"
            + "?enablejsapi=1&playsinline=1&autoplay=1&controls=1"
            + "&rel=0&modestbranding=1&fs=1&origin=https://\(parentHost)"
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <!-- Required by YouTube's tightened embed checks (avoids error 152/153). -->
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <style>
            * { margin: 0; padding: 0; }
            html, body { background: #000; height: 100%; width: 100%; overflow: hidden; }
            #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
          </style>
        </head>
        <body>
          <iframe id="player"
                  src="\(src)"
                  referrerpolicy="strict-origin-when-cross-origin"
                  allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture; web-share"
                  allowfullscreen></iframe>
          <script src="https://www.youtube.com/iframe_api"></script>
          <script>
            function post(msg) {
              try { window.webkit.messageHandlers.\(messageName).postMessage(msg); } catch (e) {}
            }
            var player;
            function onYouTubeIframeAPIReady() {
              // Attach to the existing iframe so its referrerpolicy is preserved.
              player = new YT.Player('player', {
                events: {
                  onReady: function (e) { post('ready'); e.target.playVideo(); },
                  onStateChange: function (e) { post('state:' + e.data); },
                  onError: function (e) { post('error:' + e.data); }
                }
              });
            }
          </script>
        </body>
        </html>
        """
    }

    // Translate IFrame error codes into a human-readable reason.
    fileprivate func handleBridgeMessage(_ body: String) {
        if body == "ready" {
            spinner.stopAnimating()
            delegate?.youTubeTrailerDidBecomeReady(self)
            delegate?.youTubeTrailer(self, didChangeState: .readyToPlay)

            return
        }
        if body.hasPrefix("state:"), let code = Int(body.dropFirst("state:".count)) {
            // YT codes: -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued.
            switch code {
            case 0:  delegate?.youTubeTrailer(self, didChangeState: .ended)
            case 1:  spinner.stopAnimating(); delegate?.youTubeTrailer(self, didChangeState: .playing)
            case 2:  delegate?.youTubeTrailer(self, didChangeState: .paused)
            case 3:  delegate?.youTubeTrailer(self, didChangeState: .loading)
            default: break
            }
            return
        }
        if body.hasPrefix("error:"), let code = Int(body.dropFirst("error:".count)) {
            let reason: String
            switch code {
            case 2: reason = "The video id is invalid."
            case 5: reason = "The video can't be played in the HTML5 player."
            case 100: reason = "The trailer was removed or is private."
            case 101, 150: reason = "The owner doesn't allow this trailer to be embedded."
            case 152, 153: reason = "YouTube rejected the embed request (missing referrer)."
            default: reason = "YouTube player error (\(code))."
            }
            spinner.stopAnimating()
            let error = NSError(domain: "AnimeApp.YouTube", code: code,
                                userInfo: [NSLocalizedDescriptionKey: reason])
            delegate?.youTubeTrailer(self, didChangeState: .failed(reason))
            delegate?.youTubeTrailer(self, didFailWithError: error)
        }
    }
}

// MARK: - WKScriptMessageHandler (JS bridge)

extension YouTubeTrailerViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard message.name == Self.messageName, let body = message.body as? String else { return }
        handleBridgeMessage(body)
    }
}

/// Forwards script messages to a weakly-held handler so the
/// `WKUserContentController` doesn't retain (and leak) the view controller.
private final class WeakScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - WKNavigationDelegate (load lifecycle → delegate callbacks)

extension YouTubeTrailerViewController: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // The HTML loaded; actual readiness/play/error now arrives via the JS
        // bridge (handleBridgeMessage), so keep the spinner until the player is ready.
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reportFailure(error)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        reportFailure(error)
    }

    private func reportFailure(_ error: Error) {
        spinner.stopAnimating()
        delegate?.youTubeTrailer(self, didChangeState: .failed(error.localizedDescription))
        delegate?.youTubeTrailer(self, didFailWithError: error)
    }
}
