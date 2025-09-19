import Foundation
import CoreLocation
import SwiftUI

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
        }
    }
    
    var severity: IncidentSeverity {
        switch self {
        case .tornado, .hurricane: return .critical
        case .severeThunderstorm, .flashFlood, .blizzard: return .high
        case .winterStorm, .iceStorm, .wildfire: return .high
        case .heatWave, .extremeCold: return .medium
        case .airQuality, .dustStorm, .highWind, .hail: return .medium
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
struct WeatherAlert: Codable, Identifiable {
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
    let polygon: [CLLocationCoordinate2D]?
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
}
