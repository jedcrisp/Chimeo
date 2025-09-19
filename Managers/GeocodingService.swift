import Foundation
import CoreLocation
import MapKit

// MARK: - Geocoding Service
class GeocodingService: ObservableObject {
    static let shared = GeocodingService()
    
    private let geocoder = CLGeocoder()
    
    private init() {}
    
    // MARK: - Address to Coordinates
    /// Convert a full address string to coordinates
    func geocodeAddress(_ address: String) async -> Location? {
        print("🌍 Geocoding address: \(address)")
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            
            if let placemark = placemarks.first,
               let location = placemark.location {
                let result = Location(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: address, // Use the original address the user entered
                    city: placemark.locality,
                    state: placemark.administrativeArea,
                    zipCode: placemark.postalCode
                )
                
                print("✅ Geocoding successful: \(result.coordinate.latitude), \(result.coordinate.longitude)")
                return result
            } else {
                print("❌ No placemarks found for address: \(address)")
            }
        } catch {
            print("⚠️ Geocoding failed: \(error)")
        }
        
        return nil
    }
    
    /// Convert address components to coordinates
    func geocodeAddressComponents(address: String, city: String, state: String, zipCode: String) async -> Location? {
        let fullAddress = "\(address), \(city), \(state) \(zipCode)"
        return await geocodeAddress(fullAddress)
    }
    
    // MARK: - Coordinates to Address
    /// Convert coordinates to an address (reverse geocoding)
    func reverseGeocode(latitude: Double, longitude: Double) async -> Location? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            if let placemark = placemarks.first {
                let result = Location(
                    latitude: latitude,
                    longitude: longitude,
                    address: "Reverse geocoded location", // For reverse geocoding, we don't have an original address
                    city: placemark.locality,
                    state: placemark.administrativeArea,
                    zipCode: placemark.postalCode
                )
                
                print("✅ Reverse geocoding successful: \(result.fullAddress)")
                return result
            }
        } catch {
            print("⚠️ Reverse geocoding failed: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Batch Geocoding
    /// Geocode multiple addresses efficiently
    func geocodeAddresses(_ addresses: [String]) async -> [String: Location] {
        var results: [String: Location] = [:]
        
        // Process addresses in parallel with a limit to avoid overwhelming the geocoding service
        let semaphore = DispatchSemaphore(value: 3) // Limit to 3 concurrent requests
        
        await withTaskGroup(of: (String, Location?).self) { group in
            for address in addresses {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        semaphore.wait()
                        Task {
                            let location = await self.geocodeAddress(address)
                            continuation.resume(returning: (address, location))
                            semaphore.signal()
                        }
                    }
                }
            }
            
            for await (address, location) in group {
                if let location = location {
                    results[address] = location
                }
            }
        }
        
        return results
    }
    
    // MARK: - Validation and Fallbacks
    /// Check if coordinates are valid (not 0,0 or default values)
    func areCoordinatesValid(_ latitude: Double, _ longitude: Double) -> Bool {
        // Check for invalid coordinates
        if latitude == 0.0 && longitude == 0.0 { return false }
        if latitude == 33.1032 && longitude == -96.6705 { return false } // Default fallback
        if latitude == 33.2148 && longitude == -97.1331 { return false } // Default fallback
        
        // Check for reasonable coordinate ranges
        if latitude < -90 || latitude > 90 { return false }
        if longitude < -180 || longitude > 180 { return false }
        
        return true
    }
    
    /// Get fallback coordinates for a city/state
    func getFallbackCoordinates(for city: String, state: String) -> (latitude: Double, longitude: Double) {
        let cityState = "\(city.lowercased()), \(state.lowercased())"
        
        switch cityState {
        case "denton, tx":
            return (33.2148, -97.1331)
        case "allen, tx":
            return (33.1032, -96.6705)
        case "plano, tx":
            return (33.0198, -96.6989)
        case "frisco, tx":
            return (33.1507, -96.8236)
        case "mckinney, tx":
            return (33.1972, -96.6397)
        case "dallas, tx":
            return (32.7767, -96.7970)
        case "fort worth, tx":
            return (32.7555, -97.3308)
        case "arlington, tx":
            return (32.7357, -97.1081)
        default:
            // Generic Texas coordinates as final fallback
            return (32.7767, -96.7970)
        }
    }
    
    // MARK: - Organization Geocoding
    /// Geocode an organization's address and update its location
    func geocodeOrganization(_ organization: Organization) async -> Organization? {
        // Check if organization already has valid coordinates
        if areCoordinatesValid(organization.location.latitude, organization.location.longitude) {
            print("✅ \(organization.name) already has valid coordinates")
            return nil
        }
        
        // Try to get address from nested location or flat fields
        let address = organization.location.address ?? organization.address ?? ""
        let city = organization.location.city ?? organization.city ?? ""
        let state = organization.location.state ?? organization.state ?? ""
        let zipCode = organization.location.zipCode ?? organization.zipCode ?? ""
        
        // Check if we have enough address data
        if address.isEmpty || city.isEmpty || state.isEmpty {
            print("❌ \(organization.name) missing required address data")
            return nil
        }
        
        // Attempt geocoding
        if let geocodedLocation = await geocodeAddressComponents(
            address: address,
            city: city,
            state: state,
            zipCode: zipCode
        ) {
            print("✅ Successfully geocoded \(organization.name)")
            
            // Create updated organization with geocoded coordinates
            return Organization(
                id: organization.id,
                name: organization.name,
                type: organization.type,
                description: organization.description,
                location: geocodedLocation,
                verified: organization.verified,
                followerCount: organization.followerCount,
                logoURL: organization.logoURL,
                website: organization.website,
                phone: organization.phone,
                email: organization.email,
                groups: organization.groups,
                adminIds: organization.adminIds,
                createdAt: organization.createdAt,
                updatedAt: Date(),
                address: organization.address,
                city: organization.city,
                state: organization.state,
                zipCode: organization.zipCode
            )
        } else {
            print("❌ Failed to geocode \(organization.name)")
            return nil
        }
    }
}
