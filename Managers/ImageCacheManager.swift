//
//  ImageCacheManager.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import Foundation
import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var cachedKeys = Set<String>()
    
    private init() {
        // Set cache limits
        cache.countLimit = 100 // Maximum 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB total cache size
        
        // Create cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    func getImage(for url: String) -> UIImage? {
        let key = NSString(string: url)
        return cache.object(forKey: key)
    }
    
    func setImage(_ image: UIImage, for url: String) {
        let key = NSString(string: url)
        cache.setObject(image, forKey: key)
        cachedKeys.insert(url)
        
        // Also save to disk for persistence
        saveImageToDisk(image, for: url)
    }
    
    func clearCacheForOrganization(_ organizationId: String) {
        // Clear from memory cache
        let keysToRemove = cachedKeys.filter { key in
            key.contains(organizationId)
        }
        
        for key in keysToRemove {
            let nsKey = NSString(string: key)
            cache.removeObject(forKey: nsKey)
            cachedKeys.remove(key)
        }
        
        // Clear from disk cache
        clearDiskCacheForOrganization(organizationId)
        
        print("🗑️ Cleared image cache for organization: \(organizationId)")
    }
    
    func preloadImages(for urls: [String]) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            for url in urls {
                if self?.getImage(for: url) == nil {
                    self?.loadImageFromURL(url)
                }
            }
        }
    }
    
    func clearAllCache() {
        cache.removeAllObjects()
        cachedKeys.removeAll()
        clearAllDiskCache()
        print("🗑️ Cleared all image cache")
    }
    
    // MARK: - Private Methods
    
    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let image = UIImage(data: data),
                  error == nil else {
                print("❌ Failed to load image from URL: \(urlString)")
                return
            }
            
            DispatchQueue.main.async {
                self?.setImage(image, for: urlString)
                print("✅ Loaded and cached image: \(urlString)")
            }
        }.resume()
    }
    
    private func saveImageToDisk(_ image: UIImage, for url: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileName = url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "unknown"
        let fileURL = cacheDirectory.appendingPathComponent("\(fileName).jpg")
        
        try? data.write(to: fileURL)
    }
    
    private func clearDiskCacheForOrganization(_ organizationId: String) {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.contains(organizationId) {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("❌ Error clearing disk cache for organization: \(error)")
        }
    }
    
    private func clearAllDiskCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("❌ Error clearing all disk cache: \(error)")
        }
    }
}

// MARK: - Extensions

extension ImageCacheManager {
    func getCacheSize() -> String {
        let memorySize = cache.totalCostLimit
        let memorySizeMB = memorySize / (1024 * 1024)
        return "\(memorySizeMB)MB"
    }
    
    func getCachedImageCount() -> Int {
        return cache.countLimit
    }
}
