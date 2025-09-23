import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

// MARK: - Organization Service
class OrganizationService: ObservableObject {
    @Published var organizations: [Organization] = []
    @Published var pendingRequests: [OrganizationRequest] = []
    
    private let userService: UserManagementService
    
    init(userService: UserManagementService) {
        self.userService = userService
    }
    
    // MARK: - Load Organizations
    func loadOrganizations() async {
        print("🔍 Loading organizations into service...")
        
        do {
            let organizations = try await fetchOrganizations()
            
            await MainActor.run {
                self.organizations = organizations
            }
            
            print("✅ Loaded \(organizations.count) organizations")
        } catch {
            print("❌ Failed to load organizations: \(error)")
        }
    }
    
    // MARK: - Fetch Organizations from Firestore
    func fetchOrganizations() async throws -> [Organization] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("organizations").getDocuments()
        
        var organizations: [Organization] = []
        
        for document in snapshot.documents {
            do {
                let organization = try await parseOrganizationFromFirestore(docId: document.documentID, data: document.data())
                if let org = organization {
                    organizations.append(org)
                }
            } catch {
                print("⚠️ Warning: Could not parse organization \(document.documentID): \(error)")
            }
        }
        
        return organizations
    }
    
    // MARK: - Parse Organization from Firestore
    private func parseOrganizationFromFirestore(docId: String, data: [String: Any]) async throws -> Organization? {
        let name = data["name"] as? String ?? "Unknown"
        let type = data["type"] as? String ?? "business"
        let description = data["description"] as? String ?? ""
        let website = data["website"] as? String
        let phone = data["phone"] as? String
        let email = data["email"] as? String ?? ""
        let verified = data["verified"] as? Bool ?? false
        let followerCount = data["followerCount"] as? Int ?? 0
        let logoURL = data["logoURL"] as? String
        
        // Debug logging for logo URL
        print("🔍 OrganizationService parseOrganizationFromFirestore:")
        print("   - Organization ID: \(docId)")
        print("   - Organization name: \(name)")
        print("   - Raw logoURL from Firestore: \(String(describing: data["logoURL"]))")
        print("   - Parsed logoURL: \(String(describing: logoURL))")
        print("   - logoURL isEmpty: \(logoURL?.isEmpty ?? true)")
        print("   - logoURL is nil: \(logoURL == nil)")
        
        let adminIds = data["adminIds"] as? [String: Bool] ?? [:]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Parse organization settings
        let groupsArePrivate = data["groupsArePrivate"] as? Bool ?? false
        let allowPublicGroupJoin = data["allowPublicGroupJoin"] as? Bool ?? true
        
        // Try to get location from nested structure first
        var location: Location
        if let locationData = data["location"] as? [String: Any],
           let latitude = locationData["latitude"] as? Double,
           let longitude = locationData["longitude"] as? Double {
            // Use nested location data
            location = Location(
                latitude: latitude,
                longitude: longitude,
                address: locationData["address"] as? String,
                city: locationData["city"] as? String,
                state: locationData["state"] as? String,
                zipCode: locationData["zipCode"] as? String
            )
        } else {
            // Fall back to flat address fields for backward compatibility
            let address = data["address"] as? String ?? ""
            let city = data["city"] as? String ?? ""
            let state = data["state"] as? String ?? ""
            let zipCode = data["zipCode"] as? String ?? ""
            
            location = Location(
                latitude: 33.1032, // Default coordinates
                longitude: -96.6705,
                address: address.isEmpty ? nil : address,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                zipCode: zipCode.isEmpty ? nil : zipCode
            )
        }
        
        let organization = Organization(
            id: docId,
            name: name,
            type: type,
            description: description,
            location: location,
            verified: verified,
            followerCount: followerCount,
            logoURL: logoURL,
            website: website,
            phone: phone,
            email: email,
            groups: nil,
            adminIds: adminIds,
            createdAt: createdAt,
            updatedAt: updatedAt,
            groupsArePrivate: groupsArePrivate,
            allowPublicGroupJoin: allowPublicGroupJoin
        )
        
        return organization
    }
    
    // MARK: - Organization Requests
    func submitOrganizationRequest(_ request: OrganizationRequest) async throws -> OrganizationRequest {
        print("🏢 Organization registration request received:")
        print("   Name: \(request.name)")
        print("   Type: \(request.type.displayName)")
        print("   Contact: \(request.contactPersonName)")
        print("   Email: \(request.contactPersonEmail)")
        print("   Phone: \(request.contactPersonPhone)")
        print("   Address: \(request.fullAddress)")
        print("   Description: \(request.description)")
        
        // Automatically geocode the address to get GPS coordinates
        print("🌍 Auto-geocoding address for GPS coordinates...")
        let fullAddress = "\(request.address), \(request.city), \(request.state) \(request.zipCode)"
        let geocodedLocation = await geocodeAddress(fullAddress)
        
        var latitude: Double = 0.0
        var longitude: Double = 0.0
        
        if let location = geocodedLocation {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            print("✅ Address geocoded successfully:")
            print("   Coordinates: (\(latitude), \(longitude))")
            print("   Full Address: \(fullAddress)")
        } else {
            print("⚠️ Geocoding failed, using fallback coordinates")
            // Use fallback coordinates based on city/state
            let fallbackCoords = getFallbackCoordinates(for: request.city, state: request.state)
            latitude = fallbackCoords.latitude
            longitude = fallbackCoords.longitude
        }
        
        // Save to Firestore with complete location data
        let db = Firestore.firestore()
        var requestData: [String: Any] = [
            "id": request.id,
            "name": request.name,
            "type": request.type.rawValue,
            "description": request.description,
            "email": request.email,
            "website": request.website ?? "",
            "phone": request.phone ?? "",
            "contactPersonName": request.contactPersonName,
            "contactPersonTitle": request.contactPersonTitle,
            "contactPersonPhone": request.contactPersonPhone,
            "contactPersonEmail": request.contactPersonEmail,
            "status": request.status.rawValue,
            "submittedAt": FieldValue.serverTimestamp(),
            // Store address data in both flat and nested location format
            "address": request.address,
            "city": request.city,
            "state": request.state,
            "zipCode": request.zipCode,
            // Nested location object with GPS coordinates
            "location": [
                "latitude": latitude,
                "longitude": longitude,
                "address": request.address,
                "city": request.city,
                "state": request.state,
                "zipCode": request.zipCode
            ]
        ]
        
        let requestRef = db.collection("organizationRequests").document()
        let requestId = requestRef.documentID
        requestData["id"] = requestId
        
        try await requestRef.setData(requestData)
        
        print("✅ Organization request submitted successfully")
        print("   Request ID: \(requestId)")
        
        // Create/link user account for the contact person
        print("🔄 Creating/linking user account for contact person...")
        do {
            let user = try await userService.createOrGetUserAccount(
                email: request.contactPersonEmail,
                name: request.contactPersonName,
                organizationId: requestId // Use request ID temporarily
            )
            
            print("✅ User account created/linked: \(user.id)")
            
            // Fix any missing fields in the user document
            try await userService.fixUserDocumentForOrganizationAdmin(
                userId: user.id,
                email: request.contactPersonEmail,
                name: request.contactPersonName
            )
        } catch {
            print("⚠️ Warning: Could not create/link user account: \(error)")
            
            // Fallback: Create basic user account
            do {
                let fallbackUser = try await createBasicUserAccount(
                    email: request.contactPersonEmail,
                    name: request.contactPersonName
                )
                print("✅ Fallback user account created: \(fallbackUser.id)")
            } catch {
                print("❌ Failed to create fallback user account: \(error)")
            }
        }
        
        // Create updated request with new ID
        let updatedRequest = OrganizationRequest(
            name: request.name,
            type: request.type,
            description: request.description,
            website: request.website,
            phone: request.phone,
            email: request.email,
            address: request.address,
            city: request.city,
            state: request.state,
            zipCode: request.zipCode,
            contactPersonName: request.contactPersonName,
            contactPersonTitle: request.contactPersonTitle,
            contactPersonPhone: request.contactPersonPhone,
            contactPersonEmail: request.contactPersonEmail,
            adminPassword: request.adminPassword,
            status: .pending
        )
        
        return updatedRequest
    }
    
    func approveOrganizationRequest(_ requestId: String, notes: String = "") async throws -> OrganizationRequest {
        print("✅ ORGANIZATION REQUEST APPROVED")
        print("   Request ID: \(requestId)")
        print("   Approved by: Admin")
        print("   Notes: \(notes.isEmpty ? "No additional notes" : notes)")
        print("   Next step: Create organization profile and link existing admin user")
        
        // Get the actual request data from Firestore
        let db = Firestore.firestore()
        let documentId = getFirestoreDocumentId(for: requestId) ?? requestId
        
        do {
            let requestDoc = try await db.collection("organizationRequests").document(documentId).getDocument()
            
            if let requestData = requestDoc.data() {
                let contactEmail = requestData["contactPersonEmail"] as? String ?? ""
                let contactName = requestData["contactPersonName"] as? String ?? "Unknown"
                
                print("   📋 Processing approval for organization: \(requestData["name"] ?? "Unknown")")
                print("   👤 Contact person: \(contactName) (\(contactEmail))")
                
                // First, find the existing user account that was created during submission
                print("   🔍 Looking for existing user account...")
                let usersQuery = try await db.collection("users")
                    .whereField("email", isEqualTo: contactEmail)
                    .getDocuments()
                
                guard let userDoc = usersQuery.documents.first else {
                    print("   ❌ User account not found for email: \(contactEmail)")
                    throw NSError(domain: "ApprovalError", code: 404, userInfo: [NSLocalizedDescriptionKey: "User account not found"])
                }
                
                let userId = userDoc.documentID
                print("   ✅ Found existing user account: \(userId)")
                
                // Parse the organization request
                let organizationRequest = OrganizationRequest(
                    name: requestData["name"] as? String ?? "Unknown",
                    type: OrganizationType(rawValue: requestData["type"] as? String ?? "business") ?? .business,
                    description: requestData["description"] as? String ?? "",
                    website: requestData["website"] as? String,
                    phone: requestData["phone"] as? String,
                    email: requestData["email"] as? String ?? "",
                    address: requestData["address"] as? String ?? "",
                    city: requestData["city"] as? String ?? "",
                    state: requestData["state"] as? String ?? "",
                    zipCode: requestData["zipCode"] as? String ?? "",
                    contactPersonName: contactName,
                    contactPersonTitle: requestData["contactPersonTitle"] as? String ?? "",
                    contactPersonPhone: requestData["contactPersonPhone"] as? String ?? "",
                    contactPersonEmail: contactEmail,
                    adminPassword: requestData["adminPassword"] as? String ?? "",
                    status: .approved
                )
                
                print("   🏢 Creating organization in Firestore...")
                
                // Create the organization document directly (simpler than calling createOrganization)
                let sanitizedName = organizationRequest.name.replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "\\", with: "_")
                    .replacingOccurrences(of: ".", with: "_")
                    .replacingOccurrences(of: "#", with: "_")
                    .replacingOccurrences(of: "$", with: "_")
                    .replacingOccurrences(of: "[", with: "_")
                    .replacingOccurrences(of: "]", with: "_")
                
                let orgRef = db.collection("organizations").document(sanitizedName)
                
                let orgData: [String: Any] = [
                    "id": sanitizedName,
                    "name": organizationRequest.name,
                    "type": organizationRequest.type.rawValue,
                    "description": organizationRequest.description,
                    "website": organizationRequest.website ?? "",
                    "phone": organizationRequest.phone ?? "",
                    "email": organizationRequest.email,
                    "location": [
                        "latitude": organizationRequest.location.latitude,
                        "longitude": organizationRequest.location.longitude,
                        "address": organizationRequest.location.address,
                        "city": organizationRequest.location.city,
                        "state": organizationRequest.location.state,
                        "zipCode": organizationRequest.location.zipCode
                    ],
                    "verified": true,
                    "verifiedAt": FieldValue.serverTimestamp(),
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                    "followerCount": 0,
                    "alertCount": 0,
                    "adminIds": [:], // Will be populated with Firebase Auth ID after account creation
                    "creatorId": userId,
                    "creatorName": contactName
                ]
                
                try await orgRef.setData(orgData)
                print("   ✅ Organization created successfully: \(sanitizedName)")
                print("   🔑 Organization ID: \(sanitizedName)")
                print("   👤 Admin user: \(userId)")
                
                // Generate a secure temporary password for the organization admin
                print("   🔐 Generating secure temporary password for organization admin...")
                do {
                    let securePassword = generateSecurePassword()
                    let authResult = try await Auth.auth().createUser(withEmail: contactEmail, password: securePassword)
                    let firebaseAuthId = authResult.user.uid
                    
                    // Update user document with Firebase Auth ID and mark for password change
                    try await db.collection("users").document(userId).updateData([
                        "firebaseAuthId": firebaseAuthId,
                        "needsPasswordChange": true,
                        "temporaryPassword": securePassword, // Store temporarily for admin to share
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                    
                    print("   ✅ Secure temporary password generated and stored")
                    print("   ✅ Firebase Auth account created: \(firebaseAuthId)")
                    
                    // Update the organization's adminIds to use the Firebase Auth ID
                    print("   🔑 Updating organization adminIds to use Firebase Auth ID...")
                    try await orgRef.updateData([
                        "adminIds": [firebaseAuthId: true], // Use Firebase Auth ID instead of Firestore document ID
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                    
                    print("   ✅ Organization adminIds updated to use Firebase Auth ID: \(firebaseAuthId)")
                    
                    // Sign out the temporary user
                    try await Auth.auth().signOut()
                    
                } catch {
                    print("   ⚠️ Warning: Could not set default password: \(error)")
                    print("   💡 User will need to use 'Create Account' flow instead")
                }
                
                // Update the user's organizations array to reference the real organization ID
                print("   🔗 Updating user's organization reference...")
                try await userService.updateUserOrganizationReference(
                    userId: userId,
                    oldOrgId: requestId,
                    newOrgId: sanitizedName
                )
                
                print("   ✅ User organization reference updated")
                
                // Update the request status to approved
                try await db.collection("organizationRequests").document(documentId).updateData([
                    "status": "approved",
                    "approvedAt": FieldValue.serverTimestamp(),
                    "notes": notes
                ])
                
                print("   📝 Request status updated to approved")
                print("   🎉 Organization approval complete! User \(contactEmail) is now admin of \(sanitizedName)")
                
                return organizationRequest
            } else {
                print("   ❌ Could not parse request data from Firestore")
                throw NSError(domain: "ApprovalError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid request data"])
            }
        } catch {
            print("   ❌ Error during approval process: \(error)")
            throw error
        }
    }
    
    // MARK: - Fix Existing Organizations
    func fixExistingOrganizationAdminIds() async throws {
        print("🔧 Fixing existing organization adminIds...")
        
        let db = Firestore.firestore()
        
        do {
            // Get all organizations
            let orgsSnapshot = try await db.collection("organizations").getDocuments()
            print("📋 Found \(orgsSnapshot.documents.count) organizations to check")
            
            var fixedCount = 0
            
            for orgDoc in orgsSnapshot.documents {
                let orgData = orgDoc.data()
                let orgId = orgDoc.documentID
                let adminIds = orgData["adminIds"] as? [String: Bool] ?? [:]
                
                // Check if adminIds contains Firestore document IDs instead of Firebase Auth IDs
                for (adminId, isAdmin) in adminIds {
                    if isAdmin {
                        // Try to find the user document to get their Firebase Auth ID
                        let userDoc = try await db.collection("users").document(adminId).getDocument()
                        
                        if userDoc.exists, let userData = userDoc.data() {
                            let firebaseAuthId = userData["firebaseAuthId"] as? String
                            
                            if let firebaseAuthId = firebaseAuthId, firebaseAuthId != adminId {
                                print("   🔧 Fixing organization \(orgId): replacing \(adminId) with \(firebaseAuthId)")
                                
                                // Update the organization to use Firebase Auth ID
                                try await db.collection("organizations").document(orgId).updateData([
                                    "adminIds": [firebaseAuthId: true],
                                    "updatedAt": FieldValue.serverTimestamp()
                                ])
                                
                                fixedCount += 1
                                print("   ✅ Fixed organization \(orgId)")
                                break // Only fix the first admin for each org
                            }
                        }
                    }
                }
            }
            
            print("🎉 Fixed \(fixedCount) organizations with incorrect adminIds")
            
        } catch {
            print("❌ Error fixing organization adminIds: \(error)")
            throw error
        }
    }
    
    // MARK: - Force Refresh Organization
    func forceRefreshOrganization(_ organizationId: String) async {
        print("🔄 OrganizationService: Force refreshing organization: \(organizationId)")
        
        do {
            let db = Firestore.firestore()
            let doc = try await db.collection("organizations").document(organizationId).getDocument()
            
            if let data = doc.data() {
                let refreshedOrg = try await parseOrganizationFromFirestore(docId: organizationId, data: data)
                if let refreshedOrg = refreshedOrg {
                    await MainActor.run {
                        // Update the organization in the local array
                        if let index = self.organizations.firstIndex(where: { $0.id == organizationId }) {
                            self.organizations[index] = refreshedOrg
                            print("✅ OrganizationService: Updated organization in local array: \(refreshedOrg.name)")
                            
                            // Post notification for UI updates
                            NotificationCenter.default.post(
                                name: NSNotification.Name("OrganizationUpdated"),
                                object: nil,
                                userInfo: ["organizationId": organizationId]
                            )
                        }
                    }
                }
            }
        } catch {
            print("❌ OrganizationService: Failed to force refresh organization: \(error)")
        }
    }
    
    // MARK: - Fallback Coordinates
    private func getFallbackCoordinates(for city: String, state: String) -> (latitude: Double, longitude: Double) {
        let cityState = "\(city.lowercased()), \(state.lowercased())"
        
        switch cityState {
        case "denton, tx":
            return (33.2148, -97.1331)
        case "allen, tx":
            return (33.1032, -96.6705)
        case "plano, tx":
            return (33.0198, -96.6989)
        case "frisco, tx":
            return (33.1507, -96.8236)
        case "mckinney, tx":
            return (33.1972, -96.6397)
        case "dallas, tx":
            return (32.7767, -96.7970)
        case "fort worth, tx":
            return (32.7555, -97.3308)
        case "arlington, tx":
            return (32.7357, -97.1081)
        case "deberry, tx":
            return (32.259146, -94.21128)
        default:
            // Generic Texas coordinates as final fallback
            return (32.7767, -96.7970)
        }
    }
    
    // MARK: - Helper Methods
    private func getFirestoreDocumentId(for requestId: String) -> String? {
        // This would contain any logic for mapping request IDs to Firestore document IDs
        return requestId
    }
    
    private func createBasicUserAccount(email: String, name: String) async throws -> User {
        print("🔄 Creating basic user account as fallback")
        print("   Email: \(email)")
        print("   Name: \(name)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document()
        let userId = userRef.documentID
        
        let userData: [String: Any] = [
            "id": userId,
            "email": email,
            "name": name,
            "searchableName": name.lowercased().replacingOccurrences(of: " ", with: ""),
            "customDisplayName": name,
            "isAdmin": true, // Set to true since they're submitting an org request
            "isOrganizationAdmin": true, // Set to true since they're submitting an org request
            "organizations": [], // Will be populated when org is approved
            "needsPasswordSetup": true,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await userRef.setData(userData)
        print("   ✅ Basic user account created: \(userId)")
        
        return User(
            id: userId,
            email: email,
            name: name,
            phone: nil,
            homeLocation: nil,
            workLocation: nil,
            schoolLocation: nil,
            alertRadius: 5.0,
            preferences: UserPreferences(
                incidentTypes: [],
                criticalAlertsOnly: false,
                pushNotifications: true,
                quietHoursEnabled: false,
                quietHoursStart: nil,
                quietHoursEnd: nil
            ),
            createdAt: Date(),
            isAdmin: true,
            displayName: name,
            isOrganizationAdmin: true,
            organizations: [],
            updatedAt: Date(),
            needsPasswordSetup: true,
            firebaseAuthId: nil
        )
    }
    
    // MARK: - Organization Following
    func followOrganization(_ organizationId: String) async throws {
        // Implementation for following an organization
        print("👥 Following organization: \(organizationId)")
        // This would be implemented based on your following logic
    }
    
    func unfollowOrganization(_ organizationId: String) async throws {
        // Implementation for unfollowing an organization
        print("👥 Unfollowing organization: \(organizationId)")
        // This would be implemented based on your following logic
    }
    
    func isFollowingOrganization(_ organizationId: String) async throws -> Bool {
        // Implementation for checking if following an organization
        print("👥 Checking if following organization: \(organizationId)")
        // This would be implemented based on your following logic
        return false
    }
    
    // MARK: - Geocoding
    private func geocodeAddress(_ fullAddress: String) async -> Location? {
        let geocoder = CLGeocoder()
        
        print("🌍 Geocoding address: \(fullAddress)")
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(fullAddress)
            
            if let placemark = placemarks.first,
               let location = placemark.location {
                let result = Location(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: fullAddress, // Use the original address the user entered
                    city: placemark.locality,
                    state: placemark.administrativeArea,
                    zipCode: placemark.postalCode
                )
                print("✅ Geocoding successful: \(result.coordinate.latitude), \(result.coordinate.longitude)")
                return result
            }
        } catch {
            print("⚠️ Geocoding failed: \(error)")
        }
        
        print("❌ Geocoding failed for address: \(fullAddress)")
        return nil
    }
    
    // MARK: - Password Generation
    private func generateSecurePassword() -> String {
        let length = 12
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Debug Organization Logo Issues
    func debugOrganizationLogoIssues() async {
        print("🔍 OrganizationService: Debugging organization logo issues...")
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("organizations").getDocuments()
            
            var totalOrganizations = 0
            var organizationsWithLogos = 0
            var organizationsWithInvalidLogos = 0
            var organizationsWithPlaceholderLogos = 0
            
            for document in snapshot.documents {
                totalOrganizations += 1
                let data = document.data()
                
                if let logoURL = data["logoURL"] as? String, !logoURL.isEmpty {
                    organizationsWithLogos += 1
                    
                    // Check if it's a placeholder/example URL
                    let lowercased = logoURL.lowercased()
                    if lowercased.contains("example.com") || 
                       lowercased.contains("placeholder") ||
                       lowercased.contains("via.placeholder.com") ||
                       lowercased.contains("dummy.com") ||
                       lowercased.contains("test.com") {
                        organizationsWithPlaceholderLogos += 1
                        print("⚠️ Organization with placeholder logo:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                    }
                    
                    // Check if URL is valid
                    guard let url = URL(string: logoURL) else {
                        organizationsWithInvalidLogos += 1
                        print("❌ Organization with invalid logo URL format:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                        continue
                    }
                    
                    guard let scheme = url.scheme, !scheme.isEmpty else {
                        organizationsWithInvalidLogos += 1
                        print("❌ Organization with logo URL missing scheme:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                        continue
                    }
                    
                    guard scheme == "http" || scheme == "https" else {
                        organizationsWithInvalidLogos += 1
                        print("❌ Organization with invalid logo URL scheme:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                        print("   - Scheme: \(scheme)")
                        continue
                    }
                    
                    guard let host = url.host, !host.isEmpty else {
                        organizationsWithInvalidLogos += 1
                        print("❌ Organization with logo URL missing host:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                        continue
                    }
                }
            }
            
            print("📊 Organization Logo Debug Summary:")
            print("   - Total organizations: \(totalOrganizations)")
            print("   - Organizations with logos: \(organizationsWithLogos)")
            print("   - Organizations with invalid logos: \(organizationsWithInvalidLogos)")
            print("   - Organizations with placeholder logos: \(organizationsWithPlaceholderLogos)")
            print("   - Organizations without logos: \(totalOrganizations - organizationsWithLogos)")
            
        } catch {
            print("❌ Error debugging organization logo issues: \(error)")
        }
    }
    
    // MARK: - Clean Up Invalid Logo URLs
    func cleanUpInvalidLogoURLs() async {
        print("🧹 OrganizationService: Cleaning up invalid logo URLs...")
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("organizations").getDocuments()
            
            var cleanedCount = 0
            var totalChecked = 0
            
            for document in snapshot.documents {
                totalChecked += 1
                let data = document.data()
                
                if let logoURL = data["logoURL"] as? String, !logoURL.isEmpty {
                    // Check if it's a placeholder/example URL that should be removed
                    let lowercased = logoURL.lowercased()
                    if lowercased.contains("example.com") || 
                       lowercased.contains("placeholder") ||
                       lowercased.contains("via.placeholder.com") ||
                       lowercased.contains("dummy.com") ||
                       lowercased.contains("test.com") ||
                       lowercased.contains("sample.com") ||
                       lowercased.contains("mock.com") ||
                       lowercased.contains("fake.com") {
                        
                        print("🧹 Cleaning up placeholder logo URL:")
                        print("   - Organization ID: \(document.documentID)")
                        print("   - Organization Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Old Logo URL: \(logoURL)")
                        
                        // Remove the invalid logo URL
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
            
            // Refresh organizations after cleanup by reloading from database
            await loadOrganizations()
            
        } catch {
            print("❌ Error cleaning up invalid logo URLs: \(error)")
        }
    }
}
