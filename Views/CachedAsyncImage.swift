//
//  CachedAsyncImage.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct CachedAsyncImage: View {
    let url: String
    let size: CGFloat
    let fallback: AnyView
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                ProgressView()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallback
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _, newURL in
            if newURL != url {
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        guard let imageURL = URL(string: url) else {
            print("❌ Invalid image URL: \(url)")
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getImage(for: url) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                guard let data = data,
                      let downloadedImage = UIImage(data: data),
                      error == nil else {
                    print("❌ Failed to load image from URL: \(url), error: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Cache the image
                ImageCacheManager.shared.setImage(downloadedImage, for: url)
                
                // Update the UI
                self.image = downloadedImage
                print("✅ Successfully loaded and cached image: \(url)")
            }
        }.resume()
    }
}

#Preview {
    VStack(spacing: 20) {
        CachedAsyncImage(
            url: "https://example.com/profile.jpg",
            size: 50,
            fallback: AnyView(
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            )
        )
        
        CachedAsyncImage(
            url: "invalid-url",
            size: 30,
            fallback: AnyView(
                Image(systemName: "person.circle")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            )
        )
    }
    .padding()
}
