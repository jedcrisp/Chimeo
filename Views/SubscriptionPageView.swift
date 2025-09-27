//
//  SubscriptionPageView.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct SubscriptionPageView: View {
    let organization: Organization
    @StateObject private var subscriptionService = SubscriptionService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentSubscription: OrganizationSubscription?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingUpgradeAlert = false
    @State private var selectedPlan: SubscriptionLevel?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                    
                    // Current Plan Section
                    currentPlanSection
                    
                    // Plans Section
                    plansSection
                    
                    // Features Comparison
                    featuresComparisonSection
                    
                    // FAQ Section
                    faqSection
                    
                    // Footer
                    footerSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Subscription Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentSubscription()
            }
            .alert("Upgrade Subscription", isPresented: $showingUpgradeAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Upgrade") {
                    upgradeSubscription()
                }
            } message: {
                Text("Are you sure you want to upgrade to \(selectedPlan?.displayName ?? "")?")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Logo/Icon
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Choose Your Plan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Unlock powerful features for your organization")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Current Plan Section
    private var currentPlanSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Plan")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack {
                Image(systemName: organization.subscriptionLevel.icon)
                    .foregroundColor(organization.subscriptionLevel.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(organization.subscriptionLevel.displayName)
                        .font(.headline)
                        .foregroundColor(organization.subscriptionLevel.color)
                    
                    Text("Active since \(currentSubscription?.startDate.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if organization.subscriptionLevel != .enterprise {
                    Text("Upgrade Available")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    // MARK: - Plans Section
    private var plansSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Available Plans")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 12) {
                ForEach(SubscriptionLevel.allCases, id: \.self) { plan in
                    PlanCard(
                        plan: plan,
                        isCurrentPlan: plan == organization.subscriptionLevel,
                        isRecommended: plan == .pro,
                        onSelect: {
                            if plan != organization.subscriptionLevel {
                                selectedPlan = plan
                                showingUpgradeAlert = true
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Features Comparison
    private var featuresComparisonSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Feature Comparison")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Features")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(SubscriptionLevel.allCases, id: \.self) { plan in
                        Text(plan.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(plan.color)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Feature rows
                ForEach(featureRows, id: \.title) { feature in
                    HStack {
                        Text(feature.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ForEach(SubscriptionLevel.allCases, id: \.self) { plan in
                            let features = SubscriptionFeatures.features(for: plan)
                            let value = feature.getValue(features)
                            
                            if let boolValue = value as? Bool {
                                Image(systemName: boolValue ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(boolValue ? .green : .red)
                                    .frame(maxWidth: .infinity)
                            } else if let intValue = value as? Int {
                                Text(intValue == -1 ? "∞" : String(intValue))
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("-")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    
                    if feature.title != featureRows.last?.title {
                        Divider()
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    // MARK: - FAQ Section
    private var faqSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Frequently Asked Questions")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                FAQItem(
                    question: "Can I change my plan anytime?",
                    answer: "Yes, you can upgrade or downgrade your plan at any time. Changes take effect immediately."
                )
                
                FAQItem(
                    question: "What happens to my data when I downgrade?",
                    answer: "Your data is always preserved. If you exceed limits after downgrading, you'll need to reduce usage or upgrade again."
                )
                
                FAQItem(
                    question: "Do you offer refunds?",
                    answer: "We offer a 30-day money-back guarantee for all new subscriptions."
                )
                
                FAQItem(
                    question: "Can I cancel anytime?",
                    answer: "Yes, you can cancel your subscription at any time. You'll continue to have access until the end of your billing period."
                )
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            Text("Need help choosing a plan?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Contact Support") {
                // TODO: Open support contact
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            
            Text("All plans include 24/7 support and regular updates")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
    // MARK: - Feature Rows
    private var featureRows: [SubscriptionFeatureRow] {
        [
            SubscriptionFeatureRow(title: "Groups", getValue: { $0.maxGroups }),
            SubscriptionFeatureRow(title: "Sub-Groups", getValue: { $0.maxSubGroups }),
            SubscriptionFeatureRow(title: "Members per Group", getValue: { $0.maxMembersPerGroup }),
            SubscriptionFeatureRow(title: "Advanced Analytics", getValue: { $0.advancedAnalytics }),
            SubscriptionFeatureRow(title: "Custom Branding", getValue: { $0.customBranding }),
            SubscriptionFeatureRow(title: "Priority Support", getValue: { $0.prioritySupport }),
            SubscriptionFeatureRow(title: "API Access", getValue: { $0.apiAccess }),
            SubscriptionFeatureRow(title: "Custom Integrations", getValue: { $0.customIntegrations })
        ]
    }
    
    // MARK: - Methods
    private func loadCurrentSubscription() {
        Task {
            isLoading = true
            do {
                currentSubscription = try await subscriptionService.getOrganizationSubscription(organizationId: organization.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func upgradeSubscription() {
        guard let selectedPlan = selectedPlan else { return }
        
        Task {
            isLoading = true
            do {
                try await subscriptionService.updateOrganizationSubscription(
                    organizationId: organization.id,
                    subscriptionLevel: selectedPlan
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: SubscriptionLevel
    let isCurrentPlan: Bool
    let isRecommended: Bool
    let onSelect: () -> Void
    
    private var features: SubscriptionFeatures {
        SubscriptionFeatures.features(for: plan)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(plan.color)
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                        
                        if isCurrentPlan {
                            Text("CURRENT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(planDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(planPrice)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(plan.color)
                    
                    Text(planBilling)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Key Features
            VStack(alignment: .leading, spacing: 8) {
                ForEach(keyFeatures, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
            
            // Action Button
            Button(action: onSelect) {
                Text(isCurrentPlan ? "Current Plan" : "Select Plan")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isCurrentPlan ? Color.gray : plan.color)
                    .cornerRadius(10)
            }
            .disabled(isCurrentPlan)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecommended ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
    
    private var planDescription: String {
        switch plan {
        case .free:
            return "Perfect for small organizations getting started"
        case .pro:
            return "Ideal for growing organizations with advanced needs"
        case .enterprise:
            return "Complete solution for large organizations"
        }
    }
    
    private var planPrice: String {
        switch plan {
        case .free:
            return "Free"
        case .pro:
            return "$29"
        case .enterprise:
            return "$99"
        }
    }
    
    private var planBilling: String {
        switch plan {
        case .free:
            return "Forever"
        case .pro:
            return "per month"
        case .enterprise:
            return "per month"
        }
    }
    
    private var keyFeatures: [String] {
        switch plan {
        case .free:
            return [
                "Up to \(features.maxGroups) groups",
                "Up to \(features.maxMembersPerGroup) members per group",
                "Basic support"
            ]
        case .pro:
            return [
                "Up to \(features.maxGroups) groups",
                "Up to \(features.maxSubGroups) sub-groups",
                "Advanced analytics",
                "Custom branding",
                "Priority support"
            ]
        case .enterprise:
            return [
                "Unlimited groups & sub-groups",
                "Unlimited members",
                "All Pro features",
                "API access",
                "Custom integrations",
                "Dedicated support"
            ]
        }
    }
}

// MARK: - FAQ Item
struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Subscription Feature Row
struct SubscriptionFeatureRow {
    let title: String
    let getValue: (SubscriptionFeatures) -> Any
}

#Preview {
    SubscriptionPageView(
        organization: Organization(
            name: "Test Organization",
            type: "Emergency Services",
            location: Location(latitude: 0, longitude: 0),
            subscriptionLevel: .free
        )
    )
}
