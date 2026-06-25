//
//  AdSampleSources.swift
//  AdSDK
//
//  Convenience access to the bundled sample VMAP/VAST and a set of dummy HLS
//  content / ad streams, so the host app can demo the full ad flow with zero
//  network setup. Resources load via `Bundle.module` (declared in Package.swift).
//

import Foundation

public enum AdSampleSources {

    // MARK: - Bundled XML

    /// The bundled mid-roll VMAP as a raw string.
    public static var sampleVMAPString: String? {
        loadResource(named: "SampleVMAP", ext: "xml")
    }

    /// The bundled standalone VAST as a raw string.
    public static var sampleVASTString: String? {
        loadResource(named: "SampleVAST", ext: "xml")
    }

    /// The bundled VMAP as a parsed model.
    public static func sampleVMAP() -> VMAP? {
        guard let string = sampleVMAPString else { return nil }
        return try? VMAPParser.parse(string: string)
    }

    /// The bundled VAST as a parsed model.
    public static func sampleVAST() -> VAST? {
        guard let string = sampleVASTString else { return nil }
        return try? VASTParser.parse(string: string)
    }

    /// A ready-to-use `VMAPSource` pointing at the bundled VMAP.
    public static var sampleVMAPSource: VMAPSource {
        if let string = sampleVMAPString { return .xml(string) }
        return .vmap(VMAP())
    }

    // MARK: - Dummy streams

    /// Long-form content for the main video: "Big Buck Bunny" (~10 min HLS, Mux test
    /// stream — reliably reachable). A real film makes the demo far easier to follow
    /// than a test-pattern clock — seeking, cue markers, and ad insertion are all
    /// obvious against actual footage. It is a *different* film from the short ad
    /// creatives below, so a mid-roll break is never mistaken for the main content.
    public static let dummyContentURL = URL(string:
        "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!

    /// Ad creatives — deliberately *different* films from the content so an inserted
    /// break is unmistakable. These are long-form streams, but the runtime caps each
    /// ad to its VAST-declared duration (~15s), so only a short slice plays. We use
    /// reliably-hosted public test streams (the old Google `gtv-videos-bucket` MP4s
    /// were taken private and now 403, which silently broke ad playback).
    public static let dummyAdURLs: [URL] = [
        URL(string: "https://test-streams.mux.dev/tos_ismc/main.m3u8")!,                                  // Tears of Steel
        URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8")!, // Apple BipBop
    ]

    // MARK: - Private

    private static func loadResource(named name: String, ext: String) -> String? {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
