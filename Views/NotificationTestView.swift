import SwiftUI
import FirebaseMessaging
import FirebaseFirestore

struct NotificationTestView: View {
    @EnvironmentObject var notificationService: iOSNotificationService
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isTesting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Notification Test Center")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Test your push notification setup")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Status Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Current Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        StatusRow(
                            title: "FCM Token",
                            value: notificationManager.fcmToken != nil ? "✅ Available" : "❌ Not Available",
                            color: notificationManager.fcmToken != nil ? .green : .red
                        )
                        
                        StatusRow(
                            title: "Notification Permission",
                            value: notificationManager.isAuthorized ? "✅ Granted" : "❌ Not Granted",
                            color: notificationManager.isAuthorized ? .green : .red
                        )
                        
                        StatusRow(
                            title: "Last Notification",
                            value: notificationService.lastNotification?.title ?? "None",
                            color: notificationService.lastNotification != nil ? .blue : .secondary
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Test Buttons
                VStack(spacing: 15) {
                    Button(action: testLocalNotification) {
                        HStack {
                            Image(systemName: "bell")
                            Text("Test Local Notification")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: testFCMToken) {
                        HStack {
                            Image(systemName: "key")
                            Text("Test FCM Token")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: testServiceWorker) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Test Service Worker")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: runAllTests) {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("Run All Tests")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isTesting)
                }
                
                // Debug Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Debug Tools")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        Button(action: debugOrganizationLogoIssues) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Debug Organization Logo Issues")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: cleanUpPlaceholderLogoURLs) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clean Up Invalid Logo URLs")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: testOrganizationLogoLoading) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Test Organization Logo Loading")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: removeExampleComURLs) {
                            HStack {
                                Image(systemName: "trash.circle")
                                Text("Remove Example.com URLs")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Notification History
                if !notificationService.notificationHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Recent Notifications")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("Clear") {
                                notificationService.clearNotificationHistory()
                            }
                            .foregroundColor(.red)
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(notificationService.notificationHistory.prefix(5)) { notification in
                                    NotificationHistoryRow(notification: notification)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Notification Test")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Test Result", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Test Functions
    private func testLocalNotification() {
        isTesting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            notificationService.sendTestNotification()
            alertMessage = "Local notification test completed! Check your notification center."
            showingAlert = true
            isTesting = false
        }
    }
    
    private func testFCMToken() {
        isTesting = true
        
        guard let token = notificationManager.fcmToken else {
            alertMessage = "No FCM token available. Please check your notification permissions."
            showingAlert = true
            isTesting = false
            return
        }
        
        Task {
            let isValid = await notificationService.validateFCMToken(token)
            
            await MainActor.run {
                if isValid {
                    alertMessage = "FCM token is valid and working correctly!"
                } else {
                    alertMessage = "FCM token validation failed. Please check your setup."
                }
                showingAlert = true
                isTesting = false
            }
        }
    }
    
    private func testServiceWorker() {
        isTesting = true
        
        // Check if service worker is supported (iOS doesn't have service workers like web)
        let isSupported = false // iOS doesn't support service workers
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if isSupported {
                alertMessage = "Service worker test completed successfully!"
            } else {
                alertMessage = "Service workers are not supported on iOS. This is normal."
            }
            showingAlert = true
            isTesting = false
        }
    }
    
    // MARK: - Debug Functions
    private func debugOrganizationLogoIssues() {
        Task {
            await serviceCoordinator.debugOrganizationLogoIssues()
            await MainActor.run {
                alertMessage = "Organization logo debug completed! Check the console for details."
                showingAlert = true
            }
        }
    }
    
    private func cleanUpPlaceholderLogoURLs() {
        Task {
            print("🧹 Cleaning up invalid logo URLs from organizations...")
            
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("organizations").getDocuments()
                
                var cleanedCount = 0
                var totalChecked = 0
                
                for document in snapshot.documents {
                    totalChecked += 1
                    let data = document.data()
                    
                    if let logoURL = data["logoURL"] as? String, !logoURL.isEmpty {
                        // Only remove URLs that are clearly invalid (no scheme, no host, etc.)
                        if let url = URL(string: logoURL) {
                            let scheme = url.scheme ?? ""
                            let host = url.host ?? ""
                            
                            // Only remove URLs that are structurally invalid
                            if scheme.isEmpty || host.isEmpty || (scheme != "http" && scheme != "https") {
                                print("🧹 Cleaning up structurally invalid logo URL:")
                                print("   - Organization ID: \(document.documentID)")
                                print("   - Organization Name: \(data["name"] as? String ?? "Unknown")")
                                print("   - Invalid Logo URL: \(logoURL)")
                                print("   - Scheme: \(scheme)")
                                print("   - Host: \(host)")
                                
                                // Remove the invalid logo URL
                                try await db.collection("organizations").document(document.documentID).updateData([
                                    "logoURL": FieldValue.delete()
                                ])
                                
                                cleanedCount += 1
                                print("   ✅ Logo URL removed successfully")
                            }
                        } else {
                            // URL string couldn't be parsed at all
                            print("🧹 Cleaning up unparseable logo URL:")
                            print("   - Organization ID: \(document.documentID)")
                            print("   - Organization Name: \(data["name"] as? String ?? "Unknown")")
                            print("   - Unparseable Logo URL: \(logoURL)")
                            
                            try await db.collection("organizations").document(document.documentID).updateData([
                                "logoURL": FieldValue.delete()
                            ])
                            
                            cleanedCount += 1
                            print("   ✅ Logo URL removed successfully")
                        }
                    }
                }
                
                print("📊 Logo URL Cleanup Summary:")
                print("   - Total organizations checked: \(totalChecked)")
                print("   - Invalid logo URLs cleaned: \(cleanedCount)")
                
                await MainActor.run {
                    alertMessage = "Logo URL cleanup completed! Check the console for details. Cleaned: \(cleanedCount) URLs"
                    showingAlert = true
                }
                
            } catch {
                print("❌ Error cleaning up invalid logo URLs: \(error)")
                await MainActor.run {
                    alertMessage = "Error cleaning up invalid logo URLs: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func testOrganizationLogoLoading() {
        Task {
            print("🔍 Testing Organization Logo Loading...")
            
            // Get organizations from the service coordinator
            let organizations = serviceCoordinator.organizations
            print("📊 Found \(organizations.count) organizations")
            
            var organizationsWithLogos = 0
            var organizationsWithValidLogos = 0
            var organizationsWithInvalidLogos = 0
            
            for organization in organizations {
                if let logoURL = organization.logoURL, !logoURL.isEmpty {
                    organizationsWithLogos += 1
                    print("🏢 Organization: \(organization.name)")
                    print("   - ID: \(organization.id)")
                    print("   - Logo URL: \(logoURL)")
                    
                    // Test URL validity
                    if let url = URL(string: logoURL) {
                        print("   - URL scheme: \(url.scheme ?? "nil")")
                        print("   - URL host: \(url.host ?? "nil")")
                        print("   - URL path: \(url.path)")
                        
                        // Test if URL is accessible
                        do {
                            let (_, response) = try await URLSession.shared.data(from: url)
                            if let httpResponse = response as? HTTPURLResponse {
                                print("   - HTTP Status: \(httpResponse.statusCode)")
                                if httpResponse.statusCode == 200 {
                                    organizationsWithValidLogos += 1
                                    print("   - ✅ Logo URL is accessible")
                                } else {
                                    organizationsWithInvalidLogos += 1
                                    print("   - ❌ Logo URL returned status: \(httpResponse.statusCode)")
                                }
                            }
                        } catch {
                            organizationsWithInvalidLogos += 1
                            print("   - ❌ Failed to access logo URL: \(error)")
                        }
                    } else {
                        organizationsWithInvalidLogos += 1
                        print("   - ❌ Invalid URL format")
                    }
                    print("")
                } else {
                    print("🏢 Organization: \(organization.name) - No logo URL")
                }
            }
            
            print("📊 Logo Loading Test Summary:")
            print("   - Total organizations: \(organizations.count)")
            print("   - Organizations with logos: \(organizationsWithLogos)")
            print("   - Valid logo URLs: \(organizationsWithValidLogos)")
            print("   - Invalid logo URLs: \(organizationsWithInvalidLogos)")
            
            await MainActor.run {
                alertMessage = "Logo test completed! Check console for details. Valid: \(organizationsWithValidLogos), Invalid: \(organizationsWithInvalidLogos)"
                showingAlert = true
            }
        }
    }
    
    private func removeExampleComURLs() {
        Task {
            print("🧹 Attempting to remove Example.com URLs from organizations...")
            
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("organizations").getDocuments()
                
                var removedCount = 0
                var totalChecked = 0
                
                for document in snapshot.documents {
                    totalChecked += 1
                    let data = document.data()
                    
                    if let logoURL = data["logoURL"] as? String, logoURL.contains("example.com") {
                        print("🧹 Found Example.com URL in organization \(document.documentID):")
                        print("   - Organization Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Original Logo URL: \(logoURL)")
                        
                        try await db.collection("organizations").document(document.documentID).updateData([
                            "logoURL": FieldValue.delete()
                        ])
                        
                        removedCount += 1
                        print("   ✅ Example.com URL removed successfully")
                    } else {
                        print("🏢 Organization \(document.documentID) - No Example.com URL")
                    }
                }
                
                print("📊 Example.com URL Removal Summary:")
                print("   - Total organizations checked: \(totalChecked)")
                print("   - Example.com URLs removed: \(removedCount)")
                
                await MainActor.run {
                    alertMessage = "Example.com URL removal completed! Check the console for details. Removed: \(removedCount) URLs"
                    showingAlert = true
                }
                
            } catch {
                print("❌ Error removing Example.com URLs: \(error)")
                await MainActor.run {
                    alertMessage = "Error removing Example.com URLs: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func runAllTests() {
        isTesting = true
        
        // Run tests sequentially
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            testLocalNotification()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                testFCMToken()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    testServiceWorker()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        alertMessage = "All tests completed! Check the results above."
                        showingAlert = true
                        isTesting = false
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct StatusRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
}

struct NotificationHistoryRow: View {
    let notification: PushNotification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(notification.body)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text(notification.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

#Preview {
    NotificationTestView()
        .environmentObject(iOSNotificationService())
        .environmentObject(NotificationManager())
}
