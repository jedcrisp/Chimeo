import Foundation
import CoreLocation
import SwiftUI

// MARK: - Location Coordinate
struct LocationCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Weather Alert Types
enum WeatherAlertType: String, CaseIterable, Codable {
    case severeThunderstorm = "severe_thunderstorm"
    case tornado = "tornado"
    case flashFlood = "flash_flood"
    case winterStorm = "winter_storm"
    case blizzard = "blizzard"
    case hurricane = "hurricane"
    case tropicalStorm = "tropical_storm"
    case heatWave = "heat_wave"
    case extremeCold = "extreme_cold"
    case airQuality = "air_quality"
    case wildfire = "wildfire"
    case dustStorm = "dust_storm"
    case highWind = "high_wind"
    case hail = "hail"
    case iceStorm = "ice_storm"
    
    var displayName: String {
        switch self {
        case .severeThunderstorm: return "Severe Thunderstorm"
        case .tornado: return "Tornado"
        case .flashFlood: return "Flash Flood"
        case .winterStorm: return "Winter Storm"
        case .blizzard: return "Blizzard"
        case .hurricane: return "Hurricane"
        case .tropicalStorm: return "Tropical Storm"
        case .heatWave: return "Heat Wave"
        case .extremeCold: return "Extreme Cold"
        case .airQuality: return "Air Quality"
        case .wildfire: return "Wildfire"
        case .dustStorm: return "Dust Storm"
        case .highWind: return "High Wind"
        case .hail: return "Hail"
        case .iceStorm: return "Ice Storm"
        }
    }
    
    var icon: String {
        switch self {
        case .severeThunderstorm: return "cloud.bolt.rain"
        case .tornado: return "tornado"
        case .flashFlood: return "drop.triangle"
        case .winterStorm: return "snow"
        case .blizzard: return "wind.snow"
        case .hurricane: return "hurricane"
        case .tropicalStorm: return "tropicalstorm"
        case .heatWave: return "thermometer.sun"
        case .extremeCold: return "thermometer.snowflake"
        case .airQuality: return "lungs"
        case .wildfire: return "flame"
        case .dustStorm: return "wind"
        case .highWind: return "wind"
        case .hail: return "cloud.hail"
        case .iceStorm: return "cloud.sleet"
        }
    }
    
    var color: Color {
        switch self {
        case .tornado, .hurricane: return .red
        case .severeThunderstorm, .flashFlood, .blizzard: return .orange
        case .winterStorm, .iceStorm: return .blue
        case .heatWave, .extremeCold: return .purple
        case .wildfire: return .brown
        case .airQuality, .dustStorm: return .yellow
        case .highWind, .hail: return .gray
        case .tropicalStorm: return .orange
        }
    }
    
    var severity: IncidentSeverity {
        switch self {
        case .tornado, .hurricane: return .critical
        case .severeThunderstorm, .flashFlood, .blizzard: return .high
        case .winterStorm, .iceStorm, .wildfire: return .high
        case .heatWave, .extremeCold: return .medium
        case .airQuality, .dustStorm, .highWind, .hail: return .medium
        case .tropicalStorm: return .high
        }
    }
}

// MARK: - Weather Data Models
struct WeatherData: Codable, Identifiable {
    let id = UUID()
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let windDirection: String
    let pressure: Double
    let visibility: Double
    let uvIndex: Int
    let condition: String
    let conditionIcon: String
    let sunrise: Date
    let sunset: Date
    let timestamp: Date
    
    var temperatureFormatted: String {
        "\(Int(round(temperature)))°F"
    }
    
    var feelsLikeFormatted: String {
        "\(Int(round(feelsLike)))°F"
    }
}

// MARK: - Weather Alert
struct WeatherAlert: Codable, Identifiable, Hashable {
    let id: String
    let type: WeatherAlertType
    let title: String
    let description: String
    let severity: IncidentSeverity
    let location: Location
    let effectiveTime: Date
    let expirationTime: Date
    let instructions: String?
    let source: String
    let polygon: [LocationCoordinate]?
    let distance: Double?
    
    var isActive: Bool {
        let now = Date()
        return now >= effectiveTime && now <= expirationTime
    }
    
    var timeRemaining: TimeInterval {
        expirationTime.timeIntervalSinceNow
    }
    
    var formattedTimeRemaining: String {
        let hours = Int(timeRemaining / 3600)
        let minutes = Int((timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes)m remaining"
        }
    }
    
    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WeatherAlert, rhs: WeatherAlert) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Weather Location Type
enum WeatherLocationType: String, CaseIterable, Codable {
    case city = "city"
    case zipCode = "zip_code"
    case coordinates = "coordinates"
    
    var displayName: String {
        switch self {
        case .city: return "City"
        case .zipCode: return "Zip Code"
        case .coordinates: return "Coordinates"
        }
    }
    
    var icon: String {
        switch self {
        case .city: return "building.2"
        case .zipCode: return "number"
        case .coordinates: return "location"
        }
    }
}

// MARK: - Followed Location
struct FollowedLocation: Codable, Identifiable {
    let id = UUID()
    let name: String
    let type: WeatherLocationType
    let value: String
    var isEnabled: Bool = true
    
    init(name: String, type: WeatherLocationType, value: String, isEnabled: Bool = true) {
        self.name = name
        self.type = type
        self.value = value
        self.isEnabled = isEnabled
    }
}
