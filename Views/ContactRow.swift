//
//  ContactRow.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct ContactRow: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let isLink: Bool
    
    init(icon: String, title: String, value: String, subtitle: String? = nil, isLink: Bool = false) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.isLink = isLink
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20, alignment: .center)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                if isLink {
                    Link(value, destination: URL(string: value) ?? URL(string: "https://example.com")!)
                        .font(.body)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                } else {
                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Link indicator
            if isLink {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        ContactRow(
            icon: "person.circle.fill",
            title: "Contact Person",
            value: "John Smith",
            subtitle: "CEO"
        )
        
        ContactRow(
            icon: "phone.fill",
            title: "Phone",
            value: "(555) 123-4567"
        )
        
        ContactRow(
            icon: "envelope.fill",
            title: "Email",
            value: "john@company.com"
        )
        
        ContactRow(
            icon: "globe",
            title: "Website",
            value: "https://company.com",
            isLink: true
        )
    }
    .padding()
}
