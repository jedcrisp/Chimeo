import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, @unchecked Sendable {
    private let locationManager = CLLocationManager()
    private var locationUpdateTimer: Timer?
    private let locationUpdateInterval: TimeInterval = 60.0 // 60 seconds
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var lastKnownLocation: CLLocation?
    @Published var hasError = false
    @Published var errorMessage = ""
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    deinit {
        locationUpdateTimer?.invalidate()
    }
    
    private func setupLocationManager() {
        // Add safety checks
        guard CLLocationManager.locationServicesEnabled() else {
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = "Location services are disabled"
                self.isLocationEnabled = false
            }
            return
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters // More battery efficient
        locationManager.distanceFilter = 50 // Only update if moved 50+ meters
        
        // Check current authorization status on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let status = self.locationManager.authorizationStatus
            DispatchQueue.main.async {
                self.authorizationStatus = status
                self.isLocationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
            }
        }
    }
    
    func requestLocationPermission() {
        print("📍 Requesting location permission...")
        
        // Check current authorization status first
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .notDetermined:
            print("📍 Location permission not determined, requesting...")
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("📍 Location permission denied or restricted")
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = "Location services are disabled"
                self.isLocationEnabled = false
            }
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location permission already granted")
            // Update the published property
            DispatchQueue.main.async {
                self.authorizationStatus = currentStatus
                self.isLocationEnabled = true
            }
            // Start location updates without calling requestLocationPermission again
            startLocationUpdates()
        @unknown default:
            print("📍 Unknown location authorization status")
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = "Unknown location authorization status"
                self.isLocationEnabled = false
            }
        }
    }
    
    func startLocationUpdates() {
        print("📍 startLocationUpdates() called")
        
        // Check current authorization status directly from locationManager
        let currentStatus = locationManager.authorizationStatus
        
        // If permission is not determined, we should not start updates
        // The authorization change delegate will handle starting updates
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            print("❌ No location permission (status: \(currentStatus.rawValue)), cannot start updates")
            return
        }
        
        print("✅ Starting timer-based location updates (every 60 seconds)...")
        
        // Get initial location immediately
        requestSingleLocationUpdate()
        
        // Stop any existing timer
        locationUpdateTimer?.invalidate()
        
        // Start timer for periodic updates every 60 seconds
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: locationUpdateInterval, repeats: true) { _ in
            self.requestSingleLocationUpdate()
        }
    }
    
    private func requestSingleLocationUpdate() {
        print("📍 Requesting single location update...")
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services are disabled")
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = "Location services are disabled"
                self.isLocationEnabled = false
            }
            return
        }
        
        // Check authorization status
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ No location permission, cannot request location")
            DispatchQueue.main.async {
                self.hasError = true
                self.errorMessage = "Location permission not granted"
                self.isLocationEnabled = false
            }
            return
        }
        
        // Configure for single-shot location request
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestLocation()
    }
    
    func stopLocationUpdates() {
        print("📍 Stopping location updates...")
        locationManager.stopUpdatingLocation()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    func getCurrentLocation() async -> CLLocation? {
        return await withCheckedContinuation { continuation in
            locationManager.requestLocation()
            // This is a simplified version - in production you'd want proper async handling
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                continuation.resume(returning: self.currentLocation)
            }
        }
    }
    
    func calculateDistance(to location: CLLocation) -> Double? {
        guard let currentLocation = currentLocation else { return nil }
        return currentLocation.distance(from: location)
    }
    
    func isWithinRadius(_ radius: Double, of location: CLLocation) -> Bool {
        guard let distance = calculateDistance(to: location) else { return false }
        return distance <= radius
    }
    
    func geocodeAddress(_ address: String) async -> [CLPlacemark]? {
        let geocoder = CLGeocoder()
        do {
            return try await geocoder.geocodeAddressString(address)
        } catch {
            print("Geocoding error: \(error)")
            return nil
        }
    }
    
    func reverseGeocode(location: CLLocation) async -> CLPlacemark? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first
        } catch {
            print("Reverse geocoding error: \(error)")
            return nil
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.lastKnownLocation = location
            self.isLocationEnabled = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error)")
        
        DispatchQueue.main.async {
            self.isLocationEnabled = false
            self.hasError = true
            
            // Provide more specific error messages
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.errorMessage = "Location access denied. Please enable location services in Settings."
                case .locationUnknown:
                    self.errorMessage = "Unable to determine location. Please check your GPS signal."
                case .network:
                    self.errorMessage = "Network error while getting location. Please check your internet connection."
                default:
                    self.errorMessage = "Location error: \(clError.localizedDescription)"
                }
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Authorization status changed to: \(status.rawValue)")
        
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isLocationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
            
            if self.isLocationEnabled {
                print("✅ Location permission granted, starting updates...")
                // Only start updates if we don't already have a timer running
                if self.locationUpdateTimer == nil {
                    self.startLocationUpdates()
                }
            } else {
                print("❌ Location permission not granted, stopping updates...")
                self.stopLocationUpdates()
            }
        }
    }
} 