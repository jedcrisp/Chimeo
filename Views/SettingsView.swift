import SwiftUI
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var notificationService: iOSNotificationService
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @EnvironmentObject var weatherNotificationManager: WeatherNotificationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var isFixingUsers = false
    @State private var organizationAlertService = OrganizationAlertService()
    
    private var isCreatorAccount: Bool {
        apiService.currentUser?.email == "jed@onetrack-consulting.com"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Custom Settings Title
                    HStack {
                        Text("Settings")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    
                    profileSection
                    biometricSection
                    notificationsSection
                    locationSection
                    alertsSection
                    organizationsSection
                    
                    // Only show admin management for users with admin access
                    if apiService.hasOrganizationAdminAccess() {
                        adminManagementSection
                    }
                    
                    supportSection
                    
                    // Show development section only for creator
                    if isCreatorAccount {
                        developmentSection
                    }
                    
                    // Debug section for push notifications
                    debugSection
                    
                    signOutSection
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                biometricAuthManager.loadBiometricEnabled()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var profileSection: some View {
        SettingsSection(
            title: "Profile",
            icon: "person.circle.fill",
            iconColor: .blue
        ) {
            NavigationLink(destination: EditProfileView()) {
                SettingsRow(
                    icon: "person.fill",
                    title: "Edit Profile",
                    subtitle: "Update your personal information",
                    iconColor: .blue
                )
            }
            
            NavigationLink(destination: ChangePasswordView()) {
                SettingsRow(
                    icon: "lock.fill",
                    title: "Change Password",
                    subtitle: "Update your account password",
                    iconColor: .orange
                )
            }
        }
    }
    
    private var biometricSection: some View {
        SettingsSection(
            title: "Security",
            icon: "lock.shield.fill",
            iconColor: .green
        ) {
            VStack(spacing: 16) {
                // Main biometric toggle
                HStack(spacing: 16) {
                    Image(systemName: biometricAuthManager.biometricIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(biometricAuthManager.biometricTypeName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(biometricAuthManager.statusMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $biometricAuthManager.isBiometricEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .onChange(of: biometricAuthManager.isBiometricEnabled) { _, newValue in
                            biometricAuthManager.saveBiometricEnabled(newValue)
                        }
                }
                
                // Re-enrollment option if needed
                if biometricAuthManager.shouldReEnroll && biometricAuthManager.biometricType != .none {
                    Button(action: {
                        Task {
                            await biometricAuthManager.reEnrollAfterCredentialLogin()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                            Text("Re-enroll \(biometricAuthManager.biometricTypeName)")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                

            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
    }
    
    private var notificationsSection: some View {
        SettingsSection(
            title: "Notifications",
            icon: "bell.fill",
            iconColor: .purple
        ) {
            notificationStatusRow
            notificationPreferencesRow
            quietHoursRow
        }
    }
    
    private var notificationStatusRow: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.circle.fill")
                .font(.title2)
                .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Push Notifications")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(notificationManager.isAuthorized ? "Disable" : "Enable") {
                if notificationManager.isAuthorized {
                    // Handle disabling notifications
                    print("Disabling notifications")
                } else {
                    notificationManager.requestPermissions { granted in
                        print("Notification permissions granted: \(granted)")
                    }
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(notificationManager.isAuthorized ? .red : .blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    

    
    private var notificationPreferencesRow: some View {
        NavigationLink(destination: NotificationPreferencesView()) {
            SettingsRow(
                icon: "bell.badge",
                title: "Notification Preferences",
                subtitle: "Customize your notification settings",
                iconColor: .purple
            )
        }
    }
    
    private var quietHoursRow: some View {
        NavigationLink(destination: QuietHoursSettingsView()) {
            SettingsRow(
                icon: "moon.fill",
                title: "Quiet Hours",
                subtitle: "Set times when you don't want notifications",
                iconColor: .indigo
            )
        }
    }
    
    private var locationSection: some View {
        SettingsSection(
            title: "Location",
            icon: "location.fill",
            iconColor: .green
        ) {
            locationStatusRow
            locationSettingsRow
        }
    }
    
    private var locationStatusRow: some View {
        HStack(spacing: 16) {
            Image(systemName: "location.circle.fill")
                .font(.title2)
                .foregroundColor(locationManager.isLocationEnabled ? .green : .red)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Location Access")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(locationManager.isLocationEnabled ? "Enabled" : "Disabled")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(locationManager.isLocationEnabled ? "Disable" : "Enable") {
                if locationManager.isLocationEnabled {
                    // Handle disabling location
                    print("Disabling location")
                } else {
                    locationManager.requestLocationPermission()
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(locationManager.isLocationEnabled ? .red : .blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var locationSettingsRow: some View {
        NavigationLink(destination: LocationSettingsView()) {
            SettingsRow(
                icon: "mappin.and.ellipse",
                title: "Location Settings",
                subtitle: "Manage your saved locations",
                iconColor: .green
            )
        }
    }
    
    private var alertsSection: some View {
        SettingsSection(
            title: "Alerts",
            icon: "exclamationmark.triangle.fill",
            iconColor: .red
        ) {
            incidentTypesRow
            alertRadiusRow
            criticalAlertsRow
        }
    }
    
    private var incidentTypesRow: some View {
        NavigationLink(destination: IncidentTypeSettingsView()) {
            SettingsRow(
                icon: "exclamationmark.triangle",
                title: "Incident Types",
                subtitle: "Choose which alerts to receive",
                iconColor: .red
            )
        }
    }
    
    private var alertRadiusRow: some View {
        NavigationLink(destination: AlertRadiusSettingsView()) {
            SettingsRow(
                icon: "circle.dashed",
                title: "Alert Radius",
                subtitle: "Set how far to look for incidents",
                iconColor: .orange
            )
        }
    }
    
    private var criticalAlertsRow: some View {
        NavigationLink(destination: CriticalAlertsSettingsView()) {
            SettingsRow(
                icon: "exclamationmark.octagon",
                title: "Critical Alerts",
                subtitle: "Configure emergency notifications",
                iconColor: .red
            )
        }
    }
    
    private var organizationsSection: some View {
        SettingsSection(
            title: "Organizations",
            icon: "building.2.fill",
            iconColor: .blue
        ) {
            followedOrganizationsRow
            discoverOrganizationsRow
        }
    }
    
    private var followedOrganizationsRow: some View {
        NavigationLink(destination: FollowedOrganizationsView()) {
            SettingsRow(
                icon: "heart.fill",
                title: "Followed Organizations",
                subtitle: "Manage your followed organizations",
                iconColor: .red
            )
        }
    }
    
    private var discoverOrganizationsRow: some View {
        NavigationLink(destination: DiscoverOrganizationsView()) {
            SettingsRow(
                icon: "magnifyingglass",
                title: "Discover Organizations",
                subtitle: "Find new organizations to follow",
                iconColor: .blue
            )
        }
    }
    
    private var adminManagementSection: some View {
        SettingsSection(
            title: "Admin Management",
            icon: "person.2.circle.fill",
            iconColor: .purple
        ) {
            if apiService.hasOrganizationAdminAccess() {
                NavigationLink(destination: AdminOrganizationReviewView()) {
                    SettingsRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Review Organization Requests",
                        subtitle: "Approve or deny organization verification requests",
                        iconColor: .orange
                    )
                }
                
                NavigationLink(destination: OrganizationAdminManagementView()) {
                    SettingsRow(
                        icon: "person.badge.plus",
                        title: "Manage Organization Admins",
                        subtitle: "Add or remove organization administrators",
                        iconColor: .purple
                    )
                }
            } else {
                // Debug info for admin access
                VStack(alignment: .leading, spacing: 8) {
                    Text("Admin Access Status")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Current User ID: \(apiService.currentUser?.id ?? "nil")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Organizations: \(apiService.organizations.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !apiService.organizations.isEmpty {
                        ForEach(apiService.organizations.prefix(3), id: \.id) { org in
                            Text("• \(org.name): Admin IDs: \(org.adminIds?.keys.joined(separator: ", ") ?? "none")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button("Check Admin Status") {
                            Task {
                                await checkAdminStatus()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Load Organizations") {
                            Task {
                                await loadOrganizations()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(8)
            }
        }
    }
    
    private var supportSection: some View {
        SettingsSection(
            title: "Support",
            icon: "questionmark.circle.fill",
            iconColor: .blue
        ) {
            aboutRow
            privacyPolicyRow
            termsOfServiceRow
        }
    }
    
    private var aboutRow: some View {
        NavigationLink(destination: AboutView()) {
            SettingsRow(
                icon: "info.circle",
                title: "About",
                subtitle: "App information and version",
                iconColor: .blue
            )
        }
    }
    
    private var privacyPolicyRow: some View {
        NavigationLink(destination: PrivacyPolicyView()) {
            SettingsRow(
                icon: "hand.raised",
                title: "Privacy Policy",
                subtitle: "How we protect your data",
                iconColor: .green
            )
        }
    }
    
    private var termsOfServiceRow: some View {
        NavigationLink(destination: TermsOfServiceView()) {
            SettingsRow(
                icon: "doc.text",
                title: "Terms of Service",
                subtitle: "App usage terms and conditions",
                iconColor: .orange
            )
        }
    }
    
    private var developmentSection: some View {
        SettingsSection(
            title: "Development",
            icon: "hammer.fill",
            iconColor: .orange
        ) {
            VStack(spacing: 0) {
                Button(action: {
                    Task {
                        await fixAllUserDocuments()
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fix All User Documents")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Add missing fields to all users")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isFixingUsers {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isFixingUsers)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    notificationManager.debugFCMTokenStatus()
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debug FCM Token")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Check push notification status")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    notificationManager.retryFCMTokenRegistration()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Retry FCM Registration")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Re-register push notification token")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    notificationManager.testFCMTokenRegistration()
                }) {
                    HStack {
                        Image(systemName: "wifi")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test FCM Token")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Test FCM token registration")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    notificationManager.testLocalNotification()
                }) {
                    HStack {
                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test Local Notification")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Send test notification in 2 seconds")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    self.debugFollowStatus()
                }) {
                    HStack {
                        Image(systemName: "person.2")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debug Follow Status")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Check follow status for all organizations")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    debugOrganizationRequests()
                }) {
                    HStack {
                        Image(systemName: "building.2")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debug Organization Requests")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Check organization requests in Firestore")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await createTestAlert()
                    }
                }) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Test Alert")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Send test push notification")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await apiService.updateOrganizationCoordinates()
                    }
                }) {
                    HStack {
                        Image(systemName: "location.badge.questionmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fix Organization Coordinates")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Update org locations using real geocoding")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await setupCurrentUserAsAdmin()
                    }
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Admin to Specific Org")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Add current user as admin to one organization (use console to see org IDs)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await cleanInvalidAdminIds()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clean Invalid Admin IDs")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Remove invalid admin IDs from all organizations")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await fixUserAuthentication()
                    }
                }) {
                    HStack {
                        Image(systemName: "person.badge.minus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fix User Authentication")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Sync APIService user with Firebase Auth user")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await fixSpecificUser()
                    }
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fix Test User Document")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Fix jedidiahcrisp@gmail.com document")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isFixingUsers {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isFixingUsers)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await fixOrganizationAdminAccess()
                    }
                }) {
                    HStack {
                        Image(systemName: "building.2.badge.gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fix Test Organization Admin")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Link user to Test organization as admin")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if isFixingUsers {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isFixingUsers)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // MARK: - FCM Testing Tools
                Button(action: {
                    Task {
                        await testFCMPushNotifications()
                    }
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test FCM Push Notifications")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Test push notifications and diagnose FCM issues")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await debugFCMStatus()
                    }
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debug FCM Status")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Check FCM token status and configuration")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        do {
                            try await apiService.forceRefreshFCMToken()
                        } catch {
                            print("❌ Failed to refresh FCM token: \(error)")
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Force Refresh FCM Token")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Generate new FCM token and re-register")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await validateAndRegisterFCMToken()
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Validate & Register FCM Token")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Ensure FCM token is properly registered in Firestore")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await debugGlobalFCMTokens()
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debug Global FCM Tokens")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Check FCM token status for all users globally")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal, 20)
                
                Button(action: {
                    Task {
                        await checkDuplicateFCMTokens()
                    }
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check for Duplicate FCM Tokens")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Find users with duplicate tokens")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Button(action: {
                    Task {
                        await cleanupDuplicateFCMTokens()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clean Up Duplicate FCM Tokens")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Remove duplicate tokens to fix notifications")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // Debug Follow Button Test
                Button(action: {
                    Task {
                        await testFollowFunctionality()
                    }
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test Follow Functionality")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Debug follow/unfollow system")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                        Button(action: {
                            Task {
                                await checkAndRestoreAuthState()
                            }
                        }) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.green)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Check & Restore Auth State")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Check Firebase Auth and restore user state")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        
                        Button(action: {
                            Task {
                                await syncUserFromAPIService()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.purple)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sync User from APIService")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Fix user ID mismatch by syncing from APIService")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        
                        Button(action: {
                            Task {
                                await fixExistingOrganizationAdminIds()
                            }
                        }) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.orange)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fix Organization Admin IDs")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Fix permission issues with approved organizations")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                

            }
        }
    }
    
    private var debugSection: some View {
        SettingsSection(
            title: "Debug",
            icon: "wrench.and.screwdriver.fill",
            iconColor: .gray
        ) {
            Button(action: {
                notificationManager.debugPushNotificationSystem()
            }) {
                SettingsRow(
                    icon: "magnifyingglass",
                    title: "Debug Push Notifications",
                    subtitle: "Check FCM token and notification status",
                    iconColor: .blue
                )
            }
            
            Button(action: {
                Task {
                    do {
                        try await apiService.forceRefreshFCMToken()
                    } catch {
                        print("❌ Failed to refresh FCM token: \(error)")
                    }
                }
            }) {
                SettingsRow(
                    icon: "arrow.clockwise",
                    title: "Refresh FCM Token",
                    subtitle: "Force refresh Firebase Cloud Messaging token",
                    iconColor: .orange
                )
            }
            
            Button(action: {
                Task {
                    await notificationManager.checkFollowingStatus()
                }
            }) {
                SettingsRow(
                    icon: "person.2.fill",
                    title: "Check Following Status",
                    subtitle: "See which organizations you follow",
                    iconColor: .purple
                )
            }
            
            Button(action: {
                notificationManager.testNotification()
            }) {
                SettingsRow(
                    icon: "bell.badge",
                    title: "Test Notification",
                    subtitle: "Send a test push notification",
                    iconColor: .green
                )
            }
        }
    }
    
    private var signOutSection: some View {
        SettingsSection(
            title: "Account",
            icon: "person.crop.circle.fill",
            iconColor: .red
        ) {
            Button(action: {
                showingSignOutAlert = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                        
                        Text("Sign out of your account")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func fixUserAuthentication() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Fixing User Authentication"
            alertMessage = "Syncing user data with Firebase Auth..."
            showingAlert = true
        }
        
        do {
            try await apiService.fixUserAuthenticationMismatch()
            
            await MainActor.run {
                alertTitle = "Authentication Fixed"
                alertMessage = "User data has been synced with Firebase Auth. Admin checks should now work correctly."
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Fix Failed"
                alertMessage = "Failed to fix authentication: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func checkAdminStatus() async {
        print("🔍 Checking admin status...")
        print("📱 Current user ID: \(apiService.currentUser?.id ?? "nil")")
        print("📱 Current user email: \(apiService.currentUser?.email ?? "nil")")
        print("🏢 Organizations count: \(apiService.organizations.count)")
        
        for (index, org) in apiService.organizations.enumerated() {
            print("🏢 Organization \(index + 1): \(org.name)")
            print("   ID: \(org.id)")
            print("   Admin IDs: \(org.adminIds?.keys.joined(separator: ", ") ?? "none")")
            
            let isAdmin = await apiService.isAdminOfOrganization(org.id)
            print("   Is current user admin: \(isAdmin)")
        }
        
        let hasAccess = apiService.hasOrganizationAdminAccess()
        print("✅ Has organization admin access: \(hasAccess)")
    }
    
    private func loadOrganizations() async {
        print("🔄 Manual organization load requested...")
        await apiService.loadOrganizations()
        print("✅ Manual organization load completed")
    }
    
    private func cleanInvalidAdminIds() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Cleaning Admin IDs"
            alertMessage = "Removing invalid admin IDs from organizations..."
            showingAlert = true
        }
        
        do {
            try await apiService.cleanInvalidAdminIds()
            
            await MainActor.run {
                alertTitle = "Cleanup Complete"
                alertMessage = "Invalid admin IDs have been removed. Check console for details."
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Cleanup Failed"
                alertMessage = "Failed to clean admin IDs: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func setupCurrentUserAsAdmin() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Listing Organizations"
            alertMessage = "Check console for organization IDs and admin status..."
            showingAlert = true
        }
        
        do {
            try await apiService.setupCurrentUserAsAdminForSpecificOrg()
            
            await MainActor.run {
                alertTitle = "Organizations Listed"
                alertMessage = "Check the console for organization IDs. You need to manually add your user ID to specific organization adminIds in Firestore."
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Failed to List Organizations"
                alertMessage = "Failed to list organizations: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func fixAllUserDocuments() async {
        isFixingUsers = true
        do {
            try await apiService.fixAllExistingUserDocuments()
            await MainActor.run {
                alertTitle = "Success"
                alertMessage = "All user documents have been fixed!"
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Error"
                alertMessage = "Failed to fix user documents: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func fixSpecificUser() async {
        isFixingUsers = true
        do {
            try await apiService.fixSpecificUserDocument(email: "jedidiahcrisp@gmail.com")
            await MainActor.run {
                alertTitle = "Success"
                alertMessage = "User document for jedidiahcrisp@gmail.com has been fixed!"
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Error"
                alertMessage = "Failed to fix user document: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func fixOrganizationAdminAccess() async {
        isFixingUsers = true
        do {
            try await apiService.fixOrganizationAdminAccess(email: "jedidiahcrisp@gmail.com", organizationName: "Test")
            await MainActor.run {
                alertTitle = "Success"
                alertMessage = "Organization admin access has been fixed! User is now admin of Test organization."
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Error"
                alertMessage = "Failed to fix organization admin access: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func testFCMPushNotifications() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Testing FCM Push Notifications"
            alertMessage = "Attempting to send a test push notification..."
            showingAlert = true
        }
        
        do {
            try await apiService.sendTestPushNotification()
            await MainActor.run {
                alertTitle = "Test Push Sent"
                alertMessage = "Test push notification has been sent. Check your device for the notification."
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Test Push Failed"
                alertMessage = "Failed to send test push notification: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func debugFCMStatus() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Debugging FCM Status"
            alertMessage = "Checking FCM token and configuration..."
            showingAlert = true
        }
        
        do {
            let token = try await apiService.getFCMToken()
            let isRegistered = try await apiService.isFCMTokenRegistered()
            
            await MainActor.run {
                alertTitle = "FCM Status"
                alertMessage = """
                    FCM Token: \(token)
                    Is Registered: \(isRegistered)
                    """
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Debug Failed"
                alertMessage = "Failed to debug FCM status: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func forceRefreshFCMToken() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Refreshing FCM Token"
            alertMessage = "Attempting to force refresh FCM token and re-register..."
            showingAlert = true
        }
        
        do {
            try await apiService.forceRefreshFCMToken()
            await MainActor.run {
                alertTitle = "FCM Token Refreshed"
                alertMessage = "FCM token has been refreshed and re-registered. You may need to sign out and sign back in for the new token to take effect."
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Refresh Failed"
                alertMessage = "Failed to refresh FCM token: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func validateAndRegisterFCMToken() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Validating & Registering FCM Token"
            alertMessage = "Attempting to validate and register FCM token in Firestore..."
            showingAlert = true
        }
        
        do {
            try await apiService.validateAndRegisterFCMToken()
            await MainActor.run {
                alertTitle = "FCM Token Validated"
                alertMessage = "FCM token has been validated and registered in Firestore."
                showingAlert = true
                isFixingUsers = false
            }
        } catch {
            await MainActor.run {
                alertTitle = "Validation Failed"
                alertMessage = "Failed to validate or register FCM token: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func debugGlobalFCMTokens() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Debugging Global FCM Tokens"
            alertMessage = "Checking FCM token status for all users globally..."
            showingAlert = true
        }
        
        do {
            let globalStatus = await notificationService.debugGlobalFCMTokens()
            
            if let success = globalStatus["success"] as? Bool, success {
                if let userStats = globalStatus["userStats"] as? [String: Any] {
                    let totalUsers = userStats["totalUsers"] as? Int ?? 0
                    let usersWithTokens = userStats["usersWithTokens"] as? Int ?? 0
                    let validTokens = userStats["validTokens"] as? Int ?? 0
                    let invalidTokens = userStats["invalidTokens"] as? Int ?? 0
                    
                    let statusMessage = """
                        Global FCM Token Status:
                        
                        Total Users: \(totalUsers)
                        Users with FCM Tokens: \(usersWithTokens)
                        Valid Tokens: \(validTokens)
                        Invalid Tokens: \(invalidTokens)
                        Users without Tokens: \(totalUsers - usersWithTokens)
                        
                        Check console for detailed breakdown.
                        """
                    
                    await MainActor.run {
                        alertTitle = "Global FCM Token Status"
                        alertMessage = statusMessage
                        showingAlert = true
                        isFixingUsers = false
                    }
                }
            } else {
                let errorMessage = globalStatus["error"] as? String ?? "Unknown error"
                await MainActor.run {
                    alertTitle = "Debug Failed"
                    alertMessage = "Failed to debug global FCM tokens: \(errorMessage)"
                    showingAlert = true
                    isFixingUsers = false
                }
            }
        } catch {
            await MainActor.run {
                alertTitle = "Debug Failed"
                alertMessage = "Failed to debug global FCM tokens: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }

    // MARK: - Duplicate FCM Token Management
    private func checkDuplicateFCMTokens() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Checking for Duplicate FCM Tokens"
            alertMessage = "Scanning database for duplicate FCM tokens..."
            showingAlert = true
        }
        
        do {
            let duplicateStatus = await notificationService.checkForDuplicateFCMTokens()
            
            if let totalUsers = duplicateStatus["totalUsers"] as? Int,
               let usersWithTokens = duplicateStatus["usersWithTokens"] as? Int,
               let uniqueTokens = duplicateStatus["uniqueTokens"] as? Int,
               let duplicateTokens = duplicateStatus["duplicateTokens"] as? Int {
                
                await MainActor.run {
                    alertTitle = "Duplicate FCM Token Scan Complete"
                    alertMessage = """
                    Database Scan Results:
                    
                    Total Users: \(totalUsers)
                    Users with FCM Tokens: \(usersWithTokens)
                    Unique FCM Tokens: \(uniqueTokens)
                    Duplicate FCM Tokens: \(duplicateTokens)
                    
                    \(duplicateTokens > 0 ? "⚠️ Duplicate tokens found! Use 'Clean Up' to remove them." : "✅ No duplicate tokens found.")
                    """
                    showingAlert = true
                    isFixingUsers = false
                }
            } else {
                await MainActor.run {
                    alertTitle = "Scan Error"
                    alertMessage = "Failed to parse scan results"
                    showingAlert = true
                    isFixingUsers = false
                }
            }
        } catch {
            await MainActor.run {
                alertTitle = "Scan Failed"
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    private func cleanupDuplicateFCMTokens() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Cleaning Up Duplicate FCM Tokens"
            alertMessage = "Removing duplicate FCM tokens from database..."
            showingAlert = true
        }
        
        do {
            let cleanupStatus = await notificationService.cleanUpDuplicateFCMTokens()
            
            if let success = cleanupStatus["success"] as? Bool, success {
                let removedCount = cleanupStatus["removedCount"] as? Int ?? 0
                await MainActor.run {
                    alertTitle = "Cleanup Complete"
                    alertMessage = "Successfully removed \(removedCount) duplicate FCM tokens from database."
                    showingAlert = true
                    isFixingUsers = false
                }
            } else {
                let errorMessage = cleanupStatus["errorMessage"] as? String ?? "Unknown error"
                await MainActor.run {
                    alertTitle = "Cleanup Failed"
                    alertMessage = "Error: \(errorMessage)"
                    showingAlert = true
                    isFixingUsers = false
                }
            }
        } catch {
            await MainActor.run {
                alertTitle = "Cleanup Failed"
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
                isFixingUsers = false
            }
        }
    }
    
    // MARK: - Follow Functionality Test
    private func testFollowFunctionality() async {
        await MainActor.run {
            alertTitle = "Testing Follow Functionality"
            alertMessage = "Checking ServiceCoordinator and follow system..."
            showingAlert = true
        }
        
        do {
            // Test if currentUser is set
            guard let currentUser = serviceCoordinator.currentUser else {
                await MainActor.run {
                    alertTitle = "Test Failed - No Current User"
                    alertMessage = "Current user is nil - user may not be authenticated. Please check if you're signed in."
                    showingAlert = true
                }
                return
            }
            
            // Test if followingService is available
            _ = serviceCoordinator.followingService
            
            // Test if we can access the user ID
            let userId = currentUser.id
            let userName = currentUser.name ?? "Unknown"
            
            await MainActor.run {
                alertTitle = "Test Successful"
                alertMessage = "ServiceCoordinator is working correctly!\n\nUser ID: \(userId)\nUser Name: \(userName)\nFollowing Service: Available"
                showingAlert = true
            }
            
        } catch {
            await MainActor.run {
                alertTitle = "Test Failed - Error"
                alertMessage = "Error occurred: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    // MARK: - Authentication State Check
    private func checkAndRestoreAuthState() async {
        await MainActor.run {
            alertTitle = "Checking Authentication State"
            alertMessage = "Checking Firebase Auth and restoring user state..."
            showingAlert = true
        }
        
        // Call the ServiceCoordinator method to check and restore auth state
        serviceCoordinator.checkAndRestoreAuthenticationState()
        
        // Wait a moment for the async operations to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            if let currentUser = serviceCoordinator.currentUser {
                alertTitle = "Authentication State Restored"
                alertMessage = "✅ User is now authenticated!\n\nUser ID: \(currentUser.id)\nUser Name: \(currentUser.name ?? "Unknown")\nEmail: \(currentUser.email ?? "Unknown")"
            } else {
                alertTitle = "No Authenticated User"
                alertMessage = "❌ No user is currently authenticated.\n\nPlease sign in to use the follow functionality."
            }
            showingAlert = true
        }
    }
    
    // MARK: - Sync User from APIService
    private func syncUserFromAPIService() async {
        await MainActor.run {
            alertTitle = "Syncing User from APIService"
            alertMessage = "Attempting to sync current user from APIService to resolve user ID mismatch..."
            showingAlert = true
        }

        // Call the ServiceCoordinator method to sync user from APIService
        serviceCoordinator.syncUserFromAPIService()

        // Wait a moment for the async operations to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        await MainActor.run {
            if let currentUser = serviceCoordinator.currentUser {
                alertTitle = "User Synced Successfully"
                alertMessage = "✅ User ID mismatch resolved!\n\nUser ID: \(currentUser.id)\nUser Name: \(currentUser.name ?? "Unknown")\nEmail: \(currentUser.email ?? "Unknown")\n\nFollow buttons should now work correctly."
            } else {
                alertTitle = "Sync Failed"
                alertMessage = "❌ Failed to sync user from APIService.\n\nUser may not be authenticated in APIService."
            }
            showingAlert = true
        }
    }
    
    // MARK: - Fix Existing Organization Admin IDs
    private func fixExistingOrganizationAdminIds() async {
        await MainActor.run {
            alertTitle = "Fixing Organization Admin IDs"
            alertMessage = "Attempting to fix permission issues with approved organizations..."
            showingAlert = true
        }

        do {
            try await serviceCoordinator.fixExistingOrganizationAdminIds()
            
            await MainActor.run {
                alertTitle = "Organization Admin IDs Fixed"
                alertMessage = "✅ Successfully fixed organization permission issues!\n\nNewly approved organization admins should now be able to:\n• View their organization profile\n• Edit organization details\n• Add groups\n• Post alerts\n\nPlease try accessing your organization features again."
                showingAlert = true
            }
        } catch {
            await MainActor.run {
                alertTitle = "Fix Failed"
                alertMessage = "❌ Failed to fix organization admin IDs: \(error.localizedDescription)\n\nPlease contact support if the issue persists."
                showingAlert = true
            }
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await apiService.signOut()
                // Handle successful sign out (e.g., navigate to auth view)
                print("Successfully signed out")
            } catch {
                print("Sign out failed: \(error)")
            }
        }
    }
    
    private func createTestAlert() async {
        guard let currentUser = apiService.currentUser else {
            print("❌ No current user for test alert")
            return
        }
        
        // Get the first organization the user has access to
        guard let organization = apiService.organizations.first else {
            print("❌ No organizations available for test alert")
            return
        }
        
        do {
            try await organizationAlertService.createTestAlert(
                organizationId: organization.id,
                organizationName: organization.name
            )
            print("✅ Test alert created successfully")
        } catch {
            print("❌ Failed to create test alert: \(error)")
        }
    }
    
    private func debugFollowStatus() {
        print("🔍 Debug Follow Status:")
        print("   FollowStatusManager shared instance: \(FollowStatusManager.shared)")
        print("   Current follow status changes: \(FollowStatusManager.shared.followStatusChanges)")
        
        // Check a specific organization if we have one
        if let firstOrg = apiService.organizations.first {
            let followStatus = FollowStatusManager.shared.getFollowStatus(for: firstOrg.id)
            print("   Follow status for '\(firstOrg.name)': \(followStatus?.description ?? "nil")")
        }
        
        // Check if user is following any organizations
        Task {
            do {
                guard let userId = apiService.currentUser?.id else {
                    print("   No current user ID available")
                    return
                }
                let followedOrgs = try await serviceCoordinator.getFollowedOrganizations(userId: userId)
                print("   Followed organizations count: \(followedOrgs.count)")
                for org in followedOrgs {
                    print("   - Following: \(org.name) (ID: \(org.id))")
                }
            } catch {
                print("   Error getting followed organizations: \(error)")
            }
        }
    }
    
    private func debugOrganizationRequests() {
        print("🔍 Debug Organization Requests:")
        
        Task {
            do {
                let db = Firestore.firestore()
                
                // Get all organization requests
                let snapshot = try await db.collection("organizationRequests").getDocuments()
                print("📊 Total organization requests in Firestore: \(snapshot.documents.count)")
                
                // Debug: Print all requests and their details
                for (index, doc) in snapshot.documents.enumerated() {
                    let data = doc.data()
                    let status = data["status"] as? String ?? "nil"
                    let name = data["name"] as? String ?? data["organizationName"] as? String ?? "Unknown"
                    let id = data["id"] as? String ?? doc.documentID
                    let submittedAt = data["submittedAt"] as? Timestamp
                    let createdAt = data["createdAt"] as? Timestamp
                    
                    print("📄 Request \(index + 1):")
                    print("   - Document ID: \(doc.documentID)")
                    print("   - Request ID: \(id)")
                    print("   - Name: \(name)")
                    print("   - Status: \(status)")
                    print("   - Submitted At: \(submittedAt?.dateValue() ?? Date())")
                    print("   - Created At: \(createdAt?.dateValue() ?? Date())")
                    print("   - Admin Email: \(data["adminEmail"] as? String ?? "nil")")
                    print("   - Organization Type: \(data["type"] as? String ?? data["organizationType"] as? String ?? "nil")")
                    print("   ---")
                }
                
                // Try to fetch using the iOS app's method
                print("🔄 Testing iOS app's fetchOrganizationRequests method...")
                let requests = try await apiService.getPendingOrganizationRequests()
                print("📱 iOS app found \(requests.count) pending requests")
                
                for request in requests {
                    print("📱 iOS Request: \(request.name) (Status: \(request.status.rawValue))")
                }
                
            } catch {
                print("❌ Error debugging organization requests: \(error)")
            }
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            
            // Section Content
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIService())
        .environmentObject(LocationManager())
        .environmentObject(NotificationManager())
        .environmentObject(BiometricAuthManager())
}

// MARK: - Organization Admin Management View
struct OrganizationAdminManagementView: View {
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var emailToAdd = ""
    @State private var selectedOrganization: Organization?
    @State private var showingAddAdminSheet = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var currentAdmins: [String] = []
    @State private var adminUsers: [String: User] = [:]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Organization Selection
                if let selectedOrg = selectedOrganization {
                    organizationInfoCard(selectedOrg)
                } else {
                    organizationSelectionCard
                }
                
                // Current Admins List
                if let selectedOrg = selectedOrganization {
                    currentAdminsCard(selectedOrg)
                }
                
                // Add Admin Button
                if selectedOrganization != nil {
                    addAdminButton
                }
            }
            .padding()
        }
        .navigationTitle("Admin Management")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadUserOrganizations()
        }
        .sheet(isPresented: $showingAddAdminSheet) {
            AddAdminSheet(
                emailToAdd: $emailToAdd,
                selectedOrganization: selectedOrganization,
                onAdminAdded: { success, message in
                    if success {
                        alertTitle = "Success"
                        alertMessage = message
                        showingAlert = true
                        // Refresh admin list
                        if let org = selectedOrganization {
                            loadCurrentAdmins(for: org)
                        }
                    } else {
                        alertTitle = "Error"
                        alertMessage = message
                        showingAlert = true
                    }
                }
            )
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var organizationSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Organization")
                .font(.headline)
                .foregroundColor(.primary)
            
            if apiService.organizations.isEmpty {
                Text("No organizations found")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(apiService.organizations.filter { org in
                    org.adminIds?[apiService.currentUser?.id ?? ""] == true
                }) { org in
                    Button(action: {
                        selectedOrganization = org
                        loadCurrentAdmins(for: org)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(org.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(org.type.capitalized)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    private func organizationInfoCard(_ org: Organization) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(org.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(org.type.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Change") {
                    selectedOrganization = nil
                }
                .buttonStyle(.bordered)
            }
            
            if let email = org.email {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                    Text(email)
                        .font(.subheadline)
                }
            }
            
            if let address = org.address, let city = org.city, let state = org.state {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.green)
                    Text("\(address), \(city), \(state)")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func currentAdminsCard(_ org: Organization) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Administrators")
                .font(.headline)
                .foregroundColor(.primary)
            
            if currentAdmins.count > 0 {
                Text("You cannot remove yourself as an administrator")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            if currentAdmins.isEmpty {
                Text("Loading admins...")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(currentAdmins, id: \.self) { adminId in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if let user = adminUsers[adminId] {
                                Text(user.name ?? user.email ?? "Unknown User")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(user.email ?? "No email")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Loading...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(adminId)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if currentAdmins.count > 1 {
                            Button("Remove") {
                                removeAdmin(adminId, from: org)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.red)
                            .disabled(adminId == apiService.currentUser?.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var addAdminButton: some View {
        Button(action: {
            showingAddAdminSheet = true
        }) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 18, weight: .medium))
                
                Text("Add New Administrator")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func loadUserOrganizations() {
        // Organizations are already loaded in APIService
        print("📋 Loaded \(apiService.organizations.count) organizations")
    }
    
    private func loadCurrentAdmins(for org: Organization) {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                let adminIds = org.adminIds ?? [:]
                let adminList = Array(adminIds.keys.filter { adminIds[$0] == true })
                
                await MainActor.run {
                    currentAdmins = adminList
                    isLoading = false
                    print("👥 Loaded \(adminList.count) admins for \(org.name)")
                }
                
                // Load user details for each admin
                var userDetails: [String: User] = [:]
                for adminId in adminList {
                    if let user = try await apiService.getUserById(adminId) {
                        userDetails[adminId] = user
                    }
                }
                
                await MainActor.run {
                    adminUsers = userDetails
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertTitle = "Error"
                    alertMessage = "Failed to load current admins: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func removeAdmin(_ adminId: String, from org: Organization) {
        Task {
            do {
                try await apiService.removeOrganizationAdmin(adminId, from: org.id)
                
                await MainActor.run {
                    alertTitle = "Success"
                    alertMessage = "Administrator removed successfully"
                    showingAlert = true
                    // Refresh admin list
                    loadCurrentAdmins(for: org)
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = "Failed to remove administrator: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Add Admin Sheet
struct AddAdminSheet: View {
    @Binding var emailToAdd: String
    let selectedOrganization: Organization?
    let onAdminAdded: (Bool, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    
    @State private var isLoading = false
    @State private var searchResults: [User] = []
    @State private var showingSearchResults = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Add Organization Administrator")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let org = selectedOrganization {
                        Text("Adding admin to: \(org.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("User Email")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Enter user's email address", text: $emailToAdd)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: emailToAdd) { _ in
                                showingSearchResults = false
                                searchResults = []
                            }
                        
                        Button(action: {
                            searchUserByEmail()
                        }) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Text("Search")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(emailToAdd.isEmpty || isLoading)
                    }
                }
                
                // Search Results
                if showingSearchResults {
                    searchResultsView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Administrator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Results")
                .font(.headline)
                .foregroundColor(.primary)
            
            if searchResults.isEmpty {
                Text("No users found with that email address")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(searchResults) { user in
                    userResultRow(user)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    private func userResultRow(_ user: User) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name ?? user.email ?? "Unknown User")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(user.email ?? "No email")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Add as Admin") {
                addUserAsAdmin(user)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isLoading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func searchUserByEmail() {
        guard !emailToAdd.isEmpty, let org = selectedOrganization else { return }
        
        isLoading = true
        showingSearchResults = false
        
        Task {
            do {
                let users = try await apiService.findUsersByEmail(emailToAdd)
                
                await MainActor.run {
                    searchResults = users
                    showingSearchResults = true
                    isLoading = false
                    
                    if users.isEmpty {
                        onAdminAdded(false, "No users found with email: \(emailToAdd)")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    onAdminAdded(false, "Search failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    private func addUserAsAdmin(_ user: User) {
        guard let org = selectedOrganization else { return }
        
        // Check if user is already an admin
        let isAlreadyAdmin = org.adminIds?[user.id] == true
        if isAlreadyAdmin {
            onAdminAdded(false, "\(user.name ?? user.email ?? "User") is already an administrator")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await apiService.addOrganizationAdmin(user.id, to: org.id)
                
                await MainActor.run {
                    isLoading = false
                    onAdminAdded(true, "\(user.name ?? user.email ?? "User") added as administrator successfully")
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    onAdminAdded(false, "Failed to add administrator: \(error.localizedDescription)")
                }
            }
        }
    }
} 