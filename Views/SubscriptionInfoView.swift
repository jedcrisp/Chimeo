//
//  SubscriptionInfoView.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct SubscriptionInfoView: View {
    let organization: Organization
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var subscription: OrganizationSubscription?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Subscription Header
            HStack {
                Image(systemName: organization.subscriptionLevel.icon)
                    .foregroundColor(organization.subscriptionLevel.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(organization.subscriptionLevel.displayName)
                        .font(.headline)
                        .foregroundColor(organization.subscriptionLevel.color)
                    
                    Text("Current Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                NavigationLink(destination: SubscriptionPageView(organization: organization)) {
                    Text("View Plans")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(organization.subscriptionLevel.color)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Features List
            VStack(alignment: .leading, spacing: 12) {
                Text("Plan Features")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ForEach(featureItems, id: \.title) { feature in
                    HStack {
                        Image(systemName: feature.isIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(feature.isIncluded ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            if let subtitle = feature.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Usage Stats
            if organization.subscriptionLevel != .free {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Usage")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    UsageStatRow(
                        title: "Groups",
                        current: organization.groupCount,
                        limit: organization.subscriptionFeatures.maxGroups,
                        isUnlimited: organization.subscriptionFeatures.maxGroups == -1
                    )
                    
                    if organization.subscriptionFeatures.maxSubGroups > 0 {
                        UsageStatRow(
                            title: "Sub-Groups",
                            current: 0, // TODO: Get actual sub-group count
                            limit: organization.subscriptionFeatures.maxSubGroups,
                            isUnlimited: organization.subscriptionFeatures.maxSubGroups == -1
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            loadSubscriptionInfo()
        }
    }
    
    private var featureItems: [FeatureItem] {
        let features = organization.subscriptionFeatures
        
        return [
            FeatureItem(
                title: "Groups",
                subtitle: features.maxGroups == -1 ? "Unlimited" : "Up to \(features.maxGroups)",
                isIncluded: true
            ),
            FeatureItem(
                title: "Sub-Groups",
                subtitle: features.maxSubGroups == -1 ? "Unlimited" : features.maxSubGroups > 0 ? "Up to \(features.maxSubGroups)" : "Not available",
                isIncluded: features.maxSubGroups > 0
            ),
            FeatureItem(
                title: "Members per Group",
                subtitle: features.maxMembersPerGroup == -1 ? "Unlimited" : "Up to \(features.maxMembersPerGroup)",
                isIncluded: true
            ),
            FeatureItem(
                title: "Advanced Analytics",
                subtitle: nil,
                isIncluded: features.advancedAnalytics
            ),
            FeatureItem(
                title: "Custom Branding",
                subtitle: nil,
                isIncluded: features.customBranding
            ),
            FeatureItem(
                title: "Priority Support",
                subtitle: nil,
                isIncluded: features.prioritySupport
            ),
            FeatureItem(
                title: "API Access",
                subtitle: nil,
                isIncluded: features.apiAccess
            ),
            FeatureItem(
                title: "Custom Integrations",
                subtitle: nil,
                isIncluded: features.customIntegrations
            )
        ]
    }
    
    private func loadSubscriptionInfo() {
        Task {
            isLoading = true
            do {
                subscription = try await subscriptionService.getOrganizationSubscription(organizationId: organization.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct FeatureItem {
    let title: String
    let subtitle: String?
    let isIncluded: Bool
}

struct UsageStatRow: View {
    let title: String
    let current: Int
    let limit: Int
    let isUnlimited: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isUnlimited {
                Text("Unlimited")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("\(current) / \(limit)")
                    .font(.subheadline)
                    .foregroundColor(current >= limit ? .red : .primary)
            }
        }
    }
}

#Preview {
    SubscriptionInfoView(
        organization: Organization(
            name: "Test Organization",
            type: "Emergency Services",
            location: Location(latitude: 0, longitude: 0),
            subscriptionLevel: .pro
        )
    )
}
