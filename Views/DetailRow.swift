//
//  DetailRow.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20, alignment: .center)
            
            // Title and Value
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
            }
            
            Spacer()
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
        DetailRow(
            icon: "text.bubble",
            title: "Description",
            value: "Severe weather warning with heavy rain and strong winds expected."
        )
        
        DetailRow(
            icon: "clock",
            title: "Effective Time",
            value: "January 15, 2025 at 2:30 PM"
        )
        
        DetailRow(
            icon: "clock.badge.xmark",
            title: "Expires",
            value: "January 16, 2025 at 6:00 AM"
        )
        
        DetailRow(
            icon: "building.2",
            title: "Source",
            value: "National Weather Service"
        )
        
        DetailRow(
            icon: "globe",
            title: "Website",
            value: "https://weather.gov"
        )
        
        DetailRow(
            icon: "phone",
            title: "Organization Phone",
            value: "(555) 123-4567"
        )
        
        DetailRow(
            icon: "envelope",
            title: "Organization Email",
            value: "contact@organization.com"
        )
    }
    .padding()
}
