import SwiftUI

// This view can be used to generate the app icon
// Take a screenshot of this view at 1024x1024 to create the App Store icon
struct AppIconGenerator: View {
    var body: some View {
        ZStack {
            // Background - use a gradient similar to the app's theme
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Main bell icon with notification dot
            VStack(spacing: 20) {
                ZStack {
                    // Bell icon
                    Image(systemName: "bell")
                        .font(.system(size: 300, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    
                    // Notification dot
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 80, height: 80)
                        .offset(x: 60, y: -60)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                
                Text("Chimeo")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
        }
        .frame(width: 1024, height: 1024)
        .background(Color.white)
    }
}

#Preview {
    AppIconGenerator()
        .frame(width: 300, height: 300)
        .scaleEffect(0.3)
} 