import Foundation
import CoreLocation
import Combine
import SwiftUI

// Note: WeatherAlert and WeatherAlertType are defined in WeatherModels.swift



// MARK: - Weather Data Models
// WeatherData is now defined in WeatherModels.swift



// MARK: - Weather Service
class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherData?
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    private var cancellables = Set<AnyCancellable>()
    let locationManager: LocationManager
    // private let notificationManager: WeatherNotificationManager
    // private let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect() // Update every 5 minutes - DISABLED
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        // self.notificationManager = WeatherNotificationManager()
        setupLocationUpdates()
        setupTimer()
    }
    
    private func setupLocationUpdates() {
        // DISABLED: Automatic weather updates on location change
        // locationManager.$currentLocation
        //     .compactMap { $0 }
        //     .debounce(for: .seconds(2), scheduler: RunLoop.main)
        //     .sink { [weak self] location in
        //         self?.fetchWeatherData(for: location.coordinate)
        //     }
        //     .store(in: &cancellables)
    }
    
    private func setupTimer() {
        // DISABLED: Automatic weather updates every 5 minutes
        // timer
        //     .sink { [weak self] _ in
        //         if let location = self?.locationManager.currentLocation {
        //             self?.fetchWeatherData(for: location.coordinate)
        //         }
        //     }
        //     .store(in: &cancellables)
    }
    
    func fetchWeatherData(for coordinate: CLLocationCoordinate2D) {
        isLoading = true
        
        // Fetch both current weather and alerts
        Task {
            async let weatherTask = fetchCurrentWeather(coordinate: coordinate)
            async let alertsTask = fetchWeatherAlerts(coordinate: coordinate)
            
            do {
                let (weather, alerts) = await (try weatherTask, try alertsTask)
                
                await MainActor.run {
                    self.currentWeather = weather
                    self.weatherAlerts = alerts
                    self.isLoading = false
                    self.lastUpdated = Date()
                    
                    // Monitor alerts for notifications
                    // self.notificationManager.monitorWeatherAlerts(alerts)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Error fetching weather data: \(error)")
                }
            }
        }
    }
    
    private func fetchCurrentWeather(coordinate: CLLocationCoordinate2D) async throws -> WeatherData {
        // In a real app, you'd use a weather API like OpenWeatherMap, WeatherAPI, or NOAA
        // For now, we'll create mock data for development
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock weather data based on time of day
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        let baseTemp: Double
        let condition: String
        let conditionIcon: String
        
        if hour >= 6 && hour < 18 {
            // Daytime
            baseTemp = 75.0
            condition = "Partly Cloudy"
            conditionIcon = "cloud.sun.fill"
        } else {
            // Nighttime
            baseTemp = 65.0
            condition = "Clear"
            conditionIcon = "moon.stars.fill"
        }
        
        // Add some variation based on coordinates
        let tempVariation = sin(coordinate.latitude) * 10
        let temperature = baseTemp + tempVariation
        
        return WeatherData(
            temperature: temperature,
            feelsLike: temperature + Double.random(in: -2...2),
            humidity: Int.random(in: 40...80),
            windSpeed: Double.random(in: 5...15),
            windDirection: ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].randomElement() ?? "N",
            pressure: 29.92 + Double.random(in: -0.5...0.5),
            visibility: Double.random(in: 8...12),
            uvIndex: hour >= 10 && hour <= 16 ? Int.random(in: 5...10) : Int.random(in: 0...3),
            condition: condition,
            conditionIcon: conditionIcon,
            sunrise: calendar.date(bySettingHour: 6, minute: 30, second: 0, of: now) ?? now,
            sunset: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: now) ?? now,
            timestamp: now
        )
    }
    
    private func fetchWeatherAlerts(coordinate: CLLocationCoordinate2D) async throws -> [WeatherAlert] {
        // In a real app, you'd fetch from NOAA's weather alert API
        // For now, we'll create mock alerts for development
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        var mockAlerts: [WeatherAlert] = []
        
        // Randomly generate some weather alerts
        let alertTypes: [WeatherAlertType] = [.severeThunderstorm, .flashFlood, .highWind, .heatWave]
        let shouldHaveAlert = Bool.random()
        
        if shouldHaveAlert {
            let alertType = alertTypes.randomElement() ?? .severeThunderstorm
            let now = Date()
            let effectiveTime = now.addingTimeInterval(-3600) // Started 1 hour ago
            let expirationTime = now.addingTimeInterval(Double.random(in: 3600...7200)) // Expires in 1-2 hours
            
            let alert = WeatherAlert(
                id: UUID().uuidString,
                type: alertType,
                title: "\(alertType.displayName) Warning",
                description: "A \(alertType.displayName.lowercased()) has been detected in your area. Please take necessary precautions.",
                severity: alertType.severity,
                location: Location(
                    latitude: coordinate.latitude + Double.random(in: -0.01...0.01),
                    longitude: coordinate.longitude + Double.random(in: -0.01...0.01),
                    city: "Local Area",
                    state: "TX"
                ),
                effectiveTime: effectiveTime,
                expirationTime: expirationTime,
                instructions: "Stay indoors and monitor local weather reports. Avoid travel if possible.",
                source: "National Weather Service",
                polygon: nil,
                distance: Double.random(in: 0.5...5.0)
            )
            
            mockAlerts.append(alert)
        }
        
        return mockAlerts
    }
    
    func refreshWeatherData() {
        if let location = locationManager.currentLocation {
            fetchWeatherData(for: location.coordinate)
        }
    }
    
    func getActiveAlerts() -> [WeatherAlert] {
        return weatherAlerts.filter { $0.isActive }
    }
    
    func getCriticalAlerts() -> [WeatherAlert] {
        return weatherAlerts.filter { $0.isActive && $0.severity == .critical }
    }
    
    // MARK: - Mock Data for Development
    func addMockAlert() {
        let mockAlert = WeatherAlert(
            id: UUID().uuidString,
            type: .severeThunderstorm,
            title: "Test Weather Alert",
            description: "This is a test weather alert for development purposes",
            severity: .high,
            location: Location(
                latitude: 33.2148,
                longitude: -97.1331,
                address: "123 Test St, Test City, TC 12345",
                city: "Test City",
                state: "TC",
                zipCode: "76201"
            ),
            effectiveTime: Date(),
            expirationTime: Date().addingTimeInterval(3600),
            instructions: "Stay indoors and avoid windows",
            source: "Test Source",
            polygon: nil,
            distance: nil
        )
        
        weatherAlerts.append(mockAlert)
    }
    
    func clearMockAlerts() {
        weatherAlerts.removeAll()
    }
    
    deinit {
        cancellables.removeAll()
    }
}
