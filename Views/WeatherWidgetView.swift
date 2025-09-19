import SwiftUI

struct WeatherWidgetView: View {
    @ObservedObject var weatherService: WeatherService
    @State private var showingWeatherDetails = false
    @State private var showingWeatherAlerts = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Current weather card
            currentWeatherCard
            
            // Weather alerts banner (if any) - temporarily disabled
            // if !weatherService.getActiveAlerts().isEmpty {
            //     weatherAlertsBanner
            // }
        }
        .sheet(isPresented: $showingWeatherDetails) {
            WeatherDetailsView(weatherService: weatherService)
        }
        // .sheet(isPresented: $showingWeatherAlerts) {
        //     WeatherAlertsListView(weatherService: weatherService)
        // }
    }
    
    private var currentWeatherCard: some View {
        Button(action: {
            showingWeatherDetails = true
        }) {
            HStack(spacing: 12) {
                // Weather icon and temperature
                HStack(spacing: 8) {
                    if let weather = weatherService.currentWeather {
                        Image(systemName: weather.conditionIcon)
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text(weather.temperatureFormatted)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                }
                
                Spacer()
                
                // Location and refresh button
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Current Location")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Button(action: {
                        weatherService.refreshWeatherData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var weatherAlertsBanner: some View {
        Button(action: {
            showingWeatherAlerts = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weather Alerts Active")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("0 alert(s) in your area") // Temporarily hardcoded
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.9), Color.red.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct WeatherDetailsView: View {
    @ObservedObject var weatherService: WeatherService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let weather = weatherService.currentWeather {
                    VStack(spacing: 24) {
                        // Current conditions
                        currentConditionsSection(weather)
                        
                        // Additional details
                        additionalDetailsSection(weather)
                        
                        // Sunrise/sunset
                        sunTimingSection(weather)
                        
                        // Last updated
                        lastUpdatedSection
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        ProgressView("Loading weather data...")
                            .padding()
                    }
                }
            }
            .navigationTitle("Current Weather")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") {
                        weatherService.refreshWeatherData()
                    }
                }
            }
        }
    }
    
    private func currentConditionsSection(_ weather: WeatherData) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: weather.conditionIcon)
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(weather.condition)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(weather.temperatureFormatted)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Feels like \(weather.feelsLikeFormatted)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func additionalDetailsSection(_ weather: WeatherData) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            WeatherDetailCard(
                icon: "thermometer",
                title: "Humidity",
                value: "\(weather.humidity)%"
            )
            
            WeatherDetailCard(
                icon: "wind",
                title: "Wind",
                value: "\(Int(weather.windSpeed)) mph \(weather.windDirection)"
            )
            
            WeatherDetailCard(
                icon: "gauge",
                title: "Pressure",
                value: String(format: "%.2f inHg", weather.pressure)
            )
            
            WeatherDetailCard(
                icon: "eye",
                title: "Visibility",
                value: "\(Int(weather.visibility)) mi"
            )
            
            WeatherDetailCard(
                icon: "sun.max",
                title: "UV Index",
                value: "\(weather.uvIndex)"
            )
            
            WeatherDetailCard(
                icon: "clock",
                title: "Updated",
                value: formatTime(weather.timestamp)
            )
        }
    }
    
    private func sunTimingSection(_ weather: WeatherData) -> some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "sunrise")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Sunrise")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatTime(weather.sunrise))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Image(systemName: "sunset")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Sunset")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatTime(weather.sunset))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var lastUpdatedSection: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            
            Text("Last updated: \(formatTime(weatherService.lastUpdated ?? Date()))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct WeatherDetailCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeatherAlertsListView: View {
    @ObservedObject var weatherService: WeatherService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAlert: WeatherAlert?
    
    var body: some View {
        NavigationView {
            List {
                if weatherService.weatherAlerts.isEmpty {
                    ContentUnavailableView(
                        "No Weather Alerts",
                        systemImage: "checkmark.shield",
                        description: Text("There are currently no active weather alerts in your area.")
                    )
                } else {
                    ForEach(weatherService.weatherAlerts) { alert in
                        WeatherAlertRow(alert: alert) {
                            selectedAlert = alert
                        }
                    }
                }
            }
            .navigationTitle("Weather Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedAlert) { alert in
            WeatherAlertView(alert: alert)
        }
    }
}

struct WeatherAlertRow: View {
    let alert: WeatherAlert
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: alert.type.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(alert.type.color)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(alert.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if alert.isActive {
                        Text(alert.formattedTimeRemaining)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(alert.severity.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(alert.severity.color)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WeatherWidgetView(weatherService: WeatherService(locationManager: LocationManager()))
}
