//
//  GroupToggleRow.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct GroupToggleRow: View {
    let group: OrganizationGroup
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Group Icon
            Image(systemName: "person.3.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20, alignment: .center)
            
            // Group Info
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Toggle Switch
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        GroupToggleRow(
            group: OrganizationGroup(
                id: "group1",
                name: "Emergency Alerts",
                description: "Critical safety notifications",
                organizationId: "org1",
                memberCount: 25,
                isPrivate: false,
                createdAt: Date(),
                updatedAt: Date()
            ),
            isEnabled: true,
            onToggle: { _ in }
        )
        
        GroupToggleRow(
            group: OrganizationGroup(
                id: "group2",
                name: "Weather Updates",
                description: "Daily weather forecasts and severe weather warnings",
                organizationId: "org1",
                memberCount: 150,
                isPrivate: true,
                createdAt: Date(),
                updatedAt: Date()
            ),
            isEnabled: false,
            onToggle: { _ in }
        )
    }
    .padding()
}
