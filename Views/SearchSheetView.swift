import SwiftUI

struct SearchSheetView: View {
    @Binding var searchText: String
    @Binding var searchResults: [Organization]
    @Binding var selectedOrganization: Organization?
    @Binding var showingOrganizationProfile: Bool
    @Binding var showingSearchSheet: Bool
    
    @EnvironmentObject var apiService: APIService
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                            .font(.system(size: 18, weight: .medium))
                        
                        TextField("Search organizations, cities, states...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .medium))
                            .focused($isSearchFocused)
                            .onSubmit {
                                Task {
                                    await searchOrganizations()
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { 
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 18))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Search Results
                if !searchText.isEmpty && !searchResults.isEmpty {
                    VStack(spacing: 0) {
                        // Results Header
                        HStack {
                            Text("Found \(min(searchResults.count, 10)) organizations")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        
                        // Results List
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(searchResults.prefix(10), id: \.id) { organization in
                                    Button(action: {
                                        selectedOrganization = organization
                                        showingOrganizationProfile = true
                                        showingSearchSheet = false
                                    }) {
                                        HStack(spacing: 16) {
                                            OrganizationLogoView(organization: organization, size: 40, showBorder: false)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(organization.name)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                
                                                if let city = organization.location.city, let state = organization.location.state {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "location.fill")
                                                            .font(.caption2)
                                                            .foregroundColor(.blue)
                                                        Text("\(city), \(state)")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background(Color(.systemBackground))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Separator line (except for last item)
                                    if organization.id != searchResults.prefix(10).last?.id {
                                        Rectangle()
                                            .frame(height: 0.5)
                                            .foregroundColor(Color(.systemGray5))
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    }
                } else if !searchText.isEmpty && searchResults.isEmpty {
                    // No results found
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No organizations found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try searching with different keywords")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    // Initial state - show search tips
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("Search Organizations")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Search by organization name, city, state, or address")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        showingSearchSheet = false
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            // Auto-focus the search field when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSearchFocused = true
            }
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                Task {
                    await searchOrganizations()
                }
            } else {
                searchResults = []
            }
        }
    }
    
    private func searchOrganizations() async {
        do {
            let results = try await apiService.searchOrganizations(query: searchText)
            await MainActor.run {
                searchResults = results
            }
        } catch {
            print("Search error: \(error)")
            await MainActor.run {
                searchResults = []
            }
        }
    }
}

#Preview {
    SearchSheetView(
        searchText: .constant(""),
        searchResults: .constant([]),
        selectedOrganization: .constant(nil),
        showingOrganizationProfile: .constant(false),
        showingSearchSheet: .constant(false)
    )
    .environmentObject(APIService())
}
