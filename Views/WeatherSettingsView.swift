import SwiftUI

// Import weather models

struct WeatherSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weatherAlertsEnabled") private var weatherAlertsEnabled = true
    @AppStorage("criticalWeatherAlertsOnly") private var criticalWeatherAlertsOnly = false
    @AppStorage("weatherUpdateInterval") private var weatherUpdateInterval = 5 // minutes
    @AppStorage("weatherAlertRadius") private var weatherAlertRadius = 25.0 // miles
    // @AppStorage("weatherAlertTypes") private var enabledWeatherAlertTypes = Set(WeatherAlertType.allCases.map { $0.rawValue })
    
    var body: some View {
        NavigationView {
            Form {
                // General settings
                Section("General") {
                    Toggle("Enable Weather Alerts", isOn: $weatherAlertsEnabled)
                    
                    if weatherAlertsEnabled {
                        Toggle("Critical Alerts Only", isOn: $criticalWeatherAlertsOnly)
                        
                        HStack {
                            Text("Update Interval")
                            Spacer()
                            Picker("Update Interval", selection: $weatherUpdateInterval) {
                                Text("1 min").tag(1)
                                Text("5 min").tag(5)
                                Text("15 min").tag(15)
                                Text("30 min").tag(30)
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Text("Alert Radius")
                            Spacer()
                            Text("\(Int(weatherAlertRadius)) miles")
                        }
                        
                        Slider(value: $weatherAlertRadius, in: 5...100, step: 5)
                    }
                }
                
                // Alert type preferences - temporarily simplified
                // if weatherAlertsEnabled {
                //     Section("Alert Types") {
                //         ForEach(WeatherAlertType.allCases, id: \.self) { alertType in
                //             WeatherAlertTypeToggle(
                //                 alertType: alertType,
                //                 isEnabled: enabledWeatherAlertTypes.contains(alertType.rawValue),
                //                 onToggle: { isEnabled in
                //                     if isEnabled {
                //                         enabledWeatherAlertTypes.insert(alertType.rawValue)
                //                     } else {
                //                         enabledWeatherAlertTypes.remove(alertType.rawValue)
                //                     }
                //                 }
                //             )
                //         }
                //     }
                // }
                
                // Information
                Section("Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weather alerts are provided by the National Weather Service and other official sources.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Critical alerts (Tornado, Hurricane) will always be shown regardless of your settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Weather Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// struct WeatherAlertTypeToggle: View {
//     let alertType: WeatherAlertType
//     let isEnabled: Bool
//     let onToggle: (Bool) -> Void
//     
//     var body: some View {
//         HStack {
//         Image(systemName: alertType.icon)
//             .foregroundColor(alertType.color)
//             .frame(width: 24)
//         
//         VStack(alignment: .leading, spacing: 2) {
//             Text(alertType.displayName)
//                 .font(.body)
//         
//         Text("Severity: \(alertType.severity.displayName)")
//             .font(.caption)
//             .foregroundColor(.secondary)
//         }
//         
//         Spacer()
//         
//         Toggle("", isOn: Binding(
//             get: { isEnabled },
//             set: { onToggle($0) }
//         ))
//         .labelsHidden()
//     }
//     .contentShape(Rectangle())
//     .onTapGesture {
//         onToggle(!isEnabled)
//     }
// }

#Preview {
    WeatherSettingsView()
}
