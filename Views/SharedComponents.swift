import SwiftUI
import Combine

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isClickable: Bool
    let action: (() -> Void)?
    
    init(title: String, value: String, icon: String, color: Color, isClickable: Bool = false, action: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.isClickable = isClickable
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            if isClickable, let action = action {
                action()
            }
        }
        .scaleEffect(isClickable ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isClickable)
    }
}

// MARK: - Contact Row
struct ContactRow: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    
    init(icon: String, title: String, value: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    init(label: String, value: String, format: Format = .none) {
        self.label = label
        self.value = value
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    enum Format {
        case none
        case dateTime
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let isLink: Bool
    
    init(icon: String, title: String, value: String, isLink: Bool = false) {
        self.icon = icon
        self.title = title
        self.value = value
        self.isLink = isLink
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isLink ? .blue : .primary)
            }
            
            Spacer()
            
            if isLink {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Image Cache Manager
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    private var cache = NSCache<NSString, UIImage>()
    private var cacheKeys = Set<String>() // Track keys manually since NSCache doesn't expose them
    
    private init() {
        cache.countLimit = 100 // Maximum number of images to cache
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
    }
    
    func getImage(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    func setImage(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
        cacheKeys.insert(url) // Track the key
    }
    
    func clearCache() {
        cache.removeAllObjects()
        cacheKeys.removeAll() // Clear tracked keys
    }
    
    func preloadImage(for urlString: String) {
        // Preload image in background
        Task {
            guard let url = URL(string: urlString) else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.setImage(image, for: urlString)
                        print("✅ ImageCacheManager: Preloaded image for: \(urlString)")
                    }
                }
            } catch {
                print("❌ ImageCacheManager: Failed to preload image: \(error)")
            }
        }
    }
    
    // MARK: - Preload Multiple Images
    func preloadImages(for urlStrings: [String]) {
        for urlString in urlStrings {
            preloadImage(for: urlString)
        }
    }
    
    // MARK: - Check Cache Status
    func getCacheStatus() -> (count: Int, totalCost: Int) {
        return (cacheKeys.count, cache.totalCostLimit)
    }
    
    // MARK: - Clear Expired Cache
    func clearExpiredCache() {
        // For now, just clear all cache
        // In a production app, you might want to implement LRU or time-based expiration
        clearCache()
    }
    
    // MARK: - Clear Cache for Specific URL
    func clearCache(for urlString: String) {
        cache.removeObject(forKey: urlString as NSString)
        cacheKeys.remove(urlString) // Remove from tracked keys
        print("🗑️ ImageCacheManager: Cleared cache for: \(urlString)")
    }
    
    // MARK: - Clear Cache for Organization
    func clearCacheForOrganization(_ organizationId: String) {
        // Clear any cached images that might be related to this organization
        // This is useful when organization logos are updated
        let keysToRemove = cacheKeys.filter { key in
            return key.contains(organizationId)
        }
        
        for key in keysToRemove {
            cache.removeObject(forKey: key as NSString)
            cacheKeys.remove(key)
        }
        
        if !keysToRemove.isEmpty {
            print("🗑️ ImageCacheManager: Cleared \(keysToRemove.count) cached images for organization: \(organizationId)")
        }
    }
}

// MARK: - Cached Image Loader
class CachedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var hasError = false
    
    private var cancellable: AnyCancellable?
    private var retryCount = 0
    private let maxRetries = 1
    
    func loadImage(from urlString: String) {
        print("🖼️ CachedImageLoader: loadImage called with URL: \(urlString)")
        
        // Fix Firebase Storage URL format
        let encodedURLString: String
        if urlString.contains("firebasestorage.googleapis.com") && urlString.contains(".appspot.com") {
            // Fix the bucket name by removing .appspot.com
            let fixedURL = urlString.replacingOccurrences(of: ".appspot.com", with: "")
            encodedURLString = fixedURL
        } else {
            encodedURLString = urlString
        }
        
        // Validate URL before attempting to load
        guard let url = URL(string: encodedURLString) else {
            hasError = true
            return
        }
        
        // Check cache first
        if let cachedImage = ImageCacheManager.shared.getImage(for: urlString) {
            print("✅ CachedImageLoader: Found cached image")
            self.image = cachedImage
            self.hasError = false
            return
        }
        
        isLoading = true
        hasError = false
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { data, response -> UIImage? in
                return UIImage(data: data)
            }
            .catch { error -> AnyPublisher<UIImage?, Never> in
                print("❌ CachedImageLoader: Network error: \(error)")
                return Just(nil).eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (loadedImage: UIImage?) in
                self?.isLoading = false
                if let loadedImage = loadedImage {
                    self?.image = loadedImage
                    self?.hasError = false
                    self?.retryCount = 0 // Reset retry count on success
                    // Cache the loaded image
                    ImageCacheManager.shared.setImage(loadedImage, for: urlString)
                } else {
                    self?.handleLoadError(urlString: urlString)
                }
            }
    }
    
    private func handleLoadError(urlString: String) {
        if retryCount < maxRetries {
            retryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadImage(from: urlString)
            }
        } else {
            // Fail silently and show fallback UI
            self.hasError = true
            self.retryCount = 0 // Reset for next attempt
        }
    }
    
    // MARK: - Helper Methods
    
    func reset() {
        image = nil
        isLoading = false
        hasError = false
        retryCount = 0
        cancellable?.cancel()
    }
}

// MARK: - Cached Async Image
struct CachedAsyncImage: View {
    let url: String
    let size: CGFloat
    let fallback: AnyView
    
    @StateObject private var imageLoader = CachedImageLoader()
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                // Show cached/loaded image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .transition(.opacity.combined(with: .scale))
                    .onAppear {
                        print("✅ CachedAsyncImage: Showing loaded image")
                    }
            } else if imageLoader.isLoading {
                // Show loading state
                fallback
                    .onAppear {
                        print("🔄 CachedAsyncImage: Showing loading state")
                    }
            } else if imageLoader.hasError {
                // Show fallback on error
                fallback
                    .onAppear {
                        print("❌ CachedAsyncImage: Showing error fallback")
                    }
            } else {
                // Initial state - start loading
                fallback
                    .onAppear {
                        print("🖼️ CachedAsyncImage: Starting to load image from: \(url)")
                        print("   - Image loader state: isLoading=\(imageLoader.isLoading), hasError=\(imageLoader.hasError), image=\(imageLoader.image != nil)")
                        imageLoader.loadImage(from: url)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: imageLoader.image != nil)
    }
}

// MARK: - Organization Logo View
struct OrganizationLogoView: View {
    let organization: Organization
    let size: CGFloat
    let showBorder: Bool
    @StateObject private var imageLoader = CachedImageLoader()
    
    init(organization: Organization, size: CGFloat = 50, showBorder: Bool = true) {
        self.organization = organization
        self.size = size
        self.showBorder = showBorder
    }
    
    var body: some View {
        Group {
            // Check if we have a valid logo URL first
            if let logoURL = organization.logoURL, 
               !logoURL.isEmpty, 
               isValidURL(logoURL), 
               !isPlaceholderURL(logoURL) {
                // Display uploaded logo with caching
                CachedAsyncImage(
                    url: logoURL,
                    size: size,
                    fallback: AnyView(defaultIconView)
                )
                .onAppear {
                    print("🖼️ OrganizationLogoView: Displaying uploaded logo: \(logoURL)")
                    print("   - Organization ID: \(organization.id)")
                    print("   - Organization name: \(organization.name)")
                }
                .onChange(of: organization.logoURL) { _, newLogoURL in
                    if let newLogoURL = newLogoURL, 
                       !newLogoURL.isEmpty, 
                       isValidURL(newLogoURL), 
                       !isPlaceholderURL(newLogoURL) {
                        print("✅ OrganizationLogoView: Valid new logo URL, reloading image: \(newLogoURL)")
                        imageLoader.loadImage(from: newLogoURL)
                    }
                }
            } else {
                // Fallback to default icon based on organization type
                defaultIconView
                    .onAppear {
                        let logoURL = organization.logoURL
                        if logoURL == nil || logoURL?.isEmpty == true {
                            print("🖼️ OrganizationLogoView: No logo URL, using default icon for type: \(organization.type)")
                        } else if let logoURL = logoURL {
                            if isPlaceholderURL(logoURL) {
                                print("🖼️ OrganizationLogoView: Placeholder logo URL detected, using default icon for type: \(organization.type)")
                            } else {
                                print("🖼️ OrganizationLogoView: Invalid logo URL, using default icon for type: \(organization.type)")
                            }
                        }
                        print("   - Organization ID: \(organization.id)")
                        print("   - Organization name: \(organization.name)")
                    }
            }
        }
        .overlay(
            Group {
                if showBorder {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .shadow(radius: 2)
                }
            }
        )
    }
    
    private var defaultIconView: some View {
        Image(systemName: OrganizationAvatarUtility.getIcon(for: organization.type))
            .font(.system(size: size * 0.6, weight: .medium))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(OrganizationAvatarUtility.getColor(for: organization.type))
            .clipShape(Circle())
    }
    
    // MARK: - Helper Methods
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { 
            print("   - URL validation: Failed to create URL from string")
            return false 
        }
        
        // Check if scheme is present and valid
        guard let scheme = url.scheme, !scheme.isEmpty else {
            print("   - URL validation: No scheme present")
            return false
        }
        
        // Only allow HTTP and HTTPS schemes
        guard scheme == "http" || scheme == "https" else {
            print("   - URL validation: Invalid scheme: \(scheme)")
            return false
        }
        
        // Check if host is present and not empty
        guard let host = url.host, !host.isEmpty else {
            print("   - URL validation: No host present")
            return false
        }
        
        // Basic validation passed - allow the URL to load
        print("   - URL validation: URL appears valid")
        return true
    }
    
    private func isPlaceholderURL(_ urlString: String) -> Bool {
        // Check if URL contains placeholder domains
        let placeholderDomains = [
            "example.com",
            "placeholder.com", 
            "via.placeholder.com",
            "dummy.com",
            "test.com"
        ]
        
        for domain in placeholderDomains {
            if urlString.contains(domain) {
                print("   - 🚫 Placeholder domain detected: \(domain)")
                return true
            }
        }
        
        print("   - ✅ URL is not a placeholder")
        return false
    }
}

// MARK: - Organization Avatar Utilities
struct OrganizationAvatarUtility {
    
    static func getIcon(for organizationType: String) -> String {
        switch organizationType.lowercased() {
        case "church": return "building.2.fill"
        case "pto": return "graduationcap.fill"
        case "school": return "building.columns.fill"
        case "business": return "building.2.fill"
        case "government": return "building.columns.fill"
        case "nonprofit": return "heart.fill"
        case "emergency": return "cross.fill"
        case "medical_practice", "medical": return "cross.case.fill"
        case "healthcare": return "heart.text.square.fill"
        case "hospital": return "building.2.crop.circle.fill"
        case "clinic": return "cross.circle.fill"
        case "pharmacy": return "pills.fill"
        case "dental": return "mouth.fill"
        case "veterinary": return "pawprint.fill"
        case "fire_department": return "flame.fill"
        case "police_department": return "shield.fill"
        case "library": return "books.vertical.fill"
        case "museum": return "building.columns.circle.fill"
        case "park": return "leaf.fill"
        case "restaurant": return "fork.knife"
        case "retail": return "bag.fill"
        case "bank": return "banknote.fill"
        case "insurance": return "umbrella.fill"
        case "real_estate": return "house.fill"
        case "law_firm": return "building.columns.circle.fill"
        case "consulting": return "person.2.fill"
        case "technology": return "laptopcomputer"
        case "manufacturing": return "gearshape.fill"
        case "construction": return "hammer.fill"
        case "transportation": return "car.fill"
        case "utilities": return "bolt.fill"
        case "entertainment": return "star.fill"
        case "sports": return "sportscourt.fill"
        case "fitness": return "dumbbell.fill"
        case "beauty": return "scissors"
        case "automotive": return "car.circle.fill"
        case "education": return "graduationcap.fill"
        case "religious": return "building.2.fill"
        case "community": return "person.3.fill"
        case "charity": return "heart.fill"
        case "environmental": return "leaf.circle.fill"
        case "arts": return "paintbrush.fill"
        case "media": return "tv.fill"
        case "finance": return "chart.line.uptrend.xyaxis"
        case "research": return "magnifyingglass"
        case "agriculture": return "leaf.arrow.circlepath"
        case "hospitality": return "bed.double.fill"
        case "logistics": return "shippingbox.fill"
        case "energy": return "bolt.circle.fill"
        case "telecommunications": return "antenna.radiowaves.left.and.right"
        case "pharmaceutical": return "pills.circle.fill"
        case "biotechnology": return "dna"
        case "aerospace": return "airplane"
        case "defense": return "shield.lefthalf.filled"
        case "mining": return "hammer.circle.fill"
        case "oil_gas": return "drop.fill"
        case "chemical": return "testtube.2"
        case "textiles": return "scissors.circle"
        case "food_beverage": return "cup.and.saucer.fill"
        case "tobacco": return "smoke.fill"
        case "gaming": return "gamecontroller.fill"
        case "cryptocurrency": return "bitcoinsign.circle.fill"
        case "blockchain": return "link.circle.fill"
        case "ai_ml": return "brain.head.profile"
        case "cybersecurity": return "lock.shield.fill"
        case "cloud_computing": return "cloud.fill"
        case "ecommerce": return "cart.fill"
        case "social_media": return "message.fill"
        case "streaming": return "play.tv.fill"
        case "gaming_industry": return "gamecontroller.fill"
        case "fashion": return "tshirt.fill"
        case "luxury": return "crown.fill"
        case "fast_food": return "takeoutbag.and.cup.and.straw.fill"
        case "coffee": return "cup.and.saucer.fill"
        case "bakery": return "birthday.cake.fill"
        case "butcher": return "scissors"
        case "fishmonger": return "fish.fill"
        case "greengrocer": return "carrot.fill"
        case "deli": return "fork.knife.circle"
        case "wine": return "wineglass.fill"
        case "brewery": return "drop.fill"
        case "distillery": return "drop.circle.fill"
        case "catering": return "fork.knife.circle.fill"
        case "food_truck": return "car.fill"
        case "popup": return "tent.fill"
        case "market": return "cart.circle.fill"
        case "farmers_market": return "leaf.circle.fill"
        case "organic": return "leaf.arrow.circlepath"
        case "vegan": return "leaf.fill"
        case "gluten_free": return "exclamationmark.triangle.fill"
        case "halal": return "checkmark.circle.fill"
        case "kosher": return "star.david.fill"
        case "halal_certified": return "checkmark.seal.fill"
        case "kosher_certified": return "star.seal.fill"
        case "organic_certified": return "leaf.seal.fill"
        case "fair_trade": return "hand.raised.fill"
        case "sustainable": return "leaf.arrow.circlepath"
        case "eco_friendly": return "leaf.circle.fill"
        case "carbon_neutral": return "leaf.arrow.circlepath"
        case "renewable_energy": return "bolt.circle.fill"
        case "solar": return "sun.max.fill"
        case "wind": return "wind"
        case "hydroelectric": return "drop.fill"
        case "geothermal": return "flame.fill"
        case "nuclear": return "atom"
        case "coal": return "circle.fill"
        case "natural_gas": return "flame.circle.fill"
        case "petroleum": return "drop.circle.fill"
        case "biodiesel": return "leaf.arrow.circlepath"
        case "ethanol": return "drop.fill"
        case "hydrogen": return "atom"
        case "fusion": return "atom"
        case "fission": return "atom"
        case "plasma": return "bolt.circle.fill"
        case "quantum": return "atom"
        case "nanotechnology": return "atom"
        case "robotics": return "gearshape.2.fill"
        case "automation": return "gearshape.2.fill"
        case "iot": return "antenna.radiowaves.left.and.right"
        case "5g": return "antenna.radiowaves.left.and.right"
        case "fiber_optics": return "antenna.radiowaves.left.and.right"
        case "satellite": return "antenna.radiowaves.left.and.right"
        case "drone": return "airplane"
        case "autonomous_vehicles": return "car.fill"
        case "electric_vehicles": return "bolt.circle.fill"
        case "hybrid_vehicles": return "leaf.circle.fill"
        case "hydrogen_vehicles": return "atom"
        case "fuel_cell": return "atom"
        case "battery": return "bolt.circle.fill"
        case "supercapacitor": return "bolt.circle.fill"
        case "wireless_charging": return "bolt.circle.fill"
        case "fast_charging": return "bolt.circle.fill"
        case "inductive_charging": return "bolt.circle.fill"
        case "solar_charging": return "sun.max.fill"
        case "kinetic_energy": return "bolt.circle.fill"
        case "thermal_energy": return "flame.fill"
        case "mechanical_energy": return "gearshape.fill"
        case "chemical_energy": return "testtube.2"
        case "nuclear_energy": return "atom"
        case "gravitational_energy": return "arrow.down.circle.fill"
        case "elastic_energy": return "arrow.up.circle.fill"
        case "sound_energy": return "speaker.wave.3.fill"
        case "light_energy": return "lightbulb.fill"
        case "electromagnetic_energy": return "antenna.radiowaves.left.and.right"
        case "atomic_energy": return "atom"
        case "molecular_energy": return "atom"
        case "cellular_energy": return "atom"
        case "biological_energy": return "leaf.fill"
        case "geological_energy": return "mountain.2.fill"
        case "oceanic_energy": return "drop.fill"
        case "atmospheric_energy": return "cloud.fill"
        case "cosmic_energy": return "star.fill"
        case "dark_energy": return "moon"
        case "antimatter": return "atom"
        case "dark_matter": return "moon"
        case "neutrinos": return "atom"
        case "gravitons": return "arrow.down.circle.fill"
        case "photons": return "lightbulb.fill"
        case "electrons": return "bolt.circle.fill"
        case "protons": return "plus.circle.fill"
        case "neutrons": return "circle.fill"
        case "quarks": return "atom"
        case "leptons": return "atom"
        case "bosons": return "atom"
        case "fermions": return "atom"
        case "hadrons": return "atom"
        case "mesons": return "atom"
        case "baryons": return "atom"
        case "gluons": return "atom"
        case "w_bosons": return "atom"
        case "z_bosons": return "atom"
        case "graviton": return "arrow.down.circle.fill"
        case "photon": return "lightbulb.fill"
        case "electron": return "bolt.circle.fill"
        case "proton": return "plus.circle.fill"
        case "neutron": return "circle.fill"
        case "quark": return "atom"
        case "lepton": return "atom"
        case "boson": return "atom"
        case "fermion": return "atom"
        case "hadron": return "atom"
        case "meson": return "atom"
        case "baryon": return "atom"
        case "gluon": return "atom"
        case "w_boson": return "atom"
        case "z_boson": return "atom"
        default: return "building.2.fill"
        }
    }
    
    static func getColor(for organizationType: String) -> Color {
        switch organizationType.lowercased() {
        case "church": return .purple
        case "pto": return .green
        case "school": return .blue
        case "business": return .orange
        case "government": return .red
        case "nonprofit": return .pink
        case "emergency": return .red
        case "medical_practice", "medical": return .teal
        case "healthcare": return .teal
        case "hospital": return .teal
        case "clinic": return .teal
        case "pharmacy": return .teal
        case "dental": return .teal
        case "veterinary": return .teal
        case "fire_department": return .red
        case "police_department": return .blue
        case "library": return .brown
        case "museum": return .purple
        case "park": return .green
        case "restaurant": return .orange
        case "retail": return .pink
        case "bank": return .green
        case "insurance": return .blue
        case "real_estate": return .orange
        case "law_firm": return .purple
        case "consulting": return .blue
        case "technology": return .blue
        case "manufacturing": return .gray
        case "construction": return .orange
        case "transportation": return .blue
        case "utilities": return .yellow
        case "entertainment": return .purple
        case "sports": return .green
        case "fitness": return .green
        case "beauty": return .pink
        case "automotive": return .blue
        case "education": return .blue
        case "religious": return .purple
        case "community": return .green
        case "charity": return .pink
        case "environmental": return .green
        case "arts": return .purple
        case "media": return .blue
        case "finance": return .green
        case "research": return .blue
        case "agriculture": return .green
        case "hospitality": return .orange
        case "logistics": return .blue
        case "energy": return .yellow
        case "telecommunications": return .blue
        case "pharmaceutical": return .teal
        case "biotechnology": return .purple
        case "aerospace": return .blue
        case "defense": return .red
        case "mining": return .gray
        case "oil_gas": return .black
        case "chemical": return .orange
        case "textiles": return .pink
        case "food_beverage": return .orange
        case "tobacco": return .brown
        case "gaming": return .purple
        case "cryptocurrency": return .orange
        case "blockchain": return .blue
        case "ai_ml": return .purple
        case "cybersecurity": return .red
        case "cloud_computing": return .blue
        case "ecommerce": return .green
        case "social_media": return .blue
        case "streaming": return .purple
        case "gaming_industry": return .purple
        case "fashion": return .pink
        case "luxury": return .yellow
        case "fast_food": return .orange
        case "coffee": return .brown
        case "bakery": return .orange
        case "butcher": return .red
        case "fishmonger": return .blue
        case "greengrocer": return .green
        case "deli": return .orange
        case "wine": return .purple
        case "brewery": return .blue
        case "distillery": return .brown
        case "catering": return .orange
        case "food_truck": return .blue
        case "popup": return .orange
        case "market": return .green
        case "farmers_market": return .green
        case "organic": return .green
        case "vegan": return .green
        case "gluten_free": return .orange
        case "halal": return .green
        case "kosher": return .blue
        case "halal_certified": return .green
        case "kosher_certified": return .blue
        case "organic_certified": return .green
        case "fair_trade": return .green
        case "sustainable": return .green
        case "eco_friendly": return .green
        case "carbon_neutral": return .green
        case "renewable_energy": return .green
        case "solar": return .yellow
        case "wind": return .blue
        case "hydroelectric": return .blue
        case "geothermal": return .orange
        case "nuclear": return .red
        case "coal": return .black
        case "natural_gas": return .orange
        case "petroleum": return .black
        case "biodiesel": return .green
        case "ethanol": return .green
        case "hydrogen": return .blue
        case "fusion": return .blue
        case "fission": return .red
        case "plasma": return .purple
        case "quantum": return .purple
        case "nanotechnology": return .purple
        case "robotics": return .blue
        case "automation": return .blue
        case "iot": return .blue
        case "5g": return .blue
        case "fiber_optics": return .blue
        case "satellite": return .blue
        case "drone": return .blue
        case "autonomous_vehicles": return .blue
        case "electric_vehicles": return .green
        case "hybrid_vehicles": return .green
        case "hydrogen_vehicles": return .blue
        case "fuel_cell": return .green
        case "battery": return .green
        case "supercapacitor": return .green
        case "wireless_charging": return .green
        case "fast_charging": return .green
        case "inductive_charging": return .green
        case "solar_charging": return .yellow
        case "kinetic_energy": return .green
        case "thermal_energy": return .orange
        case "mechanical_energy": return .blue
        case "chemical_energy": return .orange
        case "nuclear_energy": return .red
        case "gravitational_energy": return .purple
        case "elastic_energy": return .purple
        case "sound_energy": return .blue
        case "light_energy": return .yellow
        case "electromagnetic_energy": return .purple
        case "atomic_energy": return .red
        case "molecular_energy": return .blue
        case "cellular_energy": return .green
        case "biological_energy": return .green
        case "geological_energy": return .brown
        case "oceanic_energy": return .blue
        case "atmospheric_energy": return .blue
        case "cosmic_energy": return .purple
        case "dark_energy": return .black
        case "antimatter": return .purple
        case "dark_matter": return .black
        case "neutrinos": return .blue
        case "gravitons": return .purple
        case "photons": return .yellow
        case "electrons": return .blue
        case "protons": return .red
        case "neutrons": return .gray
        case "quarks": return .purple
        case "leptons": return .blue
        case "bosons": return .green
        case "fermions": return .orange
        case "hadrons": return .red
        case "mesons": return .purple
        case "baryons": return .blue
        case "gluon": return .red
        case "w_boson": return .orange
        case "z_boson": return .blue
        default: return .blue
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Group Toggle Row
struct GroupToggleRow: View {
    let group: OrganizationGroup
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Group Icon
            Image(systemName: isEnabled ? "bell.fill" : "bell.slash.fill")
                .font(.subheadline)
                .foregroundColor(isEnabled ? .blue : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isEnabled ? Color.blue.opacity(0.1) : Color(.systemGray5))
                        .frame(width: 32, height: 32)
                )
            
            // Group Info
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let description = group.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .scaleEffect(0.9)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}
