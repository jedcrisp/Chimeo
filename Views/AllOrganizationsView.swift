import SwiftUI

struct AllOrganizationsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var organizations: [Organization] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedType: String? = nil
    
    private var filteredOrganizations: [Organization] {
        var filtered = organizations
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { org in
                org.name.localizedCaseInsensitiveContains(searchText) ||
                org.description?.localizedCaseInsensitiveContains(searchText) == true ||
                org.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by type
        if let selectedType = selectedType {
            filtered = filtered.filter { $0.type.lowercased() == selectedType.lowercased() }
        }
        
        return filtered
    }
    
    private var organizationTypes: [String] {
        Array(Set(organizations.map { $0.type })).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            VStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search organizations...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Type Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedType == nil,
                            action: { selectedType = nil }
                        )
                        
                        ForEach(organizationTypes, id: \.self) { type in
                            FilterChip(
                                title: type.capitalized,
                                isSelected: selectedType == type,
                                action: { selectedType = type }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Organizations List
            if isLoading {
                Spacer()
                ProgressView("Loading organizations...")
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if filteredOrganizations.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "No organizations found" : "No matching organizations")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if !searchText.isEmpty {
                        Text("Try adjusting your search terms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            } else {
                List(filteredOrganizations) { organization in
                    NavigationLink(destination: OrganizationProfileView(organization: organization)) {
                        OrganizationRowView(organization: organization)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("All Organizations")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadOrganizations()
        }
    }
    
    private func loadOrganizations() {
        isLoading = true
        
        Task {
            do {
                let fetchedOrganizations = try await apiService.fetchOrganizations()
                
                await MainActor.run {
                    self.organizations = fetchedOrganizations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}



// MARK: - Organization Row View (Enhanced)
struct OrganizationRowView: View {
    let organization: Organization
    @State private var isFollowing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Organization Icon
            OrganizationLogoView(organization: organization, size: 40, showBorder: false)
            
            // Organization Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(organization.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if organization.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Text(organization.type.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let description = organization.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label("\(organization.followerCount)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(organization.location.city ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Follow Button
            Button(action: { isFollowing.toggle() }) {
                Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                    .foregroundColor(isFollowing ? .red : .blue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
    
    private var organizationIcon: String {
        switch organization.type.lowercased() {
        case "church": return "building.2.fill"
        case "pto": return "graduationcap.fill"
        case "school": return "building.columns.fill"
        case "business": return "building.2.fill"
        case "government": return "building.columns.fill"
        case "nonprofit": return "heart.fill"
        case "emergency": return "cross.fill"
        case "medical_practice", "medical": return "cross.case.fill"
        case "healthcare": return "heart.text.square.fill"
        case "hospital": return "building.2.crop.circle.fill"
        case "clinic": return "cross.circle.fill"
        case "pharmacy": return "pills.fill"
        case "dental": return "mouth.fill"
        case "veterinary": return "pawprint.fill"
        case "fire_department": return "flame.fill"
        case "police_department": return "shield.fill"
        case "library": return "books.vertical.fill"
        case "museum": return "building.columns.circle.fill"
        case "park": return "leaf.fill"
        case "restaurant": return "fork.knife"
        case "retail": return "bag.fill"
        case "bank": return "banknote.fill"
        case "insurance": return "umbrella.fill"
        case "real_estate": return "house.fill"
        case "law_firm": return "building.columns.circle.fill"
        case "consulting": return "person.2.fill"
        case "technology": return "laptopcomputer"
        case "manufacturing": return "gearshape.fill"
        case "construction": return "hammer.fill"
        case "transportation": return "car.fill"
        case "utilities": return "bolt.fill"
        case "entertainment": return "star.fill"
        case "sports": return "sportscourt.fill"
        case "fitness": return "dumbbell.fill"
        case "beauty": return "scissors"
        case "automotive": return "car.circle.fill"
        case "education": return "graduationcap.fill"
        case "religious": return "building.2.fill"
        case "community": return "person.3.fill"
        case "charity": return "heart.fill"
        case "environmental": return "leaf.circle.fill"
        case "arts": return "paintbrush.fill"
        case "media": return "tv.fill"
        case "finance": return "chart.line.uptrend.xyaxis"
        case "research": return "magnifyingglass"
        case "agriculture": return "leaf.arrow.circlepath"
        case "hospitality": return "bed.double.fill"
        case "logistics": return "shippingbox.fill"
        case "energy": return "bolt.circle.fill"
        case "telecommunications": return "antenna.radiowaves.left.and.right"
        case "pharmaceutical": return "pills.circle.fill"
        case "biotechnology": return "dna"
        case "aerospace": return "airplane"
        case "defense": return "shield.lefthalf.filled"
        case "mining": return "hammer.circle.fill"
        case "oil_gas": return "drop.fill"
        case "chemical": return "testtube.2"
        case "textiles": return "scissors.circle"
        case "food_beverage": return "cup.and.saucer.fill"
        case "tobacco": return "smoke.fill"
        case "gaming": return "gamecontroller.fill"
        case "cryptocurrency": return "bitcoinsign.circle.fill"
        case "blockchain": return "link.circle.fill"
        case "ai_ml": return "brain.head.profile"
        case "cybersecurity": return "lock.shield.fill"
        case "cloud_computing": return "cloud.fill"
        case "ecommerce": return "cart.fill"
        case "social_media": return "message.fill"
        case "streaming": return "play.tv.fill"
        case "gaming_industry": return "gamecontroller.fill"
        case "fashion": return "tshirt.fill"
        case "luxury": return "crown.fill"
        case "fast_food": return "takeoutbag.and.cup.and.straw.fill"
        case "coffee": return "cup.and.saucer.fill"
        case "bakery": return "birthday.cake.fill"
        case "butcher": return "scissors"
        case "fishmonger": return "fish.fill"
        case "greengrocer": return "carrot.fill"
        case "deli": return "fork.knife.circle"
        case "wine": return "wineglass.fill"
        case "brewery": return "drop.fill"
        case "distillery": return "drop.circle.fill"
        case "catering": return "fork.knife.circle.fill"
        case "food_truck": return "car.fill"
        case "popup": return "tent.fill"
        case "market": return "cart.circle.fill"
        case "farmers_market": return "leaf.circle.fill"
        case "organic": return "leaf.arrow.circlepath"
        case "vegan": return "leaf.fill"
        case "gluten_free": return "exclamationmark.triangle.fill"
        case "halal": return "checkmark.circle.fill"
        case "kosher": return "star.david.fill"
        case "halal_certified": return "checkmark.seal.fill"
        case "kosher_certified": return "star.seal.fill"
        case "organic_certified": return "leaf.seal.fill"
        case "fair_trade": return "hand.raised.fill"
        case "sustainable": return "leaf.arrow.circlepath"
        case "eco_friendly": return "leaf.circle.fill"
        case "carbon_neutral": return "leaf.arrow.circlepath"
        case "renewable_energy": return "bolt.circle.fill"
        case "solar": return "sun.max.fill"
        case "wind": return "wind"
        case "hydroelectric": return "drop.fill"
        case "geothermal": return "flame.fill"
        case "nuclear": return "atom"
        case "coal": return "circle.fill"
        case "natural_gas": return "flame.circle.fill"
        case "petroleum": return "drop.circle.fill"
        case "biodiesel": return "leaf.arrow.circlepath"
        case "ethanol": return "drop.fill"
        case "hydrogen": return "atom"
        case "fusion": return "atom"
        case "fission": return "atom"
        case "plasma": return "bolt.circle.fill"
        case "quantum": return "atom"
        case "nanotechnology": return "atom"
        case "robotics": return "gearshape.2.fill"
        case "automation": return "gearshape.2.fill"
        case "iot": return "antenna.radiowaves.left.and.right"
        case "5g": return "antenna.radiowaves.left.and.right"
        case "fiber_optics": return "antenna.radiowaves.left.and.right"
        case "satellite": return "antenna.radiowaves.left.and.right"
        case "drone": return "airplane"
        case "autonomous_vehicles": return "car.fill"
        case "electric_vehicles": return "bolt.circle.fill"
        case "hybrid_vehicles": return "leaf.circle.fill"
        case "hydrogen_vehicles": return "atom"
        case "fuel_cell": return "atom"
        case "battery": return "bolt.circle.fill"
        case "supercapacitor": return "bolt.circle.fill"
        case "wireless_charging": return "bolt.circle.fill"
        case "fast_charging": return "bolt.circle.fill"
        case "inductive_charging": return "bolt.circle.fill"
        case "solar_charging": return "sun.max.fill"
        case "kinetic_energy": return "bolt.circle.fill"
        case "thermal_energy": return "flame.fill"
        case "mechanical_energy": return "gearshape.fill"
        case "chemical_energy": return "testtube.2"
        case "nuclear_energy": return "atom"
        case "gravitational_energy": return "arrow.down.circle.fill"
        case "elastic_energy": return "arrow.up.circle.fill"
        case "sound_energy": return "speaker.wave.3.fill"
        case "light_energy": return "lightbulb.fill"
        case "electromagnetic_energy": return "antenna.radiowaves.left.and.right"
        case "atomic_energy": return "atom"
        case "molecular_energy": return "atom"
        case "cellular_energy": return "atom"
        case "biological_energy": return "leaf.fill"
        case "geological_energy": return "mountain.2.fill"
        case "oceanic_energy": return "drop.fill"
        case "atmospheric_energy": return "cloud.fill"
        case "cosmic_energy": return "star.fill"
        case "dark_energy": return "moon.fill"
        case "antimatter": return "atom"
        case "dark_matter": return "moon.fill"
        case "neutrinos": return "atom"
        case "gravitons": return "arrow.down.circle.fill"
        case "photons": return "lightbulb.fill"
        case "electrons": return "bolt.circle.fill"
        case "protons": return "plus.circle.fill"
        case "neutrons": return "circle.fill"
        case "quarks": return "atom"
        case "leptons": return "atom"
        case "bosons": return "atom"
        case "fermions": return "atom"
        case "hadrons": return "atom"
        case "mesons": return "atom"
        case "baryons": return "atom"
        case "gluons": return "atom"
        case "w_bosons": return "atom"
        case "z_bosons": return "atom"
        case "higgs_boson": return "atom"
        case "graviton": return "arrow.down.circle.fill"
        case "photon": return "lightbulb.fill"
        case "electron": return "bolt.circle.fill"
        case "proton": return "plus.circle.fill"
        case "neutron": return "circle.fill"
        case "quark": return "atom"
        case "lepton": return "atom"
        case "boson": return "atom"
        case "fermion": return "atom"
        case "hadron": return "atom"
        case "meson": return "atom"
        case "baryon": return "atom"
        case "gluon": return "atom"
        case "w_boson": return "atom"
        case "z_boson": return "atom"
        case "higgs_boson": return "atom"
        default: return "building.2.fill"
        }
    }
    
    private var organizationColor: Color {
        switch organization.type.lowercased() {
        case "church": return .purple
        case "pto": return .green
        case "school": return .blue
        case "business": return .orange
        case "government": return .red
        case "nonprofit": return .pink
        case "emergency": return .red
        case "medical_practice", "medical": return .blue
        case "healthcare": return .mint
        case "hospital": return .red
        case "clinic": return .blue
        case "pharmacy": return .green
        case "dental": return .cyan
        case "veterinary": return .brown
        case "fire_department": return .orange
        case "police_department": return .blue
        case "library": return .indigo
        case "museum": return .purple
        case "park": return .green
        case "restaurant": return .orange
        case "retail": return .pink
        case "bank": return .green
        case "insurance": return .blue
        case "real_estate": return .brown
        case "law_firm": return .purple
        case "consulting": return .blue
        case "technology": return .blue
        case "manufacturing": return .orange
        case "construction": return .orange
        case "transportation": return .blue
        case "utilities": return .yellow
        case "entertainment": return .purple
        case "sports": return .green
        case "fitness": return .red
        case "beauty": return .pink
        case "automotive": return .gray
        case "education": return .blue
        case "religious": return .purple
        case "community": return .green
        case "charity": return .pink
        case "environmental": return .green
        case "arts": return .purple
        case "media": return .blue
        case "finance": return .green
        case "research": return .blue
        case "agriculture": return .green
        case "hospitality": return .orange
        case "logistics": return .blue
        case "energy": return .yellow
        case "telecommunications": return .blue
        case "pharmaceutical": return .blue
        case "biotechnology": return .green
        case "aerospace": return .blue
        case "defense": return .red
        case "mining": return .brown
        case "oil_gas": return .black
        case "chemical": return .orange
        case "textiles": return .pink
        case "food_beverage": return .orange
        case "tobacco": return .brown
        case "gaming": return .purple
        case "cryptocurrency": return .orange
        case "blockchain": return .blue
        case "ai_ml": return .purple
        case "cybersecurity": return .red
        case "cloud_computing": return .blue
        case "ecommerce": return .orange
        case "social_media": return .blue
        case "streaming": return .purple
        case "gaming_industry": return .purple
        case "fashion": return .pink
        case "luxury": return .yellow
        case "fast_food": return .red
        case "coffee": return .brown
        case "bakery": return .orange
        case "butcher": return .red
        case "fishmonger": return .blue
        case "greengrocer": return .green
        case "deli": return .orange
        case "wine": return .purple
        case "brewery": return .brown
        case "distillery": return .brown
        case "catering": return .orange
        case "food_truck": return .orange
        case "popup": return .orange
        case "market": return .green
        case "farmers_market": return .green
        case "organic": return .green
        case "vegan": return .green
        case "gluten_free": return .green
        case "halal": return .green
        case "kosher": return .blue
        case "halal_certified": return .green
        case "kosher_certified": return .blue
        case "organic_certified": return .green
        case "fair_trade": return .green
        case "sustainable": return .green
        case "eco_friendly": return .green
        case "carbon_neutral": return .green
        case "renewable_energy": return .green
        case "solar": return .yellow
        case "wind": return .blue
        case "hydroelectric": return .blue
        case "geothermal": return .orange
        case "nuclear": return .red
        case "coal": return .black
        case "natural_gas": return .orange
        case "petroleum": return .black
        case "biodiesel": return .green
        case "ethanol": return .green
        case "hydrogen": return .blue
        case "fusion": return .blue
        case "fission": return .red
        case "plasma": return .purple
        case "quantum": return .purple
        case "nanotechnology": return .purple
        case "robotics": return .blue
        case "automation": return .blue
        case "iot": return .blue
        case "5g": return .blue
        case "fiber_optics": return .blue
        case "satellite": return .blue
        case "drone": return .blue
        case "autonomous_vehicles": return .blue
        case "electric_vehicles": return .green
        case "hybrid_vehicles": return .green
        case "hydrogen_vehicles": return .blue
        case "fuel_cell": return .green
        case "battery": return .green
        case "supercapacitor": return .green
        case "wireless_charging": return .green
        case "fast_charging": return .green
        case "inductive_charging": return .green
        case "solar_charging": return .yellow
        case "kinetic_energy": return .green
        case "thermal_energy": return .orange
        case "mechanical_energy": return .blue
        case "chemical_energy": return .orange
        case "nuclear_energy": return .red
        case "gravitational_energy": return .purple
        case "elastic_energy": return .purple
        case "sound_energy": return .blue
        case "light_energy": return .yellow
        case "electromagnetic_energy": return .purple
        case "atomic_energy": return .red
        case "molecular_energy": return .blue
        case "cellular_energy": return .green
        case "biological_energy": return .green
        case "geological_energy": return .brown
        case "oceanic_energy": return .blue
        case "atmospheric_energy": return .blue
        case "cosmic_energy": return .purple
        case "dark_energy": return .black
        case "antimatter": return .purple
        case "dark_matter": return .black
        case "neutrinos": return .blue
        case "gravitons": return .purple
        case "photons": return .yellow
        case "electrons": return .blue
        case "protons": return .red
        case "neutrons": return .gray
        case "quarks": return .purple
        case "leptons": return .blue
        case "bosons": return .green
        case "fermions": return .orange
        case "hadrons": return .red
        case "mesons": return .purple
        case "baryons": return .blue
        case "gluons": return .red
        case "w_bosons": return .orange
        case "z_bosons": return .blue
        case "higgs_boson": return .yellow
        case "graviton": return .purple
        case "photon": return .yellow
        case "electron": return .blue
        case "proton": return .red
        case "neutron": return .gray
        case "quark": return .purple
        case "lepton": return .blue
        case "boson": return .green
        case "fermion": return .orange
        case "hadron": return .red
        case "meson": return .purple
        case "baryon": return .blue
        case "gluon": return .red
        case "w_boson": return .orange
        case "z_boson": return .blue
        case "higgs_boson": return .yellow
        default: return .blue
        }
    }
}

#Preview {
    NavigationView {
        AllOrganizationsView()
            .environmentObject(APIService())
    }
} 