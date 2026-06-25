//  ImageLoader.swift
//  ImageLoaderKit
//
//  A tiny async image loader with an in-memory cache and request de-duplication.
//  Posters/characters are loaded straight from URLs (no third-party deps); the
//  cache avoids re-downloading the same poster as cells are reused.
//

import UIKit

/// Loads and caches remote images. Use ``ImageLoader/shared`` everywhere so the
/// cache (and in-flight de-duplication) is process-wide.
public actor ImageLoader {

    public static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 200
    }

    /// Returns the image for `url`, hitting the in-memory cache first and
    /// coalescing duplicate concurrent requests for the same URL.
    public func image(from url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            guard
                let (data, _) = try? await URLSession.shared.data(from: url),
                let image = UIImage(data: data)
            else { return nil }
            // Force-decode the image here (off the main thread). `UIImage(data:)`
            // only decodes lazily at *render* time on the main thread, so without
            // this, assigning many large posters to image views during scrolling
            // decodes them all on the main thread — causing hitches that look like
            // the screen freezing. `preparingForDisplay()` returns a bitmap that's
            // ready to draw, so the main thread just blits it.
            return image.preparingForDisplay() ?? image
        }
        inFlight[url] = task

        let image = await task.value
        inFlight[url] = nil
        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }
        return image
    }
}
