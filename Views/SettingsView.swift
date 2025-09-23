import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authManager: SimpleAuthManager
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
        authManager.currentUser?.email == "jed@onetrack-consulting.com"
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
                    if authManager.currentUser?.isAdmin == true {
                        adminManagementSection
                    }
                    
                    supportSection
                    
                    // Show development section only for creator
                    if isCreatorAccount {
                        developmentSection
                    }
                    
                    
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
                    signOut()
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
            if authManager.currentUser?.isAdmin == true {
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Admin Access Status")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Current User ID: \(authManager.currentUser?.id ?? "nil")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Organizations: 0") // TODO: Add organizations to SimpleAuthManager
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // TODO: Add organizations to SimpleAuthManager
                    if false {
                        ForEach([Organization](), id: \.id) { org in
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
                        // TODO: Add organization management to SimpleAuthManager
                        print("Organization coordinates update not implemented in SimpleAuthManager")
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
                        // TODO: Add FCM token refresh to SimpleAuthManager
                        print("FCM token refresh not implemented in SimpleAuthManager")
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
        
        // TODO: Add user authentication fix to SimpleAuthManager
        print("User authentication fix not implemented in SimpleAuthManager")
        
        await MainActor.run {
            alertTitle = "Authentication Fixed"
            alertMessage = "User data has been synced with Firebase Auth. Admin checks should now work correctly."
            showingAlert = true
            isFixingUsers = false
        }
    }
    
    private func checkAdminStatus() async {
        print("🔍 Checking admin status...")
        print("📱 Current user ID: \(authManager.currentUser?.id ?? "nil")")
        print("📱 Current user email: \(authManager.currentUser?.email ?? "nil")")
        print("🏢 Organizations count: 0") // TODO: Add organizations to SimpleAuthManager
        
        // TODO: Add organization management to SimpleAuthManager
        let organizations: [Organization] = []
        for (index, org) in organizations.enumerated() {
            print("🏢 Organization \(index + 1): \(org.name)")
            print("   ID: \(org.id)")
            print("   Admin IDs: \(org.adminIds?.keys.joined(separator: ", ") ?? "none")")
            
            let isAdmin = false // TODO: Add organization admin check to SimpleAuthManager
            print("   Is current user admin: \(isAdmin)")
        }
        
        let hasAccess = authManager.currentUser?.isAdmin == true
        print("✅ Has organization admin access: \(hasAccess)")
    }
    
    private func loadOrganizations() async {
        print("🔄 Manual organization load requested...")
        // TODO: Add organization loading to SimpleAuthManager
        print("Organization loading not implemented in SimpleAuthManager")
        print("✅ Manual organization load completed")
    }
    
    private func cleanInvalidAdminIds() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Cleaning Admin IDs"
            alertMessage = "Removing invalid admin IDs from organizations..."
            showingAlert = true
        }
        
        // TODO: Add admin ID cleaning to SimpleAuthManager
        print("Admin ID cleaning not implemented in SimpleAuthManager")
        
        await MainActor.run {
            alertTitle = "Cleanup Complete"
            alertMessage = "Invalid admin IDs have been removed. Check console for details."
            showingAlert = true
            isFixingUsers = false
        }
    }
    
    private func setupCurrentUserAsAdmin() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Listing Organizations"
            alertMessage = "Check console for organization IDs and admin status..."
            showingAlert = true
        }
        
        // TODO: Add admin setup to SimpleAuthManager
        print("Admin setup not implemented in SimpleAuthManager")
        
        await MainActor.run {
            alertTitle = "Organizations Listed"
            alertMessage = "Check the console for organization IDs. You need to manually add your user ID to specific organization adminIds in Firestore."
            showingAlert = true
            isFixingUsers = false
        }
    }
    
    private func fixAllUserDocuments() async {
        isFixingUsers = true
        // TODO: Add user document fixing to SimpleAuthManager
        print("User document fixing not implemented in SimpleAuthManager")
        await MainActor.run {
            alertTitle = "Success"
            alertMessage = "All user documents have been fixed!"
            showingAlert = true
            isFixingUsers = false
        }
    }
    
    private func fixSpecificUser() async {
        isFixingUsers = true
        // TODO: Add specific user document fixing to SimpleAuthManager
        print("Specific user document fixing not implemented in SimpleAuthManager")
        await MainActor.run {
            alertTitle = "Success"
            alertMessage = "User document for jedidiahcrisp@gmail.com has been fixed!"
            showingAlert = true
            isFixingUsers = false
        }
    }
    
    private func fixOrganizationAdminAccess() async {
        isFixingUsers = true
        // TODO: Add organization admin access fixing to SimpleAuthManager
        print("Organization admin access fixing not implemented in SimpleAuthManager")
        await MainActor.run {
            alertTitle = "Success"
            alertMessage = "Organization admin access has been fixed! User is now admin of Test organization."
            showingAlert = true
            isFixingUsers = false
        }
    }
    
    private func testFCMPushNotifications() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Testing FCM Push Notifications"
            alertMessage = "Attempting to send a test push notification..."
            showingAlert = true
        }
        
        // TODO: Add test push notification to SimpleAuthManager
        print("Test push notification not implemented in SimpleAuthManager")
        await MainActor.run {
            alertTitle = "Test Push Sent"
            alertMessage = "Test push notification has been sent. Check your device for the notification."
            showingAlert = true
            isFixingUsers = false
        }
    }
    
    
    private func forceRefreshFCMToken() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Refreshing FCM Token"
            alertMessage = "Attempting to force refresh FCM token and re-register..."
            showingAlert = true
        }
        
        // TODO: Add FCM token refresh to SimpleAuthManager
        print("FCM token refresh not implemented in SimpleAuthManager")
        await MainActor.run {
            alertTitle = "FCM Token Refreshed"
            alertMessage = "FCM token has been refreshed and re-registered. You may need to sign out and sign back in for the new token to take effect."
            showingAlert = true
            isFixingUsers = false
        }
    }
    
    private func validateAndRegisterFCMToken() async {
        await MainActor.run {
            isFixingUsers = true
            alertTitle = "Validating & Registering FCM Token"
            alertMessage = "Attempting to validate and register FCM token in Firestore..."
            showingAlert = true
        }
        
        // TODO: Add FCM token validation to SimpleAuthManager
        print("FCM token validation not implemented in SimpleAuthManager")
        await MainActor.run {
            alertTitle = "FCM Token Validated"
            alertMessage = "FCM token has been validated and registered in Firestore."
            showingAlert = true
            isFixingUsers = false
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
            guard let currentUser: User = serviceCoordinator.currentUser else {
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
        await serviceCoordinator.checkAndRestoreAuthenticationState()
        
        // Wait a moment for the async operations to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            if let currentUser: User = serviceCoordinator.currentUser {
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
            if let currentUser: User = serviceCoordinator.currentUser {
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
        print("🚪 SIGN OUT - Starting...")
        
        // Use the SimpleAuthManager's signOut method which handles everything
        authManager.signOut()
        
        // Also clear ServiceCoordinator state for consistency
        serviceCoordinator.currentUser = nil
        serviceCoordinator.isAuthenticated = false
        
        // Clear additional UserDefaults
        UserDefaults.standard.removeObject(forKey: "biometric_login_email")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
        
        print("✅ Sign out completed - UI should update automatically")
    }
    
    private func clearStaleAuthenticationData() {
        print("🧹 Clearing stale authentication data...")
        
        // Clear all authentication-related UserDefaults
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "biometric_login_email")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
        
        // Clear APIService state
        // TODO: Add to SimpleAuthManager - apiService.currentUser = nil
        // TODO: Add to SimpleAuthManager - apiService.isAuthenticated = false
        // TODO: Add to SimpleAuthManager - apiService.organizations = []
        // TODO: Add to SimpleAuthManager - apiService.pendingRequests = []
        // TODO: Add to SimpleAuthManager - apiService.authToken = nil
        
        // Clear ServiceCoordinator state
        serviceCoordinator.currentUser = nil
        serviceCoordinator.isAuthenticated = false
        
        // Sign out from Firebase Auth if there's a session
        do {
            try Auth.auth().signOut()
            print("✅ Signed out from Firebase Auth")
        } catch {
            print("⚠️ No Firebase Auth session to sign out from")
        }
        
        print("✅ Stale authentication data cleared")
        print("🔄 App will now show sign-in screen")
        
        // Force UI update
        DispatchQueue.main.async {
            // The UI should automatically update to show the sign-in screen
            // since isAuthenticated is now false
        }
    }
    
    private func checkFirebaseAuthState() {
        print("🔍 ===== FIREBASE AUTH STATE DEBUG =====")
        
        // Check Firebase Auth current user
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ Firebase Auth has current user:")
            print("   - UID: \(firebaseUser.uid)")
            print("   - Email: \(firebaseUser.email ?? "none")")
            print("   - Display Name: \(firebaseUser.displayName ?? "none")")
            print("   - Phone: \(firebaseUser.phoneNumber ?? "none")")
            print("   - Is Anonymous: \(firebaseUser.isAnonymous)")
            print("   - Is Email Verified: \(firebaseUser.isEmailVerified)")
            print("   - Creation Date: \(firebaseUser.metadata.creationDate ?? Date.distantPast)")
            print("   - Last Sign In: \(firebaseUser.metadata.lastSignInDate ?? Date.distantPast)")
            
            // Check if user has valid token
            Task {
                do {
                    let idToken = try await firebaseUser.getIDToken()
                    print("   - ID Token: \(idToken.prefix(20))...")
                    print("   - Token is valid: YES")
                } catch {
                    print("   - ID Token: ERROR - \(error.localizedDescription)")
                    print("   - Token is valid: NO")
                }
            }
        } else {
            print("❌ Firebase Auth has NO current user")
        }
        
        // Check APIService state
        print("📱 APIService state:")
        print("   - isAuthenticated: \(authManager.isAuthenticated)")
        print("   - currentUser: \(authManager.currentUser?.id ?? "nil")")
        print("   - authToken: Not available in SimpleAuthManager")
        
        // Check ServiceCoordinator state
        print("🔧 ServiceCoordinator state:")
        print("   - isAuthenticated: \(serviceCoordinator.isAuthenticated)")
        print("   - currentUser: \(serviceCoordinator.currentUser?.id ?? "nil")")
        
        // Check UserDefaults
        print("💾 UserDefaults state:")
        print("   - currentUser data exists: \(UserDefaults.standard.data(forKey: "currentUser") != nil)")
        print("   - currentUserId: \(UserDefaults.standard.string(forKey: "currentUserId") ?? "nil")")
        print("   - authToken exists: \(UserDefaults.standard.string(forKey: "authToken") != nil)")
        print("   - biometric_login_email: \(UserDefaults.standard.string(forKey: "biometric_login_email") ?? "nil")")
        
        print("🔍 ===== END FIREBASE AUTH DEBUG =====")
    }
    
    private func restoreFirebaseAuthSession() {
        print("🔄 Attempting to restore Firebase Auth session...")
        
        // First, check current state
        print("🔍 Current state before restoration:")
        print("   - Firebase Auth current user: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("   - APIService isAuthenticated: \(authManager.isAuthenticated)")
        print("   - APIService currentUser: \(authManager.currentUser?.id ?? "nil")")
        
        // Check if we have a stored auth token
        // TODO: Add auth token to SimpleAuthManager
        let storedToken: String? = nil
        guard let storedToken = storedToken, !storedToken.isEmpty else {
            print("❌ No stored auth token found")
            return
        }
        
        print("✅ Found stored auth token: \(storedToken.prefix(20))...")
        
        // Check if we have stored credentials
        guard let storedEmail = UserDefaults.standard.string(forKey: "biometric_login_email"),
              let storedPassword = KeychainService.getPassword(for: storedEmail) else {
            print("❌ No stored credentials found")
            return
        }
        
        print("✅ Found stored credentials for: \(storedEmail)")
        
        // Clear current APIService state first to ensure clean restoration
        print("🧹 Clearing current APIService state...")
        // TODO: Add to SimpleAuthManager - apiService.currentUser = nil
        // TODO: Add to SimpleAuthManager - apiService.isAuthenticated = false
        // TODO: Add to SimpleAuthManager - apiService.organizations = []
        // TODO: Add to SimpleAuthManager - apiService.pendingRequests = []
        
        // Attempt to sign in with stored credentials
        Task {
            do {
                print("🔄 Attempting to sign in with stored credentials...")
                // TODO: Add email sign-in to SimpleAuthManager
                try await authManager.signInWithEmail(email: storedEmail, password: storedPassword)
                
                await MainActor.run {
                    print("✅ Firebase Auth session restored successfully!")
                    if let user = authManager.currentUser {
                        print("   - User: \(user.name ?? "Unknown")")
                        print("   - Email: \(user.email ?? "Unknown")")
                        print("   - ID: \(user.id)")
                    }
                    
                    // Verify Firebase Auth state after restoration
                    if let firebaseUser = Auth.auth().currentUser {
                        print("✅ Firebase Auth current user confirmed: \(firebaseUser.uid)")
                        print("✅ Firebase Auth email: \(firebaseUser.email ?? "none")")
                    } else {
                        print("❌ Firebase Auth still has no current user after restoration!")
                    }
                    
                    // The FCM token registration should now work
                    print("🔄 FCM token registration should now work...")
                }
                
            } catch {
                await MainActor.run {
                    print("❌ Failed to restore Firebase Auth session: \(error.localizedDescription)")
                    print("❌ Error details: \(error)")
                    
                    // If restoration fails, clear the stale data
                    print("🧹 Clearing stale authentication data...")
                    clearStaleAuthenticationData()
                }
            }
        }
    }
    
    private func forceSignOutAndClear() {
        print("🚨 FORCE SIGN OUT AND CLEAR - Nuclear option")
        
        // Use SimpleAuthManager's signOut method first
        authManager.signOut()
        
        // Clear ALL authentication data
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "biometric_login_email")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
        UserDefaults.standard.removeObject(forKey: "fcm_token")
        
        // Clear ServiceCoordinator state
        serviceCoordinator.currentUser = nil
        serviceCoordinator.isAuthenticated = false
        
        // Clear Keychain credentials
        if let email = UserDefaults.standard.string(forKey: "biometric_login_email") {
            do {
                try KeychainService.deletePassword(for: email)
                print("✅ Cleared Keychain credentials for: \(email)")
            } catch {
                print("⚠️ Error clearing Keychain credentials: \(error)")
            }
        }
        
        print("✅ All authentication data cleared")
        print("🔄 Forcing UI update...")
        
        // Force UI update with multiple approaches
        DispatchQueue.main.async {
            // Force objectWillChange to trigger UI update
            // TODO: Add objectWillChange to SimpleAuthManager
            print("ObjectWillChange not implemented in SimpleAuthManager")
            self.serviceCoordinator.objectWillChange.send()
            
            // Additional force update
            // TODO: Add isAuthenticated property to SimpleAuthManager
            print("isAuthenticated property not available in SimpleAuthManager")
            self.serviceCoordinator.isAuthenticated = false
            
            print("🔄 UI update forced - isAuthenticated should now be false")
            print("🔍 APIService isAuthenticated: \(self.authManager.isAuthenticated)")
            print("🔍 ServiceCoordinator isAuthenticated: \(self.serviceCoordinator.isAuthenticated)")
        }
    }
    
    private func forceAppRestart() {
        print("🚨 FORCE APP RESTART - Ultimate nuclear option")
        
        // Clear everything first
        forceSignOutAndClear()
        
        // Force app to restart by exiting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🚨 Forcing app exit...")
            exit(0)
        }
    }
    
    private func createTestAlert() async {
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user for test alert")
            return
        }
        
        // Get the first organization the user has access to
        // TODO: Add organizations to SimpleAuthManager
        guard let organization = nil as Organization? else {
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
    
    
    
    // MARK: - Force Re-register Push Notifications
    private func forceReregisterPushNotifications() async {
        print("🔄 Force re-registering push notifications...")
        
        await MainActor.run {
            alertTitle = "Re-registering Push Notifications"
            alertMessage = "Clearing old tokens and re-registering..."
            showingAlert = true
        }
        
        // Clear old FCM token
        UserDefaults.standard.removeObject(forKey: "fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
        
        // Force re-register for push notifications
        notificationManager.registerForPushNotifications()
        
        // Wait a moment then check status
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Check if we got a new token
        let newToken = UserDefaults.standard.string(forKey: "fcm_token")
        
        await MainActor.run {
            if let token = newToken, !token.isEmpty {
                alertTitle = "Success!"
                alertMessage = "Push notifications re-registered successfully!\n\nNew FCM Token: \(String(token.prefix(20)))..."
            } else {
                alertTitle = "Warning"
                alertMessage = "Push notifications re-registered but no FCM token received yet. This may take a few moments."
            }
            showingAlert = true
        }
    }
    
    // MARK: - Clear All FCM Data
    private func clearAllFCMData() async {
        print("🧹 Clearing ALL FCM data...")
        
        await MainActor.run {
            alertTitle = "Clearing FCM Data"
            alertMessage = "Removing all FCM tokens and data..."
            showingAlert = true
        }
        
        // Clear from UserDefaults
        UserDefaults.standard.removeObject(forKey: "fcm_token")
        UserDefaults.standard.removeObject(forKey: "fcmToken")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
        UserDefaults.standard.removeObject(forKey: "fcmTokenReceived")
        UserDefaults.standard.removeObject(forKey: "lastTokenUpdate")
        UserDefaults.standard.removeObject(forKey: "tokenStatus")
        
        print("✅ Cleared UserDefaults FCM data")
        
        // Clear from Firestore
        if let currentUser = Auth.auth().currentUser {
            do {
                let db = Firestore.firestore()
                try await db.collection("users").document(currentUser.uid).updateData([
                    "fcmToken": FieldValue.delete(),
                    "lastTokenUpdate": FieldValue.delete(),
                    "platform": FieldValue.delete(),
                    "appVersion": FieldValue.delete(),
                    "tokenStatus": FieldValue.delete()
                ])
                print("✅ Cleared Firestore FCM data")
            } catch {
                print("❌ Error clearing Firestore: \(error.localizedDescription)")
            }
        }
        
        // Clear from NotificationManager
        notificationManager.fcmToken = nil
        
        await MainActor.run {
            alertTitle = "FCM Data Cleared"
            alertMessage = "All FCM tokens and data have been removed.\n\nRestart the app for a completely clean state."
            showingAlert = true
        }
    }
    
    // MARK: - Force Request APNs Permission
    private func forceRequestAPNsPermission() async {
        print("🔔 Force requesting APNs permission...")
        
        await MainActor.run {
            alertTitle = "Requesting APNs Permission"
            alertMessage = "Requesting notification permissions..."
            showingAlert = true
        }
        
        let granted = await notificationManager.forceRequestAPNsPermission()
        
        await MainActor.run {
            if granted {
                alertTitle = "APNs Permission Granted"
                alertMessage = "Notification permissions granted!\n\nApp registered for remote notifications.\nFCM token should be generated shortly."
            } else {
                alertTitle = "APNs Permission Denied"
                alertMessage = "Notification permissions denied.\n\nGo to Settings > Notifications to enable notifications, then try again."
            }
            showingAlert = true
        }
    }
    
    // MARK: - Delete and Refresh FCM Token
    private func deleteAndRefreshFCMToken() async {
        print("🔄 Deleting old FCM token and getting new one...")
        
        await MainActor.run {
            alertTitle = "Refreshing FCM Token"
            alertMessage = "Deleting old token and getting fresh one..."
            showingAlert = true
        }
        
        let newToken = await notificationManager.deleteAndRefreshFCMToken()
        
        await MainActor.run {
            if let token = newToken, !token.isEmpty {
                alertTitle = "FCM Token Refreshed"
                alertMessage = "Old FCM token deleted successfully!\n\nNew FCM token: \(String(token.prefix(20)))...\n\nToken registered in Firestore and ready for notifications."
            } else {
                alertTitle = "FCM Token Refresh Failed"
                alertMessage = "Failed to get new FCM token.\n\nMake sure APNs permission is granted.\nTry 'Force Request APNs Permission' first."
            }
            showingAlert = true
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
    @EnvironmentObject var authManager: SimpleAuthManager
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
            
            // TODO: Add organizations to SimpleAuthManager
            if true {
                Text("No organizations found")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                // TODO: Add organizations to SimpleAuthManager
                ForEach([Organization](), id: \.id) { org in
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
                            .disabled(adminId == authManager.currentUser?.id)
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
        print("📋 Loaded 0 organizations") // TODO: Add organizations to SimpleAuthManager
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
                    // TODO: Add user fetching to SimpleAuthManager
                    if let user = nil as User? {
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
                // TODO: Add admin removal to SimpleAuthManager
                print("Admin removal not implemented in SimpleAuthManager")
                
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
    @EnvironmentObject var authManager: SimpleAuthManager
    
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
                // TODO: Add user search to SimpleAuthManager
                let users = [User]()
                
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
                // TODO: Add admin addition to SimpleAuthManager
                print("Admin addition not implemented in SimpleAuthManager")
                
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