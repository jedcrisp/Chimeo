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
        
        do {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                print("📍 Location permission not determined, requesting...")
                locationManager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                print("📍 Location permission denied or restricted")
                self.hasError = true
                self.errorMessage = "Location services are disabled"
            case .authorizedWhenInUse, .authorizedAlways:
                print("📍 Location permission already granted")
                startLocationUpdates()
            @unknown default:
                print("📍 Unknown location authorization status")
                self.hasError = true
                self.errorMessage = "Unknown location authorization status"
            }
        } catch {
            print("❌ Error requesting location permission: \(error)")
            self.hasError = true
            self.errorMessage = "Error requesting location permission"
        }
    }
    
    func startLocationUpdates() {
        print("📍 startLocationUpdates() called")
        
        // Request location permission if not already granted
        if authorizationStatus == .notDetermined {
            print("📍 No permission yet, requesting...")
            requestLocationPermission()
            return
        }
        
        // Check if we have permission
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ No location permission, cannot start updates")
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
            self.errorMessage = error.localizedDescription
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Authorization status changed to: \(status.rawValue)")
        
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isLocationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
            
            if self.isLocationEnabled {
                print("✅ Location permission granted, starting updates...")
                self.startLocationUpdates()
            } else {
                print("❌ Location permission not granted, stopping updates...")
                self.stopLocationUpdates()
            }
        }
    }
} 