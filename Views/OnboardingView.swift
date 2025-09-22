import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPage(
            title: "Welcome to Chimeo",
            description: "Stay informed about important events and incidents in your community",
            imageName: "bell.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "Real-time Alerts",
            description: "Get instant notifications about emergencies, weather, and community updates",
            imageName: "exclamationmark.triangle.fill",
            color: .orange
        ),
        OnboardingPage(
            title: "Follow Organizations",
            description: "Stay connected with local organizations, schools, and emergency services",
            imageName: "building.2.fill",
            color: .green
        ),
        OnboardingPage(
            title: "Location-based",
            description: "Receive alerts relevant to your specific location and areas of interest",
            imageName: "location.fill",
            color: .purple
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 20)
                
                // Action Buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                        if currentPage == pages.count - 1 {
                            dismiss()
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(page.color)
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
