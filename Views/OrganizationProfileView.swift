import SwiftUI
import UIKit
import FirebaseFirestore
import FirebaseAuth

struct OrganizationProfileView: View {
    let organization: Organization
    @EnvironmentObject var authManager: SimpleAuthManager
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @ObservedObject private var followStatusManager = FollowStatusManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var showingGroupSelection = false
    @State private var selectedGroups: [String] = []
    @State private var organizationGroups: [OrganizationGroup] = []
    @State private var isLoadingGroups = false
    @State private var showingGroupsError = false
    @State private var groupsErrorMessage = ""
    @State private var isOrganizationAdmin = false
    

    
    @State private var recentAlerts: [OrganizationAlert] = []
    @State private var groups: [OrganizationGroup] = []
    @State private var userGroupPreferences: [String: Bool] = [:]
    @State private var showingGroupsView: Bool = false
    @State private var showingAlertPostView: Bool = false
    @State private var showingGroupManagement: Bool = false
    @State private var showingEditOrganization: Bool = false

    @State private var isLoadingAlerts = false
    @State private var showingCreateGroupAlert = false
    @State private var newGroupName = ""
    @State private var newGroupDescription = ""
    @State private var showingAdminManagement = false
    @State private var newGroupIsPrivate = false
    @State private var newGroupAllowPublicJoin = true
    @State private var selectedGroupForAlert: OrganizationGroup?
    
    // Add state for current organization data that can be updated
    @State private var currentOrganization: Organization
    @State private var actualFollowerCount: Int = 0
    
    // Initialize currentOrganization with the passed organization
    init(organization: Organization) {
        self.organization = organization
        self._currentOrganization = State(initialValue: organization)
    }
    
    // Filter groups based on privacy and admin status
    private var visibleGroups: [OrganizationGroup] {
        let filteredGroups = groups.filter { group in
            // If user is organization admin, show all groups
            if isOrganizationAdmin {
                print("🔐 Admin user - showing group: \(group.name) (private: \(group.isPrivate))")
                return true
            }
            
            // If group is not private, show it to everyone
            if !group.isPrivate {
                print("🌐 Public group - showing group: \(group.name)")
                return true
            }
            
            // If group is private, only show if user is a member
            // For now, we'll hide all private groups from non-admin users
            print("🔒 Private group hidden from non-admin: \(group.name)")
            return false
        }
        
        print("🔍 Group filtering result:")
        print("   Total groups: \(groups.count)")
        print("   Visible groups: \(filteredGroups.count)")
        print("   Is admin: \(isOrganizationAdmin)")
        print("   Private groups: \(groups.filter { $0.isPrivate }.count)")
        
        // Debug each group individually
        for group in groups {
            print("   📋 Group: \(group.name)")
            print("      - isPrivate: \(group.isPrivate)")
            print("      - will be shown: \(filteredGroups.contains { $0.id == group.id })")
        }
        
        return filteredGroups
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Organization Header
                organizationHeader
                

                
                // Stats Section (Followers, Alerts, Status)
                statsSection
                
                // Follow/Unfollow Button removed
                
                // Post Alert Button removed for org admins - they will post alerts through group selection
                
                // Groups Section (only for organization admins)
                if isOrganizationAdmin {
                    groupsSection
                    groupManagementButtons
                }
                
                // Contact Section
                contactSection
                
                // Recent Alerts Section
                recentAlertsSection
            }
            .padding(.bottom, 20)
        }

        .navigationBarTitleDisplayMode(.inline)
                .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Add Group button for org admins
                    if isOrganizationAdmin {
                        Button(action: { 
                            showingCreateGroupAlert = true 
                        }) {
                            HStack(spacing: 4) {
                                // Show organization logo if available, otherwise show plus icon
                                if let logoURL = organization.logoURL, !logoURL.isEmpty {
                                    AsyncImage(url: URL(string: logoURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                    }
                                    .frame(width: 20, height: 20)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                }
                                Text("Add Group")
                                .font(.caption)
                                .fontWeight(.medium)
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                        
                        // Admin Management button
                        Button(action: { 
                            showingAdminManagement = true 
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.circle.fill")
                                    .font(.system(size: 20))
                                Text("Manage Admins")
                                .font(.caption)
                                .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        
                        // Delete Default Groups button for org admins
                        Button(action: { 
                            deleteDefaultGroups() 
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 16))
                                Text("Delete Default Groups")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                            )
                        }
                        
                        // Edit Organization button for org admins
                        Button(action: { 
                            print("✏️ Edit Organization button tapped")
                            showingEditOrganization = true 
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                Text("Edit")
                                .font(.caption)
                                .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        
                }
                    
                    

                }
            }
        }

        .sheet(isPresented: $showingGroupManagement) {
            OrganizationGroupManagementView(organization: organization)
        }
        .sheet(isPresented: $showingGroupsView) {
            if isOrganizationAdmin {
                OrganizationGroupManagementView(organization: organization)
            } else {
                OrganizationGroupPreferencesView(organization: organization)
            }
        }
        .sheet(isPresented: $showingAlertPostView) {
            OrganizationAlertPostView(organization: organization, preSelectedGroup: selectedGroupForAlert)
                .environmentObject(serviceCoordinator)
        }
        .onChange(of: showingAlertPostView) { _, isShowing in
            // Refresh alerts when the alert post view is dismissed
            if !isShowing {
                loadRecentAlerts()
                selectedGroupForAlert = nil // Clear selected group
            }
        }
        .sheet(isPresented: $showingEditOrganization) {
            OrganizationEditView(organization: organization)
        }
                       .onChange(of: showingEditOrganization) { _, isShowing in
                   // Refresh organization data when edit sheet is dismissed
                   if !isShowing {
                       print("🔄 Edit sheet dismissed, refreshing organization data...")
                       print("   - Organization ID: \(organization.id)")
                       print("   - Current logoURL before refresh: \(currentOrganization.logoURL ?? "nil")")
                       
                       Task {
                           // Force a direct refresh from Firestore
                           do {
                               let db = Firestore.firestore()
                               let doc = try await db.collection("organizations").document(organization.id).getDocument()
                               
                               if let data = doc.data() {
                                   let logoURL = data["logoURL"] as? String
                                   print("🔄 Direct Firestore fetch - logoURL: \(logoURL ?? "nil")")
                                   
                                   // Update currentOrganization with fresh data
                                   await MainActor.run {
                                       print("🔄 Updating currentOrganization with fresh data:")
                                       print("   - Old logoURL: \(self.currentOrganization.logoURL ?? "nil")")
                                       print("   - Direct Firestore logoURL: \(logoURL ?? "nil")")
                                       
                                       // Create a new organization with updated logoURL
                                       let updatedOrg = Organization(
                                           id: self.currentOrganization.id,
                                           name: self.currentOrganization.name,
                                           type: self.currentOrganization.type,
                                           description: self.currentOrganization.description,
                                           location: self.currentOrganization.location,
                                           verified: self.currentOrganization.verified,
                                           followerCount: self.currentOrganization.followerCount,
                                           logoURL: logoURL,
                                           website: self.currentOrganization.website,
                                           phone: self.currentOrganization.phone,
                                           email: self.currentOrganization.email,
                                           groups: self.currentOrganization.groups,
                                           adminIds: self.currentOrganization.adminIds,
                                           createdAt: self.currentOrganization.createdAt,
                                           updatedAt: self.currentOrganization.updatedAt,
                                           groupsArePrivate: self.currentOrganization.groupsArePrivate,
                                           allowPublicGroupJoin: self.currentOrganization.allowPublicGroupJoin,
                                           address: self.currentOrganization.address,
                                           city: self.currentOrganization.city,
                                           state: self.currentOrganization.state,
                                           zipCode: self.currentOrganization.zipCode
                                       )
                                       
                                       self.currentOrganization = updatedOrg
                                       print("✅ Organization data refreshed")
                                       print("✅ Current logoURL after refresh: \(self.currentOrganization.logoURL ?? "nil")")
                                   }
                               }
                           } catch {
                               print("❌ Failed to fetch directly from Firestore: \(error)")
                           }
                           
                           // TODO: Add organizations refresh to SimpleAuthManager
                print("Organizations refresh not implemented in SimpleAuthManager")
                           await checkAdminStatus()
                       }
                   } else {
                       print("🔄 Edit sheet opened")
                   }
               }
        .sheet(isPresented: $showingCreateGroupAlert) {
            CreateGroupSheetView(
                organization: currentOrganization,
                onGroupCreated: { group in
                    createGroupWithDetails(name: group.name, description: group.description ?? "No description", isPrivate: group.isPrivate, allowPublicJoin: group.allowPublicJoin)
                }
            )
        }
        .sheet(isPresented: $showingAdminManagement) {
            OrganizationAdminManagementView()
        }
        .onAppear {
            print("🏢 OrganizationProfileView appeared for: \(organization.name)")
            print("   Organization ID: \(organization.id)")
            print("   Organization Firestore ID: \(organization.id)")
            print("   Organization Admin IDs: \(organization.adminIds ?? [:])")
            print("   Current User ID: \(authManager.currentUser?.id ?? "nil")")
            
            print("🔍 About to call fetchGroups()...")
            loadRecentAlerts()
            fetchGroups()
            fetchActualFollowerCount() // Fetch actual follower count from Firestore
            loadGroupPreferences() // Load user's group preferences
            
            Task {
                await refreshOrganizationData() // Refresh organization data to get accurate follower count
            }
            print("🔍 fetchGroups() called")
            
            // Force admin status check immediately
            Task {
                await checkAdminStatus()
            }
            
            // Manually refresh organizations to ensure admin status is up to date
            Task {
                print("🔄 Manually refreshing organizations in OrganizationProfileView...")
                // TODO: Add organizations refresh to SimpleAuthManager
                print("Organizations refresh not implemented in SimpleAuthManager")
                print("   📋 Organizations refreshed, checking admin status...")
                // Re-check admin status after refresh
                await checkAdminStatus()
                
                // Update currentOrganization with fresh data
                // TODO: Add organization fetching to SimpleAuthManager
                // if let updatedOrg = nil as Organization? {
                //     await MainActor.run {
                //         self.currentOrganization = updatedOrg
                //     }
                // }
            }
            
            // Listen for organization updates
            NotificationCenter.default.addObserver(
                forName: .organizationUpdated,
                object: organization.id,
                queue: .main
            ) { _ in
                print("📢 Received organizationUpdated notification for: \(organization.id)")
                Task {
                    await refreshOrganizationData()
                    print("📢 Organization data refreshed after notification")
                }
            }
        }
        .onDisappear {
            removeNotificationObservers()
            NotificationCenter.default.removeObserver(self, name: .organizationUpdated, object: organization.id)
        }
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        // Listen for organization updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OrganizationUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            handleLogoUpdate()
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Handle Logo Updates
    private func handleLogoUpdate() {
        print("🔄 OrganizationProfileView: Handling logo update...")
        
        Task {
            // Force refresh the organization data
            // TODO: Add organization refresh to SimpleAuthManager
            print("Organization refresh not implemented in SimpleAuthManager")
            
            // Also refresh the current organization
            // TODO: Add organization fetching to SimpleAuthManager
            // if let updatedOrg = nil as Organization? {
            //     await MainActor.run {
            //         self.currentOrganization = updatedOrg
            //         print("✅ OrganizationProfileView: Updated current organization with new logo")
            //     }
            // }
        }
    }
    
    // MARK: - Organization Header
    private var organizationHeader: some View {
        VStack(spacing: 16) {
            // Organization Logo/Icon
            OrganizationLogoView(organization: currentOrganization, size: 100, showBorder: true)
                .onTapGesture {
                    print("🖼️ Tapped on organization logo")
                    print("   - Current logoURL: \(currentOrganization.logoURL ?? "nil")")
                    // Force refresh the organization data
                    Task {
                        await refreshOrganizationData()
                        // Also force refresh from Firestore
                        await refreshOrganizationData()
                    }
                }
                .onAppear {
                    print("🖼️ OrganizationProfileView - OrganizationLogoView appeared:")
                    print("   - Name: \(currentOrganization.name)")
                    print("   - ID: \(currentOrganization.id)")
                    print("   - Logo URL: \(currentOrganization.logoURL ?? "nil")")
                    print("   - Logo URL isEmpty: \(currentOrganization.logoURL?.isEmpty ?? true)")
                    print("   - Organization type: \(currentOrganization.type)")
                    if let logoURL = currentOrganization.logoURL {
                        print("   - Logo URL length: \(logoURL.count)")
                        print("   - Logo URL first 50 chars: \(String(logoURL.prefix(50)))")
                    }
                }
            
            // Organization Info
            VStack(spacing: 8) {
                // Organization Name - Centered and properly spaced
                VStack(spacing: 4) {
                    Text(currentOrganization.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if currentOrganization.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }
                

                

                
                if let description = currentOrganization.description {
                    Text(description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 16) {
            Text("Organization Stats")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Followers",
                    value: "\(actualFollowerCount)",
                    icon: "person.2.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Alerts",
                    value: "\(recentAlerts.count)",
                    icon: "bell.fill",
                    color: .orange
                )
                
                StatCard(
                    title: isOrganizationAdmin ? "Groups" : "Groups",
                    value: "\(visibleGroups.count)",
                    icon: "person.3.fill",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var groupsSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Text("Alert Groups")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Small green plus button removed - org admins will manage groups through the Active status box
                }
                

                
                if isOrganizationAdmin && !visibleGroups.isEmpty {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Tap a group to post an alert to that specific group")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            

            
            if isLoadingGroups {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading groups...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if visibleGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Groups Available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This organization hasn't set up any alert groups yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleGroups) { group in
                        GroupToggleRow(
                            group: group,
                            isEnabled: userGroupPreferences[group.id] ?? true,
                            onToggle: { isEnabled in
                                toggleGroupAlerts(groupId: group.id, enabled: isEnabled)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isOrganizationAdmin {
                                print("🔍 Group tapped: \(group.name) (ID: \(group.id))")
                                selectedGroupForAlert = group
                                print("🔍 selectedGroupForAlert set to: \(selectedGroupForAlert?.name ?? "nil")")
                                showingAlertPostView = true
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if isOrganizationAdmin {
                                Button(role: .destructive) {
                                    deleteGroup(group)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        if group.id != groups.last?.id {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color(.systemGray5))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Group Management Buttons
    private var groupManagementButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Manage Groups Button
                Button(action: {
                    print("🔧 Manage Groups button tapped")
                    showingGroupManagement = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                        Text("Manage Groups")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                // Add Group Button
                Button(action: {
                    print("➕ Add Group button tapped")
                    showingCreateGroupAlert = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Group")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Post Alert Button
    private var postAlertButton: some View {
        Button(action: { 
            showingAlertPostView = true 
        }) {
            HStack {
                Image(systemName: "megaphone.fill")
                Text("Post Alert")
            }
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // Follow Button Section removed
    
    // MARK: - Contact Section
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Contact")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isOrganizationAdmin {
                    Button(action: { 
                        print("✏️ Contact Edit button tapped")
                        showingEditOrganization = true 
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                            Text("Edit")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            // Email contact
            if let email = currentOrganization.email, !email.isEmpty {
                ContactButtonRow(icon: "envelope", text: email, action: { openEmail(email) })
            }
            
            if let phone = currentOrganization.phone {
                ContactButtonRow(icon: "phone", text: phone, action: { openPhone(phone) })
            }
            if let website = currentOrganization.website {
                ContactButtonRow(icon: "globe", text: website, action: { openWebsite(website) })
            }
            
            // Address information - combined into one line
            // Check nested location first, then fall back to flat address fields
            if let address = currentOrganization.location.address, !address.isEmpty,
               let city = currentOrganization.location.city, !city.isEmpty,
               let state = currentOrganization.location.state, !state.isEmpty,
               let zipCode = currentOrganization.location.zipCode, !zipCode.isEmpty {
                let fullAddress = "\(address), \(city), \(state) \(zipCode)"
                ContactButtonRow(icon: "location", text: fullAddress, action: { openMaps(address: fullAddress) })
            } else if let address = currentOrganization.location.address, !address.isEmpty {
                // Fallback if some address components are missing from nested location
                ContactButtonRow(icon: "location", text: address, action: { openMaps(address: address) })
            } else if let flatAddress = currentOrganization.address, !flatAddress.isEmpty,
                      let flatCity = currentOrganization.city, !flatCity.isEmpty,
                      let flatState = currentOrganization.state, !flatState.isEmpty,
                      let flatZipCode = currentOrganization.zipCode, !flatZipCode.isEmpty {
                // Fallback to flat address fields if nested location is empty
                let fullAddress = "\(flatAddress), \(flatCity), \(flatState) \(flatZipCode)"
                ContactButtonRow(icon: "location", text: fullAddress, action: { openMaps(address: fullAddress) })
            } else if let flatAddress = currentOrganization.address, !flatAddress.isEmpty {
                // Show just the street address if other flat fields are missing
                ContactButtonRow(icon: "location", text: flatAddress, action: { openMaps(address: flatAddress) })
            } else {
                // No address information available - show helpful message
                HStack {
                    Image(systemName: "location.slash")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text("Address information not available")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Recent Alerts Section
    private var recentAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Alerts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: loadRecentAlerts) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            if recentAlerts.isEmpty {
                VStack(spacing: 16) {
                    if isLoadingAlerts {
                        ProgressView("Loading alerts...")
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "medical.thermometer")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("No recent alerts")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("This organization hasn't posted any alerts recently.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 16) {
                        ForEach(recentAlerts) { alert in
                            AlertRowView(
                            alert: alert, 
                            onDelete: { deleteAlert(alert) },
                            isOrganizationAdmin: isOrganizationAdmin
                        )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if isOrganizationAdmin {
                                        Button(role: .destructive) {
                                            deleteAlert(alert)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                    .frame(minHeight: 100)
                }
            }
            .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    
    // This will be called when the view appears to check admin status
    private func checkAdminStatus() async {
        print("🔍 Checking admin status for organization: \(organization.name)")
        print("   Organization ID: \(organization.id)")
        print("   Current user ID: \(authManager.currentUser?.id ?? "nil")")
        
        // Try to get user ID from multiple sources
        var currentUserId: String?
        
        // First try SimpleAuthManager
        if let apiUserId = authManager.currentUser?.id {
            currentUserId = apiUserId
            print("✅ Found user ID from APIService: \(apiUserId)")
        }
        // Then try UserDefaults
        else if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            currentUserId = defaultsUserId
            print("✅ Found user ID from UserDefaults: \(defaultsUserId)")
        }
        // Finally try Firebase Auth
        else if let firebaseUserId = Auth.auth().currentUser?.uid {
            currentUserId = firebaseUserId
            print("✅ Found user ID from Firebase Auth: \(firebaseUserId)")
        }
        
        guard let userId = currentUserId else {
            print("❌ No current user ID found from any source")
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
            return
        }
        
        print("✅ Using user ID for admin check: \(userId)")
        
        do {
            let db = Firestore.firestore()
            
            // First, check if the user document exists and has admin flags
            let userRef = db.collection("users").document(userId)
            let userDoc = try await userRef.getDocument()
            
            if userDoc.exists {
                let userData = userDoc.data() ?? [:]
                let isUserAdmin = userData["isAdmin"] as? Bool ?? false
                let isUserOrgAdmin = userData["isOrganizationAdmin"] as? Bool ?? false
                
                print("   📋 User document found:")
                print("      - Document ID: \(userId)")
                print("      - Email in document: \(userData["email"] as? String ?? "nil")")
                print("      - Name in document: \(userData["name"] as? String ?? "nil")")
                print("      - isAdmin: \(isUserAdmin)")
                print("      - isOrganizationAdmin: \(isUserOrgAdmin)")
                print("   🔐 Current user from API service:")
                print("      - UID: \(authManager.currentUser?.id ?? "nil")")
                print("      - Email: \(authManager.currentUser?.email ?? "nil")")
                
                // Check if user should be admin of THIS specific organization
                let orgRef = db.collection("organizations").document(organization.id)
                let orgDoc = try await orgRef.getDocument()
                
                if orgDoc.exists {
                    let orgData = orgDoc.data() ?? [:]
                    let adminIds = orgData["adminIds"] as? [String: Bool] ?? [:]
                    let orgEmail = orgData["email"] as? String ?? ""
                    let orgCreatedBy = orgData["createdBy"] as? String ?? ""
                    
                    print("   🏢 Organization document found:")
                    print("      - adminIds: \(adminIds)")
                    print("      - org email: \(orgEmail)")
                    print("      - created by: \(orgCreatedBy)")
                    
                    // Check if current user is already in adminIds
                    let isInAdminIds = adminIds[userId] == true
                    print("      - Current user in adminIds: \(isInAdminIds)")
                    
                    // SIMPLE: User is ONLY admin if they are explicitly in adminIds
                    // No other logic, no automatic granting, no global admin privileges
                    let canBeAdmin = isInAdminIds
                    
                    print("      - User can be admin: \(canBeAdmin)")
                    print("         - In adminIds: \(isInAdminIds)")
                    print("         - That's it. No other checks.")
                    
                    // NEVER automatically add users to adminIds
                    // They must be explicitly added by someone who already has admin access
                    
                    await MainActor.run {
                        self.isOrganizationAdmin = canBeAdmin
                        print("🔄 Set isOrganizationAdmin to: \(self.isOrganizationAdmin)")
                    }
                } else {
                    print("   ❌ Organization document not found")
                    await MainActor.run {
                        self.isOrganizationAdmin = false
                    }
                }
            } else {
                print("   ❌ User document not found")
                await MainActor.run {
                    self.isOrganizationAdmin = false
                }
            }
            
        } catch {
            print("❌ Error checking admin status: \(error)")
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
        }
    }
    



    
    // MARK: - Helper Views
    private var organizationIcon: String {
        // Use a default professional icon since we're no longer displaying organization type
        return "building.2.circle.fill"
    }

    
    private var organizationColor: Color {
        // Use a default professional color since we're no longer displaying organization type
        return .blue
    }

    
    // MARK: - Helper Functions
    private func fetchGroups() {
        print("🔍 fetchGroups() called for organization: \(organization.id)")
        print("   Organization name: \(organization.name)")
        Task {
            await MainActor.run {
                isLoadingGroups = true
                print("   🔄 Set isLoadingGroups to true")
            }
            
            do {
                print("   📡 Calling organization groups fetching...")
                // Use the OrganizationGroupService to fetch groups
                let groupService = OrganizationGroupService()
                let fetchedGroups = try await groupService.getOrganizationGroups(organizationId: organization.id)
                print("🔍 Fetched \(fetchedGroups.count) groups:")
                for group in fetchedGroups {
                    print("   - \(group.name) (ID: \(group.id), isPrivate: \(group.isPrivate))")
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.groups = fetchedGroups
                        self.isLoadingGroups = false
                        print("✅ Groups loaded into UI: \(self.groups.count)")
                    }
                }
            } catch {
                print("❌ Failed to fetch groups: \(error)")
                print("   Error details: \(error.localizedDescription)")
                print("   Error type: \(type(of: error))")
                await MainActor.run {
                    self.isLoadingGroups = false
                    print("   🔄 Set isLoadingGroups to false due to error")
                }
            }
        }
    }
    
    private func loadRecentAlerts() {
        Task {
            await MainActor.run {
                isLoadingAlerts = true
            }
            
            print("🔍 [OrganizationProfileView] Loading recent alerts for organization: \(organization.name)")
            print("   Organization ID: \(organization.id)")
            
            do {
                // TODO: Add organization alerts fetching to SimpleAuthManager
                let alerts = [OrganizationAlert]()
                print("✅ [OrganizationProfileView] Received \(alerts.count) alerts from API")
                
                for alert in alerts.prefix(3) {
                    print("   📋 Alert: \(alert.title) (posted: \(alert.postedAt))")
                }
                
                await MainActor.run {
                    self.recentAlerts = alerts
                    self.isLoadingAlerts = false
                    print("✅ [OrganizationProfileView] Updated UI with \(alerts.count) alerts")
                }
            } catch {
                print("❌ [OrganizationProfileView] Failed to load recent alerts: \(error)")
                await MainActor.run {
                    self.isLoadingAlerts = false
                }
            }
        }
    }
    
    private func debugAlerts() {
        print("🔍 [DEBUG] Current alerts state:")
        print("   Organization: \(organization.name)")
        print("   Organization ID: \(organization.id)")
        print("   recentAlerts.count: \(recentAlerts.count)")
        print("   isLoadingAlerts: \(isLoadingAlerts)")
        print("   isOrganizationAdmin: \(isOrganizationAdmin)")
        
        for (index, alert) in recentAlerts.enumerated() {
            print("   Alert \(index + 1): \(alert.title)")
            print("      ID: \(alert.id)")
            print("      Organization ID: \(alert.organizationId)")
            print("      Posted: \(alert.postedAt)")
            print("      Active: \(alert.isActive)")
        }
        
        if recentAlerts.isEmpty {
            print("   🚨 No alerts in recentAlerts array!")
        }
    }
    
    
    private func fetchActualFollowerCount() {
        print("🔍 Fetching actual follower count for organization: \(organization.id)")
        
        Task {
            do {
                let db = Firestore.firestore()
                let followersSnapshot = try await db.collection("organizations")
                    .document(organization.id)
                    .collection("followers")
                    .getDocuments()
                
                let count = followersSnapshot.documents.count
                
                await MainActor.run {
                    self.actualFollowerCount = count
                    print("✅ Actual follower count: \(count)")
                }
            } catch {
                print("❌ Failed to fetch follower count: \(error)")
                // Fall back to the stored count if there's an error
                await MainActor.run {
                    self.actualFollowerCount = currentOrganization.followerCount
                }
            }
        }
    }
    

    

    
    private func deleteAlert(_ alert: OrganizationAlert) {
        Task {
            do {
                // TODO: Add alert deletion to SimpleAuthManager
                print("Alert deletion not implemented in SimpleAuthManager")
                print("✅ Alert deleted successfully from Firestore")
                
                // Remove from local state and refresh
                await MainActor.run {
                    recentAlerts.removeAll { $0.id == alert.id }
                }
            } catch {
                print("❌ Failed to delete alert from Firestore: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to delete alert: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func loadGroupPreferences() {
        Task {
            do {
                let allPreferences = try await serviceCoordinator.fetchUserGroupPreferences()
                await MainActor.run {
                    // Filter preferences for this organization's groups only
                    for group in groups {
                        if let preference = allPreferences[group.id] {
                            userGroupPreferences[group.id] = preference
                        } else {
                            userGroupPreferences[group.id] = false // Default to disabled
                        }
                    }
                    print("✅ Loaded \(userGroupPreferences.count) group preferences for \(organization.name)")
                }
            } catch {
                print("❌ Error loading group preferences: \(error)")
            }
        }
    }
    
    private func toggleGroupAlerts(groupId: String, enabled: Bool) {
        userGroupPreferences[groupId] = enabled
        
        Task {
            do {
                try await serviceCoordinator.updateGroupPreference(
                    organizationId: organization.id,
                    groupId: groupId,
                    isEnabled: enabled
                )
                print("✅ Updated group preference: \(groupId) = \(enabled)")
            } catch {
                print("❌ Error updating group preference: \(error)")
                // Revert the local change on error
                await MainActor.run {
                    userGroupPreferences[groupId] = !enabled
                }
            }
        }
    }
    
    // MARK: - Group Management Functions
    private func createNewGroup() {
        showingCreateGroupAlert = true
    }
    
    private func createGroupWithDetails(name: String, description: String, isPrivate: Bool = false, allowPublicJoin: Bool = true) {
        print("🔍 Creating new group: \(name)")
        print("   Description: \(description)")
        print("   Is Private: \(isPrivate)")
        print("   Allow Public Join: \(allowPublicJoin)")
        print("   Organization ID: \(organization.id)")
        
        Task {
            do {
                let newGroup = OrganizationGroup(
                    name: name,
                    description: description,
                    organizationId: organization.id,
                    isPrivate: isPrivate,
                    allowPublicJoin: allowPublicJoin
                )
                
                print("   📋 New group object created: \(newGroup.name) (ID: \(newGroup.id))")
                
                try await serviceCoordinator.createOrganizationGroup(group: newGroup, organizationId: organization.id)
                
                print("   ✅ Group created in Firestore successfully")
                
                // Refresh groups
                print("   🔄 Refreshing groups list...")
                fetchGroups()
                
                print("✅ Group created successfully: \(name)")
            } catch {
                print("❌ Failed to create group: \(error)")
                print("   Error details: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Debug Functions
    private func debugAccess() {
        print("🔍 Debug: Organization Profile Access")
        print("   Organization: \(organization.name)")
        print("   Organization ID: \(organization.id)")
        print("   Current User: \(authManager.currentUser?.name ?? "Unknown")")
        print("   Current User ID: \(authManager.currentUser?.id ?? "Unknown")")
        print("   Is Organization Admin: \(isOrganizationAdmin)")
        print("   Organization Admin IDs: \(organization.adminIds ?? [:])")
    }
    

    
    

    
    private func deleteGroup(_ group: OrganizationGroup) {
        Task {
            do {
                // TODO: Add group deletion to SimpleAuthManager
                print("Group deletion not implemented in SimpleAuthManager")
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // Create a new array to avoid collection view crashes
                        var updatedGroups = groups
                        updatedGroups.removeAll { $0.id == group.id }
                        groups = updatedGroups
                        userGroupPreferences.removeValue(forKey: group.id)
                    }
                }
            } catch {
                // Handle error silently or show user-friendly message
            }
        }
    }
    
    private func deleteDefaultGroups() {
        print("🗑️ Delete default groups tapped")
        Task {
            do {
                // TODO: Add default groups deletion to SimpleAuthManager
                print("Default groups deletion not implemented in SimpleAuthManager")
                await MainActor.run {
                    // Refresh the groups list
                    fetchGroups()
                }
                print("✅ Default groups deleted successfully")
            } catch {
                print("❌ Error deleting default groups: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to delete default groups: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - Contact Helper Functions
    private func openEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPhone(_ phone: String) {
        if let url = URL(string: "tel:\(phone)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWebsite(_ website: String) {
        var urlString = website
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openMaps(address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        if let url = URL(string: "http://maps.apple.com/?q=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }
    
    // Follow Status Management methods removed

    private func refreshOrganizationData() async {
        Task {
            do {
                // Fetch organization data directly from Firestore
                let db = Firestore.firestore()
                let doc = try await db.collection("organizations").document(organization.id).getDocument()
                
                if let data = doc.data() {
                    let logoURL = data["logoURL"] as? String
                    print("🔄 Refreshing organization data from Firestore:")
                    print("   - Old logoURL: \(self.currentOrganization.logoURL ?? "nil")")
                    print("   - New logoURL: \(logoURL ?? "nil")")
                    
                    // Create updated organization with fresh data
                    let updatedOrg = Organization(
                        id: self.currentOrganization.id,
                        name: self.currentOrganization.name,
                        type: self.currentOrganization.type,
                        description: self.currentOrganization.description,
                        location: self.currentOrganization.location,
                        verified: self.currentOrganization.verified,
                        followerCount: self.currentOrganization.followerCount,
                        logoURL: logoURL,
                        website: self.currentOrganization.website,
                        phone: self.currentOrganization.phone,
                        email: self.currentOrganization.email,
                        groups: self.currentOrganization.groups,
                        adminIds: self.currentOrganization.adminIds,
                        createdAt: self.currentOrganization.createdAt,
                        updatedAt: self.currentOrganization.updatedAt,
                        groupsArePrivate: self.currentOrganization.groupsArePrivate,
                        allowPublicGroupJoin: self.currentOrganization.allowPublicGroupJoin,
                        address: self.currentOrganization.address,
                        city: self.currentOrganization.city,
                        state: self.currentOrganization.state,
                        zipCode: self.currentOrganization.zipCode
                    )
                    
                    await MainActor.run {
                        self.currentOrganization = updatedOrg
                        print("✅ Organization data refreshed successfully")
                        print("✅ New logoURL: \(self.currentOrganization.logoURL ?? "nil")")
                        print("✅ Follower count: \(updatedOrg.followerCount)")
                    }
                }
                
                // Also refresh the actual follower count from Firestore
                fetchActualFollowerCount()
            } catch {
                print("❌ Failed to refresh organization data: \(error)")
            }
        }
    }
}

// MARK: - Contact Button Row
struct ContactButtonRow: View {
    let icon: String
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(text)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}



// MARK: - Admin Group Row
struct AdminGroupRow: View {
    let group: OrganizationGroup
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                Text(group.description ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Alert Row View
struct AlertRowView: View {
    let alert: OrganizationAlert
    let onDelete: () -> Void
    let isOrganizationAdmin: Bool // Pass admin status from parent
    @EnvironmentObject var authManager: SimpleAuthManager
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var organization: Organization?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and date
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(formatTimestamp(alert.postedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Admin actions for organization admins
                if isOrganizationAdmin {
                    Menu {
                        Button(action: { showingEditAlert = true }) {
                            Label("Edit Alert", systemImage: "pencil")
                        }
                        
                        Button(action: { showingDeleteAlert = true }) {
                            Label("Delete Alert", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
            }
            
            // Description
            Text(alert.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            
            // Organization info
            HStack(spacing: 8) {
                // Organization Logo
                if let organization = organization {
                    OrganizationLogoView(organization: organization, size: 20, showBorder: false)
                } else {
                    // Fallback icon while loading
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                Text(alert.organizationName)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            // Type and severity badges
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: alert.type.icon)
                        .foregroundColor(alert.type.color)
                        .font(.caption)
                    Text(alert.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(alert.type.color.opacity(0.1))
                .cornerRadius(8)
                
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(severityColor)
                        .font(.caption)
                    Text(alert.severity.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(severityColor.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
            }
        }
        .padding(16)
        .onAppear {
            Task {
                await loadOrganization()
            }
        }
        .alert("Delete Alert", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAlert()
            }
        } message: {
            Text("Are you sure you want to delete this alert? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditAlert) {
            EditAlertView(alert: alert)
        }
    }
    
    private var severityColor: Color {
        switch alert.severity {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    // Note: isOrganizationAdmin is now passed from parent view, no need to check here
    
    private func loadOrganization() async {
        guard organization == nil else { return }
        
        do {
            // TODO: Add organization fetching to SimpleAuthManager
            if let org = nil as Organization? {
                await MainActor.run {
                    self.organization = org
                }
            }
        } catch {
            print("❌ Failed to load organization: \(error)")
        }
    }
    
    private func deleteAlert() {
        Task {
            do {
                // TODO: Add alert deletion to SimpleAuthManager
                print("Alert deletion not implemented in SimpleAuthManager")
                print("✅ Alert deleted successfully from Firestore")
                // Call the parent's deletion callback to update the UI
                await MainActor.run {
                    onDelete()
                }
            } catch {
                print("❌ Failed to delete alert from Firestore: \(error)")
            }
        }
    }
}

// MARK: - Edit Alert View
struct EditAlertView: View {
    let alert: OrganizationAlert
    @EnvironmentObject var authManager: SimpleAuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var selectedType: IncidentType
    @State private var selectedSeverity: IncidentSeverity
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    
    init(alert: OrganizationAlert) {
        self.alert = alert
        self._title = State(initialValue: alert.title)
        self._description = State(initialValue: alert.description)
        self._selectedType = State(initialValue: alert.type)
        self._selectedSeverity = State(initialValue: alert.severity)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Alert Details") {
                    TextField("Alert Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(IncidentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                            Text(severity.displayName).tag(severity)
                        }
                    }
                }
                
                Section {
                    Button(action: updateAlert) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isSubmitting ? "Updating..." : "Update Alert")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Edit Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Alert Updated!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your alert has been updated successfully.")
            }
        }
    }
    
    private func updateAlert() {
        isSubmitting = true
        
        // Create updated alert
        let updatedAlert = OrganizationAlert(
            id: alert.id,
            title: title,
            description: description,
            organizationId: alert.organizationId,
            organizationName: alert.organizationName,
            groupId: alert.groupId,
            groupName: alert.groupName,
            type: selectedType,
            severity: selectedSeverity,
            location: alert.location,
            postedBy: alert.postedBy,
            postedByUserId: alert.postedByUserId,
            postedAt: alert.postedAt,
            imageURLs: alert.imageURLs
        )
        
        Task {
            do {
                // TODO: Add alert editing to SimpleAuthManager
                print("Alert editing not implemented in SimpleAuthManager")
                await MainActor.run {
                    isSubmitting = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    print("❌ Failed to update alert: \(error)")
                }
            }
        }
    }
}

// MARK: - Timestamp Formatting
private func formatTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

// MARK: - Organization Contact Sheet
struct OrganizationContactSheet: View {
    let organization: Organization
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var subject = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    if let email = organization.email {
                        HStack {
                            Image(systemName: "envelope")
                            Text(email)
                        }
                    }
                    
                    if let phone = organization.phone {
                        HStack {
                            Image(systemName: "phone")
                            Text(phone)
                        }
                    }
                    
                    if let website = organization.website {
                        HStack {
                            Image(systemName: "globe")
                            Text(website)
                        }
                    }
                }
                
                Section("Send Message") {
                    TextField("Subject", text: $subject)
                    TextField("Message", text: $messageText, axis: .vertical)
                        .lineLimit(4...8)
                }
                
                Section {
                    Button("Send Message") {
                        // In a real app, this would send the message
                        dismiss()
                    }
                    .disabled(messageText.isEmpty || subject.isEmpty)
                }
            }
            .navigationTitle("Contact \(organization.name)")
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

#Preview {
    NavigationView {
        OrganizationProfileView(
            organization: Organization(
                id: "test",
                name: "Test Organization",
                type: "business",
                description: "This is a test organization for preview purposes.",
                location: Location(
                    latitude: 33.1032,
                    longitude: -96.6705,
                    address: "123 Test St",
                    city: "Test City",
                    state: "TX",
                    zipCode: "75002"
                ),
                verified: true,
                followerCount: 150,
                website: "https://test.com",
                phone: "555-0123",
                email: "test@test.com"
            )
        )
        .environmentObject(APIService())
    }
}

struct CreateGroupSheetView: View {
    let organization: Organization
    let onGroupCreated: (OrganizationGroup) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isPrivate = false
    @State private var allowPublicJoin = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                    TextField("Description (Optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Privacy Settings")) {
                    Toggle("Make Group Private", isOn: $isPrivate)
                        .onChange(of: isPrivate) { _, newValue in
                            if !newValue {
                                allowPublicJoin = true
                            }
                        }
                    
                    if isPrivate {
                        Toggle("Allow Public Join", isOn: $allowPublicJoin)
                        
                        Text("When a group is private, members must be manually invited by organization admins.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(footer: Text("Groups help organize your alerts and allow users to choose which types of notifications they want to receive.")) {
                    Button(action: createGroup) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Creating Group...")
                            }
                        } else {
                            Text("Create Group")
                        }
                    }
                    .disabled(groupName.isEmpty || isLoading)
                }
            }
            .navigationTitle("Create New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    errorMessage = nil
                    showingErrorAlert = false
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func createGroup() {
        guard !groupName.isEmpty else { return }
        
        isLoading = true
        
        let newGroup = OrganizationGroup(
            name: groupName,
            description: groupDescription.isEmpty ? nil : groupDescription,
            organizationId: organization.id,
            isPrivate: isPrivate,
            allowPublicJoin: allowPublicJoin
        )
        
        Task {
            do {
                let createdGroup = try await apiService.createOrganizationGroup(
                    group: newGroup,
                    organizationId: organization.id
                )
                
                await MainActor.run {
                    onGroupCreated(createdGroup)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create group: \(error.localizedDescription)"
                    showingErrorAlert = true
                    isLoading = false
                }
            }
        }
    }
} 