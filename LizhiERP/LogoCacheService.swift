import SwiftUI
import Foundation

/// A lightweight service to cache downloaded logos to the local filesystem.
/// This ensures logos persist across app launches and are not re-fetched unnecessarily.
final class LogoCacheService {
    static let shared = LogoCacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("LogoCache")
        
        // Ensure cache directory exists
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Generates a filename hash from the URL
    private func cacheFileURL(for url: URL) -> URL {
        let filename = url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? "unknown"
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    /// Returns a cached UIImage if available on disk
    func getCachedImage(for url: URL) -> UIImage? {
        let fileURL = cacheFileURL(for: url)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            return image
        }
        return nil
    }
    
    /// Downloads and caches the image from the given URL
    func downloadAndCache(url: URL) async -> UIImage? {
        let fileURL = cacheFileURL(for: url)
        
        // 1. Check disk first (redundant if caller checked, but good for safety)
        if let cached = getCachedImage(for: url) {
            return cached
        }
        
        // 2. Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            
            // 3. Save to disk
            try? data.write(to: fileURL)
            return image
        } catch {
            print("LogoCacheService: Failed to download \(url): \(error)")
            return nil
        }
    }
}

/// A wrapper view that loads from cache or downloads
struct CachedLogoView<Placeholder: View, Content: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder
    let content: (Image) -> Content
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let uiImage = image {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // Fast path: Check cache synchronously
        if let cached = LogoCacheService.shared.getCachedImage(for: url) {
            self.image = cached
            return
        }
        
        // Slow path: Download
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            let downloaded = await LogoCacheService.shared.downloadAndCache(url: url)
            await MainActor.run {
                self.image = downloaded
                self.isLoading = false
            }
        }
    }
}
